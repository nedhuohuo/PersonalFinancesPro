import 'dart:io';

import 'package:personal_finances_pro/core/data/ledger_database.dart';
import 'package:personal_finances_pro/core/data/ledger_privacy.dart';
import 'package:personal_finances_pro/core/domain/local_date.dart';
import 'package:personal_finances_pro/core/domain/money.dart';
import 'package:personal_finances_pro/features/catalog/data/sqlite_catalog_repository.dart';
import 'package:personal_finances_pro/features/catalog/domain/catalog_models.dart';
import 'package:personal_finances_pro/features/catalog/domain/catalog_repository.dart';
import 'package:personal_finances_pro/features/ledger/data/sqlite_cash_bill_repository.dart';
import 'package:personal_finances_pro/features/ledger/domain/cash_bill_repository.dart';
import 'package:personal_finances_pro/features/ledger/domain/ledger_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

final class SqliteLedgerTestHarness {
  SqliteLedgerTestHarness._({
    required Directory directory,
    required LedgerDatabase ledgerDatabase,
    required int defaultAccountId,
    required int defaultExpenseCategoryId,
    required this.unusedExpenseCategoryId,
    required this.resaleIncomeCategoryId,
  }) : _directory = directory,
       _ledgerDatabase = ledgerDatabase,
       _defaultAccountId = defaultAccountId,
       _defaultExpenseCategoryId = defaultExpenseCategoryId {
    _bindRepositories();
  }

  final Directory _directory;
  final LedgerDatabase _ledgerDatabase;
  final int _defaultAccountId;
  final int _defaultExpenseCategoryId;

  late SqliteCatalogRepository _catalog;
  late SqliteCashBillRepository _cashBills;
  bool _closed = false;

  static Future<SqliteLedgerTestHarness> open() async {
    sqfliteFfiInit();
    final directory = await Directory.systemTemp.createTemp('sqlite-ledger-');
    final ledgerDatabase = LedgerDatabase();
    await ledgerDatabase.open(
      privacy: _PreparedPrivacy(directory.path),
      databaseFactoryOverride: databaseFactoryFfi,
      preparedDirectoryOverride: directory.path,
    );
    final catalog = SqliteCatalogRepository(ledgerDatabase.database);
    await catalog.ensureDefaultCatalogs();
    final accounts = await catalog.listAccountLabels();
    final expense = await catalog.listCategories(
      direction: CashDirection.expense,
    );
    final resaleIncome =
        (await catalog.listCategories(
          direction: CashDirection.income,
          role: CategoryRole.resaleIncome,
        )).single;
    return SqliteLedgerTestHarness._(
      directory: directory,
      ledgerDatabase: ledgerDatabase,
      defaultAccountId: accounts.first.id,
      defaultExpenseCategoryId: expense.last.id,
      unusedExpenseCategoryId: expense.last.id,
      resaleIncomeCategoryId: resaleIncome.id,
    );
  }

  Database get database => _ledgerDatabase.database;
  CatalogRepository get catalog => _catalog;
  CashBillRepository get cashBills => _cashBills;
  final int unusedExpenseCategoryId;
  final int resaleIncomeCategoryId;

  Future<AccountLabel> createAccount(String name) =>
      _catalog.createAccountLabel(name: name);

  Future<Category> createCategory({
    required String name,
    required CashDirection direction,
  }) => _catalog.createCategory(name: name, direction: direction);

  Future<Party> createParty({required String name, required PartyKind kind}) =>
      _catalog.createParty(name: name, kind: kind);

  Future<Shop> createShop(String name) => _catalog.createShop(name: name);

  PurchasePaymentDraft purchasePayment({required String amount}) =>
      PurchasePaymentDraft(
        businessDate: LocalDate.parse('2026-10-14'),
        amount: Money.parsePositive(amount),
        accountId: _defaultAccountId,
        categoryId: _defaultExpenseCategoryId,
      );

  CourierCashEventDraft courierTopUp({
    required int courierAccountId,
    required BusinessScope scope,
    required String amount,
  }) => CourierCashEventDraft(
    courierAccountId: courierAccountId,
    scope: scope,
    businessDate: LocalDate.parse('2026-10-14'),
    amount: Money.parsePositive(amount),
    accountId: _defaultAccountId,
    categoryId: _defaultExpenseCategoryId,
  );

  Future<void> seedOrdinaryIncomeUsingResaleCategory({
    required String amount,
  }) async {
    await _cashBills.createCashBill(
      CashBillDraft(
        businessDate: LocalDate.parse('2026-10-14'),
        direction: CashDirection.income,
        amount: Money.parsePositive(amount),
        scope: const BusinessScope.public(),
        categoryId: resaleIncomeCategoryId,
        accountId: _defaultAccountId,
      ),
    );
  }

  Future<void> seedManualExpenseCents(int cents) async {
    await _cashBills.createCashBill(
      CashBillDraft(
        businessDate: LocalDate.parse('2026-10-14'),
        direction: CashDirection.expense,
        amount: Money.fromCents(cents),
        scope: const BusinessScope.public(),
        categoryId: _defaultExpenseCategoryId,
        accountId: _defaultAccountId,
      ),
    );
  }

  Future<int> cashBillCount() async {
    final rows = await database.rawQuery(
      'SELECT COUNT(*) AS count FROM cash_bills',
    );
    return rows.single['count']! as int;
  }

  Future<int> auditLogCount() async {
    final rows = await database.rawQuery(
      'SELECT COUNT(*) AS count FROM audit_logs',
    );
    return rows.single['count']! as int;
  }

  Future<void> closeAndReopen() async {
    await _ledgerDatabase.close();
    await _ledgerDatabase.open(
      privacy: _PreparedPrivacy(_directory.path),
      databaseFactoryOverride: databaseFactoryFfi,
      preparedDirectoryOverride: _directory.path,
    );
    _bindRepositories();
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _ledgerDatabase.close();
    if (await _directory.exists()) {
      await _directory.delete(recursive: true);
    }
  }

  void _bindRepositories() {
    _catalog = SqliteCatalogRepository(_ledgerDatabase.database);
    _cashBills = SqliteCashBillRepository(_ledgerDatabase.database);
  }
}

final class _PreparedPrivacy implements LedgerPrivacy {
  const _PreparedPrivacy(this.path);

  final String path;

  @override
  Future<PreparedLedgerDirectory> prepareLedgerDirectory() async =>
      PreparedLedgerDirectory(path: path, backupExcludedVerified: true);
}
