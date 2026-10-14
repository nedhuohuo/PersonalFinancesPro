import 'package:personal_finances_pro/core/data/sqlite_statement.dart';
import 'package:personal_finances_pro/features/catalog/domain/catalog_models.dart';
import 'package:personal_finances_pro/features/catalog/domain/catalog_repository.dart';
import 'package:sqflite/sqflite.dart';

final class SqliteCatalogRepository implements CatalogRepository {
  SqliteCatalogRepository(this._db);

  final Database _db;

  @override
  Future<void> ensureDefaultCatalogs() async {
    final now = utcNowIso();
    await _db.transaction((txn) async {
      for (final name in defaultAccountLabels) {
        await txn.insert('account_labels', {
          'name': name,
          'created_at_utc': now,
          'updated_at_utc': now,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      for (final entry in defaultExpenseCategories.entries) {
        await _insertDefaultCategory(
          txn,
          entry.key,
          CashDirection.expense,
          entry.value,
          now,
        );
      }
      for (final entry in defaultIncomeCategories.entries) {
        await _insertDefaultCategory(
          txn,
          entry.key,
          CashDirection.income,
          entry.value,
          now,
        );
      }
      for (final name in defaultResaleChannels) {
        await txn.insert('resale_channels', {
          'name': name,
          'created_at_utc': now,
          'updated_at_utc': now,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
  }

  @override
  Future<List<Shop>> listShops({bool includeInactive = false}) async =>
      (await _listActiveTable(
        'shops',
        includeInactive: includeInactive,
      )).map(_shopFromRow).toList();

  @override
  Future<Shop> createShop({required String name}) async {
    final id = await _createNamedRow('shops', {'name': name});
    return _getShop(id);
  }

  @override
  Future<Shop> renameShop({required int id, required String name}) async {
    await _rename('shops', id, name);
    return _getShop(id, includeInactive: true);
  }

  @override
  Future<void> deactivateShop(int id) => _deactivate('shops', id);

  @override
  Future<List<AccountLabel>> listAccountLabels({
    bool includeInactive = false,
  }) async =>
      (await _listActiveTable(
        'account_labels',
        includeInactive: includeInactive,
      )).map(_accountFromRow).toList();

  @override
  Future<AccountLabel> createAccountLabel({required String name}) async {
    final id = await _createNamedRow('account_labels', {'name': name});
    return _getAccount(id);
  }

  @override
  Future<AccountLabel> renameAccountLabel({
    required int id,
    required String name,
  }) async {
    await _rename('account_labels', id, name);
    return _getAccount(id, includeInactive: true);
  }

  @override
  Future<void> deactivateAccountLabel(int id) =>
      _deactivate('account_labels', id);

  @override
  Future<List<Party>> listParties({
    PartyKind? kind,
    bool includeInactive = false,
  }) async {
    final where = <String>[];
    final args = <Object?>[];
    if (!includeInactive) where.add('is_active = 1');
    if (kind != null) {
      where.add('kind = ?');
      args.add(partyKindValue(kind));
    }
    final rows = await _db.query(
      'parties',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args,
      orderBy: 'id',
    );
    return rows.map(_partyFromRow).toList();
  }

  @override
  Future<Party> createParty({
    required String name,
    required PartyKind kind,
  }) async {
    final id = await _createNamedRow('parties', {
      'name': name,
      'kind': partyKindValue(kind),
    });
    return _getParty(id);
  }

  @override
  Future<Party> renameParty({required int id, required String name}) async {
    await _rename('parties', id, name);
    return _getParty(id, includeInactive: true);
  }

  @override
  Future<void> deactivateParty(int id) => _deactivate('parties', id);

  @override
  Future<List<Category>> listCategories({
    CashDirection? direction,
    CategoryRole? role,
    bool includeInactive = false,
  }) async {
    final where = <String>[];
    final args = <Object?>[];
    if (!includeInactive) where.add('is_active = 1');
    if (direction != null) {
      where.add('direction = ?');
      args.add(cashDirectionValue(direction));
    }
    if (role != null) {
      where.add('role = ?');
      args.add(categoryRoleValue(role));
    }
    final rows = await _db.query(
      'categories',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args,
      orderBy: 'id',
    );
    return rows.map(_categoryFromRow).toList();
  }

  @override
  Future<Category> createCategory({
    required String name,
    required CashDirection direction,
  }) async {
    final id = await _createNamedRow('categories', {
      'name': name,
      'direction': cashDirectionValue(direction),
      'role': categoryRoleValue(CategoryRole.ordinary),
      'is_system': 0,
    });
    return _getCategory(id);
  }

  @override
  Future<Category> renameCategory({
    required int id,
    required String name,
  }) async {
    await _rename('categories', id, name);
    return _getCategory(id, includeInactive: true);
  }

  @override
  Future<void> deactivateCategory(int id) => _deactivate('categories', id);

  @override
  Future<List<ResaleChannel>> listResaleChannels({
    bool includeInactive = false,
  }) async =>
      (await _listActiveTable(
        'resale_channels',
        includeInactive: includeInactive,
      )).map(_resaleChannelFromRow).toList();

  @override
  Future<ResaleChannel> createResaleChannel({required String name}) async {
    final id = await _createNamedRow('resale_channels', {'name': name});
    return _getResaleChannel(id);
  }

  @override
  Future<ResaleChannel> renameResaleChannel({
    required int id,
    required String name,
  }) async {
    await _rename('resale_channels', id, name);
    return _getResaleChannel(id, includeInactive: true);
  }

  @override
  Future<void> deactivateResaleChannel(int id) =>
      _deactivate('resale_channels', id);

  Future<int> _createNamedRow(String table, Map<String, Object?> values) async {
    final now = utcNowIso();
    return _db.insert(table, {
      ...values,
      'created_at_utc': now,
      'updated_at_utc': now,
    });
  }

  Future<void> _rename(String table, int id, String name) async {
    final count = await _db.update(
      table,
      {'name': name, 'updated_at_utc': utcNowIso()},
      where: 'id = ?',
      whereArgs: [id],
    );
    if (count != 1) throw StateError('资料不存在');
  }

  Future<void> _deactivate(String table, int id) async {
    final count = await _db.update(
      table,
      {'is_active': 0, 'updated_at_utc': utcNowIso()},
      where: 'id = ?',
      whereArgs: [id],
    );
    if (count != 1) throw StateError('资料不存在');
  }

  Future<List<Map<String, Object?>>> _listActiveTable(
    String table, {
    required bool includeInactive,
  }) {
    return _db.query(
      table,
      where: includeInactive ? null : 'is_active = 1',
      orderBy: 'id',
    );
  }

  Future<Shop> _getShop(int id, {bool includeInactive = false}) async =>
      _shopFromRow(
        await _single('shops', id, includeInactive: includeInactive),
      );

  Future<AccountLabel> _getAccount(
    int id, {
    bool includeInactive = false,
  }) async => _accountFromRow(
    await _single('account_labels', id, includeInactive: includeInactive),
  );

  Future<Party> _getParty(int id, {bool includeInactive = false}) async =>
      _partyFromRow(
        await _single('parties', id, includeInactive: includeInactive),
      );

  Future<Category> _getCategory(int id, {bool includeInactive = false}) async =>
      _categoryFromRow(
        await _single('categories', id, includeInactive: includeInactive),
      );

  Future<ResaleChannel> _getResaleChannel(
    int id, {
    bool includeInactive = false,
  }) async => _resaleChannelFromRow(
    await _single('resale_channels', id, includeInactive: includeInactive),
  );

  Future<Map<String, Object?>> _single(
    String table,
    int id, {
    required bool includeInactive,
  }) async {
    final rows = await _db.query(
      table,
      where: includeInactive ? 'id = ?' : 'id = ? AND is_active = 1',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('资料不存在');
    return rows.single;
  }
}

const defaultAccountLabels = ['现金', '银行卡', '微信', '支付宝'];
const defaultExpenseCategories = {
  '厂家付款': CategoryRole.purchasePayment,
  '包装配件': CategoryRole.ordinary,
  '快递充值': CategoryRole.courierTopUp,
  '问题件费用': CategoryRole.resaleFee,
  '其他经营支出': CategoryRole.ordinary,
};
const defaultIncomeCategories = {
  '厂家退款回收': CategoryRole.supplierRefund,
  '快递退款': CategoryRole.courierRefund,
  '问题件二次销售': CategoryRole.resaleIncome,
  '其他经营收入': CategoryRole.ordinary,
};
const defaultResaleChannels = ['线下转卖', '闲置平台', '其他渠道'];

Future<void> _insertDefaultCategory(
  Transaction txn,
  String name,
  CashDirection direction,
  CategoryRole role,
  String now,
) {
  return txn.insert('categories', {
    'name': name,
    'direction': cashDirectionValue(direction),
    'role': categoryRoleValue(role),
    'is_system': 1,
    'created_at_utc': now,
    'updated_at_utc': now,
  }, conflictAlgorithm: ConflictAlgorithm.ignore);
}

Shop _shopFromRow(Map<String, Object?> row) => Shop(
  id: row['id']! as int,
  name: row['name']! as String,
  isActive: sqliteBool(row['is_active']),
);

AccountLabel _accountFromRow(Map<String, Object?> row) => AccountLabel(
  id: row['id']! as int,
  name: row['name']! as String,
  isActive: sqliteBool(row['is_active']),
);

Party _partyFromRow(Map<String, Object?> row) => Party(
  id: row['id']! as int,
  name: row['name']! as String,
  kind: partyKindFromSql(row['kind']),
  isActive: sqliteBool(row['is_active']),
);

Category _categoryFromRow(Map<String, Object?> row) => Category(
  id: row['id']! as int,
  name: row['name']! as String,
  direction: cashDirectionFromSql(row['direction']),
  role: categoryRoleFromSql(row['role']),
  isSystem: sqliteBool(row['is_system']),
  isActive: sqliteBool(row['is_active']),
);

ResaleChannel _resaleChannelFromRow(Map<String, Object?> row) => ResaleChannel(
  id: row['id']! as int,
  name: row['name']! as String,
  isActive: sqliteBool(row['is_active']),
);
