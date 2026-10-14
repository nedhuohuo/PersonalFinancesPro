import 'package:personal_finances_pro/core/data/sqlite_statement.dart';
import 'package:personal_finances_pro/core/domain/local_date.dart';
import 'package:personal_finances_pro/core/domain/money.dart';
import 'package:personal_finances_pro/features/catalog/domain/catalog_models.dart';
import 'package:personal_finances_pro/features/dashboard/domain/dashboard_repository.dart';
import 'package:personal_finances_pro/features/dashboard/domain/dashboard_snapshots.dart';
import 'package:personal_finances_pro/features/ledger/domain/ledger_calculations.dart';
import 'package:personal_finances_pro/features/ledger/domain/ledger_models.dart';
import 'package:sqflite/sqflite.dart';

final class SqliteDashboardRepository implements DashboardRepository {
  SqliteDashboardRepository(this._db);

  final Database _db;

  @override
  Future<DashboardSnapshot> loadDashboardSnapshot({
    required LocalDate monthStart,
    required LocalDate monthEnd,
    BusinessScope? scope,
  }) async {
    final cash = await _activeCashRows(
      _db,
      start: monthStart,
      end: monthEnd,
      scope: scope,
    );
    final monthExpense = Money.sumCents(
      cash
          .where((row) => row['direction'] == CashDirection.expense.name)
          .map((row) => row['amount_cents']! as int),
    );
    final resaleIncome = await _resaleIncome(
      _db,
      start: monthStart,
      end: monthEnd,
      scope: scope,
    );
    final recent = cash.reversed.take(10).map(_cashBillFromRow).toList();
    return DashboardSnapshot(
      monthCashExpense: monthExpense,
      supplierPayable: await _supplierPayable(_db, scope: scope),
      monthResaleIncome: resaleIncome,
      recentBills: recent,
    );
  }

  @override
  Future<LedgerDetailSnapshot> loadLedgerDetailSnapshot({
    required LocalDate startDate,
    required LocalDate endDate,
    BusinessScope? scope,
  }) async {
    final cash = await _activeCashRows(
      _db,
      start: startDate,
      end: endDate,
      scope: scope,
    );
    final cashIncome = Money.sumCents(
      cash
          .where((row) => row['direction'] == CashDirection.income.name)
          .map((row) => row['amount_cents']! as int),
    );
    final cashExpense = Money.sumCents(
      cash
          .where((row) => row['direction'] == CashDirection.expense.name)
          .map((row) => row['amount_cents']! as int),
    );
    final purchase = await _purchaseTotals(
      _db,
      start: startDate,
      end: endDate,
      scope: scope,
    );
    final resaleIncome = await _resaleIncome(
      _db,
      start: startDate,
      end: endDate,
      scope: scope,
    );
    final resaleFees = await _resaleFees(
      _db,
      start: startDate,
      end: endDate,
      scope: scope,
    );
    final courierTopUp = await _courierEventTotal(
      _db,
      CourierEventType.topUp,
      start: startDate,
      end: endDate,
      scope: scope,
    );
    final courierConsume = await _courierEventTotal(
      _db,
      CourierEventType.consume,
      start: startDate,
      end: endDate,
      scope: scope,
    );
    return LedgerDetailSnapshot(
      cashIncome: cashIncome,
      cashExpense: cashExpense,
      cashNet: Money.sumCents([cashIncome.cents, -cashExpense.cents]),
      purchaseEffective: purchase.effective,
      purchasePaidNet: purchase.paidNet,
      purchasePayable: purchase.payable,
      resaleIncome: resaleIncome,
      resaleFees: resaleFees,
      resaleNetRecovery: Money.sumCents([
        resaleIncome.cents,
        -resaleFees.cents,
      ]),
      courierTopUp: courierTopUp,
      courierConsume: courierConsume,
      globalCourierRecordedBalance:
          scope == null ? await _globalCourierBalance(_db) : null,
    );
  }
}

Future<List<Map<String, Object?>>> _activeCashRows(
  DatabaseExecutor db, {
  required LocalDate start,
  required LocalDate end,
  BusinessScope? scope,
}) {
  final where = <String>[
    'is_void = 0',
    'business_date >= ?',
    'business_date <= ?',
  ];
  final args = <Object?>[start.value, end.value];
  _addScopeWhere(where, args, scope, prefix: '');
  return db.query(
    'cash_bills',
    where: where.join(' AND '),
    whereArgs: args,
    orderBy: 'business_date ASC, id ASC',
  );
}

Future<Money> _supplierPayable(
  DatabaseExecutor db, {
  BusinessScope? scope,
}) async {
  final cents = <int>[];
  final where = <String>['is_void = 0'];
  final args = <Object?>[];
  _addScopeWhere(where, args, scope, prefix: '');
  final purchases = await db.query(
    'purchases',
    where: where.join(' AND '),
    whereArgs: args,
  );
  for (final purchase in purchases) {
    cents.add((await _purchasePosition(db, purchase)).payable.cents);
  }
  final debts = await db.query(
    'supplier_opening_debts',
    where: where.join(' AND '),
    whereArgs: args,
  );
  for (final debt in debts) {
    cents.add((debt['amount_cents']! as int) - (debt['paid_cents']! as int));
  }
  return Money.sumCents(cents);
}

Future<({Money effective, Money paidNet, Money payable})> _purchaseTotals(
  DatabaseExecutor db, {
  required LocalDate start,
  required LocalDate end,
  BusinessScope? scope,
}) async {
  final where = <String>[
    'is_void = 0',
    'business_date >= ?',
    'business_date <= ?',
  ];
  final args = <Object?>[start.value, end.value];
  _addScopeWhere(where, args, scope, prefix: '');
  final rows = await db.query(
    'purchases',
    where: where.join(' AND '),
    whereArgs: args,
  );
  final effective = <int>[];
  final paidNet = <int>[];
  final payable = <int>[];
  for (final row in rows) {
    final position = await _purchasePosition(db, row);
    effective.add(position.effectiveTotal.cents);
    paidNet.add(position.paidNet.cents);
    payable.add(position.payable.cents);
  }
  return (
    effective: Money.sumCents(effective),
    paidNet: Money.sumCents(paidNet),
    payable: Money.sumCents(payable),
  );
}

Future<PurchasePosition> _purchasePosition(
  DatabaseExecutor db,
  Map<String, Object?> purchase,
) async {
  final id = purchase['id']! as int;
  final payments = await db.query(
    'purchase_payments',
    columns: ['amount_cents'],
    where: 'purchase_id = ? AND is_void = 0',
    whereArgs: [id],
  );
  final adjustments = await db.query(
    'purchase_adjustments',
    columns: ['kind', 'amount_cents'],
    where: 'purchase_id = ? AND is_void = 0',
    whereArgs: [id],
  );
  return LedgerCalculations.purchasePosition(
    originalTotal: Money.fromCents(purchase['original_total_cents']! as int),
    unpaidWaivers: adjustments
        .where((row) => row['kind'] == PurchaseAdjustmentKind.unpaidWaiver.name)
        .map((row) => Money.fromCents(row['amount_cents']! as int)),
    paidRefunds: adjustments
        .where((row) => row['kind'] == PurchaseAdjustmentKind.paidRefund.name)
        .map((row) => Money.fromCents(row['amount_cents']! as int)),
    activePayments: payments.map(
      (row) => Money.fromCents(row['amount_cents']! as int),
    ),
  );
}

Future<Money> _resaleIncome(
  DatabaseExecutor db, {
  required LocalDate start,
  required LocalDate end,
  BusinessScope? scope,
}) async {
  final where = <String>[
    'r.is_void = 0',
    'r.business_date >= ?',
    'r.business_date <= ?',
    'c.is_void = 0',
    'c.linked_type = ?',
    'c.linked_id = r.id',
    'c.id = r.income_cash_bill_id',
  ];
  final args = <Object?>[
    start.value,
    end.value,
    LinkedBillType.problemResaleIncome.name,
  ];
  _addScopeWhere(where, args, scope, prefix: 'r.');
  final rows = await db.rawQuery(
    'SELECT c.amount_cents FROM problem_resales r JOIN cash_bills c ON c.id = r.income_cash_bill_id WHERE ${where.join(' AND ')}',
    args,
  );
  return Money.sumCents(rows.map((row) => row['amount_cents']! as int));
}

Future<Money> _resaleFees(
  DatabaseExecutor db, {
  required LocalDate start,
  required LocalDate end,
  BusinessScope? scope,
}) async {
  final where = <String>[
    'r.is_void = 0',
    'r.business_date >= ?',
    'r.business_date <= ?',
    'c.is_void = 0',
    'c.linked_type = ?',
    'c.linked_id = r.id',
  ];
  final args = <Object?>[
    start.value,
    end.value,
    LinkedBillType.problemResaleFee.name,
  ];
  _addScopeWhere(where, args, scope, prefix: 'r.');
  final rows = await db.rawQuery(
    'SELECT c.amount_cents FROM problem_resales r JOIN problem_resale_fees f ON f.resale_id = r.id JOIN cash_bills c ON c.id = f.cash_bill_id WHERE ${where.join(' AND ')}',
    args,
  );
  return Money.sumCents(rows.map((row) => row['amount_cents']! as int));
}

Future<Money> _courierEventTotal(
  DatabaseExecutor db,
  CourierEventType type, {
  required LocalDate start,
  required LocalDate end,
  BusinessScope? scope,
}) async {
  final where = <String>[
    'is_void = 0',
    'event_type = ?',
    'business_date >= ?',
    'business_date <= ?',
  ];
  final args = <Object?>[type.name, start.value, end.value];
  _addScopeWhere(where, args, scope, prefix: '');
  final rows = await db.query(
    'courier_events',
    columns: ['amount_cents'],
    where: where.join(' AND '),
    whereArgs: args,
  );
  return Money.sumCents(rows.map((row) => row['amount_cents']! as int));
}

Future<Money> _globalCourierBalance(DatabaseExecutor db) async {
  final accounts = await db.query(
    'courier_accounts',
    columns: ['id'],
    where: 'is_active = 1',
  );
  final cents = <int>[];
  for (final account in accounts) {
    final rows = await db.query(
      'courier_events',
      columns: ['balance_after_cents'],
      where: 'courier_account_id = ?',
      whereArgs: [account['id']],
      orderBy: 'business_date DESC, id DESC',
      limit: 1,
    );
    if (rows.isNotEmpty) cents.add(rows.single['balance_after_cents']! as int);
  }
  return Money.sumCents(cents);
}

CashBill _cashBillFromRow(Map<String, Object?> row) => CashBill(
  id: row['id']! as int,
  businessDate: LocalDate.parse(row['business_date']! as String),
  direction: CashDirection.values.byName(row['direction']! as String),
  amount: Money.fromCents(row['amount_cents']! as int),
  scope: businessScopeFromSql(row),
  categoryId: row['category_id']! as int,
  accountId: row['account_id']! as int,
  partyId: row['party_id'] as int?,
  note: row['note']! as String,
  entrySource: EntrySource.values.byName(row['entry_source']! as String),
  businessOrigin: BusinessOrigin.values.byName(
    row['business_origin']! as String,
  ),
  linkedType:
      row['linked_type'] == null
          ? null
          : LinkedBillType.values.byName(row['linked_type']! as String),
  linkedId: row['linked_id'] as int?,
  isVoid: sqliteBool(row['is_void']),
  createdAtUtc: DateTime.parse(row['created_at_utc']! as String),
  updatedAtUtc: DateTime.parse(row['updated_at_utc']! as String),
);

void _addScopeWhere(
  List<String> where,
  List<Object?> args,
  BusinessScope? scope, {
  required String prefix,
}) {
  if (scope == null) return;
  where.add('${prefix}scope_type = ?');
  args.add(scope.type.name);
  if (scope.shopId == null) {
    where.add('${prefix}shop_id IS NULL');
  } else {
    where.add('${prefix}shop_id = ?');
    args.add(scope.shopId);
  }
}
