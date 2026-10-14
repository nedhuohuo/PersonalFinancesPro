import 'dart:convert';

import 'package:personal_finances_pro/core/data/sqlite_aggregate_guard.dart';
import 'package:personal_finances_pro/core/data/sqlite_statement.dart';
import 'package:personal_finances_pro/core/domain/local_date.dart';
import 'package:personal_finances_pro/core/domain/money.dart';
import 'package:personal_finances_pro/features/catalog/domain/catalog_models.dart';
import 'package:personal_finances_pro/features/ledger/domain/cash_bill_repository.dart';
import 'package:personal_finances_pro/features/ledger/domain/ledger_models.dart';
import 'package:sqflite/sqflite.dart';

final class SqliteCashBillRepository implements CashBillRepository {
  SqliteCashBillRepository(this._db);

  final Database _db;

  @override
  Future<CashBill> createCashBill(CashBillDraft draft) async {
    _validateAmount(draft.amount);
    return _db.transaction((txn) async {
      await _validateDraftReferences(txn, draft, existing: null);
      final now = utcNowIso();
      final id = await txn.insert(
        'cash_bills',
        _cashBillValues(draft, now, now),
      );
      await SqliteAggregateGuard.ensureCashBillTotalWithinCap(txn);
      final row = await _cashBillRow(txn, id);
      await _insertAudit(txn, 'create', id, '', row);
      return _cashBillFromRow(row);
    });
  }

  @override
  Future<CashBill> updateCashBill({
    required int id,
    required CashBillDraft draft,
  }) async {
    _validateAmount(draft.amount);
    return _db.transaction((txn) async {
      final existing = await _cashBillRow(txn, id);
      _rejectLinked(existing);
      await _validateDraftReferences(txn, draft, existing: existing);
      final count = await txn.update(
        'cash_bills',
        _cashBillValues(
          draft,
          existing['created_at_utc']! as String,
          utcNowIso(),
        ),
        where: 'id = ?',
        whereArgs: [id],
      );
      if (count != 1) throw StateError('账单不存在');
      if (!sqliteBool(existing['is_void'])) {
        await SqliteAggregateGuard.ensureCashBillTotalWithinCap(txn);
      }
      final row = await _cashBillRow(txn, id);
      await _insertAudit(txn, 'update', id, '', row);
      return _cashBillFromRow(row);
    });
  }

  @override
  Future<void> voidCashBill(int id, {required String reason}) async {
    final auditReason = _validatedStatusReason(reason);
    await _db.transaction((txn) async {
      final existing = await _cashBillRow(txn, id);
      _rejectLinked(existing);
      if (sqliteBool(existing['is_void'])) return;
      final now = utcNowIso();
      await txn.update(
        'cash_bills',
        {'is_void': 1, 'voided_at_utc': now, 'updated_at_utc': now},
        where: 'id = ?',
        whereArgs: [id],
      );
      final row = await _cashBillRow(txn, id);
      await _insertAudit(txn, 'void', id, auditReason, row);
    });
  }

  @override
  Future<void> restoreCashBill(int id, {required String reason}) async {
    final auditReason = _validatedStatusReason(reason);
    await _db.transaction((txn) async {
      final existing = await _cashBillRow(txn, id);
      _rejectLinked(existing);
      if (!sqliteBool(existing['is_void'])) return;
      final now = utcNowIso();
      await txn.update(
        'cash_bills',
        {'is_void': 0, 'voided_at_utc': null, 'updated_at_utc': now},
        where: 'id = ?',
        whereArgs: [id],
      );
      await SqliteAggregateGuard.ensureCashBillTotalWithinCap(txn);
      final row = await _cashBillRow(txn, id);
      await _insertAudit(txn, 'restore', id, auditReason, row);
    });
  }

  @override
  Future<List<CashBill>> listCashBills(CashBillFilter filter) async {
    final where = <String>[];
    final args = <Object?>[];
    if (!filter.includeVoid) where.add('is_void = 0');
    if (filter.startDate != null) {
      where.add('business_date >= ?');
      args.add(filter.startDate!.value);
    }
    if (filter.endDate != null) {
      where.add('business_date <= ?');
      args.add(filter.endDate!.value);
    }
    if (filter.scope != null) {
      where.add('scope_type = ?');
      args.add(businessScopeTypeValue(filter.scope!.type));
      if (filter.scope!.shopId == null) {
        where.add('shop_id IS NULL');
      } else {
        where.add('shop_id = ?');
        args.add(filter.scope!.shopId);
      }
    }
    if (filter.categoryId != null) {
      where.add('category_id = ?');
      args.add(filter.categoryId);
    }
    if (filter.partyId != null) {
      where.add('party_id = ?');
      args.add(filter.partyId);
    }
    if (filter.noteQuery != null && filter.noteQuery!.isNotEmpty) {
      where.add('note LIKE ? ESCAPE \'\\\'');
      args.add('%${_escapeLike(filter.noteQuery!)}%');
    }
    final rows = await _db.query(
      'cash_bills',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args,
      orderBy: 'business_date ASC, id ASC',
    );
    return rows.map(_cashBillFromRow).toList();
  }
}

Map<String, Object?> _cashBillValues(
  CashBillDraft draft,
  String createdAtUtc,
  String updatedAtUtc,
) => {
  'business_date': draft.businessDate.value,
  'direction': cashDirectionValue(draft.direction),
  'amount_cents': draft.amount.cents,
  'scope_type': businessScopeTypeValue(draft.scope.type),
  'shop_id': draft.scope.shopId,
  'category_id': draft.categoryId,
  'account_id': draft.accountId,
  'party_id': draft.partyId,
  'note': draft.note,
  'entry_source': entrySourceValue(EntrySource.manual),
  'business_origin': businessOriginValue(BusinessOrigin.ordinary),
  'linked_type': null,
  'linked_id': null,
  'created_at_utc': createdAtUtc,
  'updated_at_utc': updatedAtUtc,
};

Future<void> _validateDraftReferences(
  DatabaseExecutor db,
  CashBillDraft draft, {
  required Map<String, Object?>? existing,
}) async {
  await _requireCategory(
    db,
    draft.categoryId,
    draft.direction,
    allowInactive: existing?['category_id'] == draft.categoryId,
  );
  await _requireActive(
    db,
    'account_labels',
    draft.accountId,
    allowInactive: existing?['account_id'] == draft.accountId,
  );
  if (draft.partyId != null) {
    await _requireActive(
      db,
      'parties',
      draft.partyId!,
      allowInactive: existing?['party_id'] == draft.partyId,
    );
  }
  if (draft.scope.shopId != null) {
    await _requireActive(
      db,
      'shops',
      draft.scope.shopId!,
      allowInactive: existing?['shop_id'] == draft.scope.shopId,
    );
  }
}

Future<void> _requireCategory(
  DatabaseExecutor db,
  int id,
  CashDirection direction, {
  required bool allowInactive,
}) async {
  final row = await _singleRef(db, 'categories', id);
  if (row['direction'] != cashDirectionValue(direction)) {
    throw StateError('收支方向不匹配');
  }
  if (!allowInactive && !sqliteBool(row['is_active'])) {
    throw StateError('资料已停用');
  }
}

Future<void> _requireActive(
  DatabaseExecutor db,
  String table,
  int id, {
  required bool allowInactive,
}) async {
  final row = await _singleRef(db, table, id);
  if (!allowInactive && !sqliteBool(row['is_active'])) {
    throw StateError('资料已停用');
  }
}

Future<Map<String, Object?>> _singleRef(
  DatabaseExecutor db,
  String table,
  int id,
) async {
  final rows = await db.query(
    table,
    where: 'id = ?',
    whereArgs: [id],
    limit: 1,
  );
  if (rows.isEmpty) throw StateError('资料不存在');
  return rows.single;
}

Future<Map<String, Object?>> _cashBillRow(DatabaseExecutor db, int id) async {
  final rows = await db.query(
    'cash_bills',
    where: 'id = ?',
    whereArgs: [id],
    limit: 1,
  );
  if (rows.isEmpty) throw StateError('账单不存在');
  return rows.single;
}

Future<void> _insertAudit(
  DatabaseExecutor db,
  String action,
  int entityId,
  String reason,
  Map<String, Object?> snapshot,
) {
  return db.insert('audit_logs', {
    'entity_type': 'cash_bill',
    'entity_id': entityId,
    'action': action,
    'reason': reason,
    'snapshot_json': jsonEncode(snapshot),
    'created_at_utc': utcNowIso(),
  });
}

void _rejectLinked(Map<String, Object?> row) {
  if (row['linked_type'] != null ||
      row['linked_id'] != null ||
      row['business_origin'] != 'ordinary') {
    throw StateError('关联账单只能在所属业务中修改');
  }
}

void _validateAmount(Money amount) {
  if (amount.cents <= 0 || amount.cents > Money.maxCents) {
    throw const FormatException('金额超出允许范围');
  }
}

String _validatedStatusReason(String reason) {
  final trimmed = reason.trim();
  if (trimmed.isEmpty) {
    throw const FormatException('原因不能为空');
  }
  return trimmed;
}

CashBill _cashBillFromRow(Map<String, Object?> row) => CashBill(
  id: row['id']! as int,
  businessDate: LocalDate.parse(row['business_date']! as String),
  direction: cashDirectionFromSql(row['direction']),
  amount: Money.fromCents(row['amount_cents']! as int),
  scope: businessScopeFromSql(row),
  categoryId: row['category_id']! as int,
  accountId: row['account_id']! as int,
  partyId: row['party_id'] as int?,
  note: row['note']! as String,
  entrySource: entrySourceFromSql(row['entry_source']),
  businessOrigin: businessOriginFromSql(row['business_origin']),
  linkedType: linkedBillTypeFromSql(row['linked_type']),
  linkedId: row['linked_id'] as int?,
  isVoid: sqliteBool(row['is_void']),
  createdAtUtc: DateTime.parse(row['created_at_utc']! as String),
  updatedAtUtc: DateTime.parse(row['updated_at_utc']! as String),
);

String _escapeLike(String value) =>
    value.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');
