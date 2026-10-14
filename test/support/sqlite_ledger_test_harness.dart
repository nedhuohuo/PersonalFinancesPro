import 'dart:io';

import 'package:personal_finances_pro/core/data/ledger_database.dart';
import 'package:personal_finances_pro/core/data/ledger_privacy.dart';
import 'package:personal_finances_pro/core/domain/local_date.dart';
import 'package:personal_finances_pro/core/domain/money.dart';
import 'package:personal_finances_pro/features/catalog/data/sqlite_catalog_repository.dart';
import 'package:personal_finances_pro/features/catalog/domain/catalog_models.dart';
import 'package:personal_finances_pro/features/catalog/domain/catalog_repository.dart';
import 'package:personal_finances_pro/features/dashboard/data/sqlite_dashboard_repository.dart';
import 'package:personal_finances_pro/features/dashboard/domain/dashboard_repository.dart';
import 'package:personal_finances_pro/features/ledger/data/sqlite_cash_bill_repository.dart';
import 'package:personal_finances_pro/features/ledger/data/sqlite_ledger_repository.dart';
import 'package:personal_finances_pro/features/ledger/domain/cash_bill_repository.dart';
import 'package:personal_finances_pro/features/ledger/domain/ledger_models.dart';
import 'package:personal_finances_pro/features/ledger/domain/ledger_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

final class SqliteLedgerTestHarness {
  SqliteLedgerTestHarness._({
    required Directory directory,
    required LedgerDatabase ledgerDatabase,
    required int defaultAccountId,
    required int defaultExpenseCategoryId,
    required int defaultIncomeCategoryId,
    required int resaleFeeCategoryId,
    required int defaultChannelId,
    required this.unusedExpenseCategoryId,
    required this.resaleIncomeCategoryId,
  }) : _directory = directory,
       _ledgerDatabase = ledgerDatabase,
       _defaultAccountId = defaultAccountId,
       _defaultExpenseCategoryId = defaultExpenseCategoryId,
       _defaultIncomeCategoryId = defaultIncomeCategoryId,
       _resaleFeeCategoryId = resaleFeeCategoryId,
       _defaultChannelId = defaultChannelId {
    _bindRepositories();
  }

  final Directory _directory;
  final LedgerDatabase _ledgerDatabase;
  final int _defaultAccountId;
  final int _defaultExpenseCategoryId;
  final int _defaultIncomeCategoryId;
  final int _resaleFeeCategoryId;
  final int _defaultChannelId;

  late SqliteCatalogRepository _catalog;
  late SqliteCashBillRepository _cashBills;
  late SqliteLedgerRepository _ledger;
  late SqliteDashboardRepository _dashboard;
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
    final income = await catalog.listCategories(
      direction: CashDirection.income,
    );
    final resaleIncome =
        (await catalog.listCategories(
          direction: CashDirection.income,
          role: CategoryRole.resaleIncome,
        )).single;
    final resaleFee =
        (await catalog.listCategories(
          direction: CashDirection.expense,
          role: CategoryRole.resaleFee,
        )).single;
    final channel = (await catalog.listResaleChannels()).first;
    return SqliteLedgerTestHarness._(
      directory: directory,
      ledgerDatabase: ledgerDatabase,
      defaultAccountId: accounts.first.id,
      defaultExpenseCategoryId: expense.last.id,
      defaultIncomeCategoryId: income.first.id,
      resaleFeeCategoryId: resaleFee.id,
      defaultChannelId: channel.id,
      unusedExpenseCategoryId: expense.last.id,
      resaleIncomeCategoryId: resaleIncome.id,
    );
  }

  Database get database => _ledgerDatabase.database;
  CatalogRepository get catalog => _catalog;
  CashBillRepository get cashBills => _cashBills;
  LedgerRepository get ledger => _ledger;
  DashboardRepository get dashboard => _dashboard;
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

  Future<int> seedPurchase({required String total, String paid = '0'}) async {
    final supplier = await createParty(
      name: '测试厂家$total-$paid-${DateTime.now().microsecondsSinceEpoch}',
      kind: PartyKind.supplier,
    );
    final id = await _ledger.createPurchase(
      PurchaseDraft(
        supplierId: supplier.id,
        scope: const BusinessScope.public(),
        businessDate: LocalDate.parse('2026-10-14'),
        items: [
          PurchaseItemDraft(
            description: '测试采购',
            quantity: 1,
            unitPrice: Money.parsePositive(total),
          ),
        ],
        supplierFreight: Money.zero,
      ),
    );
    if (paid != '0' && paid != '0.00') {
      await _ledger.recordPurchasePayment(
        purchaseId: id,
        payment: purchasePayment(amount: paid),
      );
    }
    return id;
  }

  Future<int> seedPaidRefund({
    required int purchaseId,
    required String amount,
  }) async {
    await _ledger.adjustPurchase(
      PurchaseAdjustmentDraft(
        purchaseId: purchaseId,
        kind: PurchaseAdjustmentKind.paidRefund,
        amount: Money.parsePositive(amount),
        reason: '测试退款',
        categoryId: _defaultIncomeCategoryId,
        accountId: _defaultAccountId,
        businessDate: LocalDate.parse('2026-10-14'),
      ),
    );
    final rows = await database.query(
      'purchase_adjustments',
      where: 'purchase_id = ?',
      whereArgs: [purchaseId],
      orderBy: 'id DESC',
      limit: 1,
    );
    return rows.single['id']! as int;
  }

  Future<CashBill> linkedCashBillForAdjustment(int adjustmentId) async {
    final rows = await database.query(
      'purchase_adjustments',
      where: 'id = ?',
      whereArgs: [adjustmentId],
      limit: 1,
    );
    final cashId = rows.single['cash_bill_id']! as int;
    return (await _cashBills.listCashBills(
      const CashBillFilter(includeVoid: true),
    )).singleWhere((bill) => bill.id == cashId);
  }

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

  Future<int> seedProblemResale({
    required String amount,
    String fee = '0',
  }) async {
    final buyer = await createParty(
      name: '测试买家$amount-$fee-${DateTime.now().microsecondsSinceEpoch}',
      kind: PartyKind.buyer,
    );
    final id = await _ledger.createProblemResale(
      ProblemResaleDraft(
        scope: const BusinessScope.public(),
        businessDate: LocalDate.parse('2026-10-14'),
        description: '测试问题件',
        quantity: 1,
        incomeAmount: Money.parsePositive(amount),
        incomeAccountId: _defaultAccountId,
        incomeCategoryId: resaleIncomeCategoryId,
        buyerId: buyer.id,
        channelId: _defaultChannelId,
        issueNote: '测试',
        fees:
            fee == '0' || fee == '0.00'
                ? const []
                : [
                  ProblemResaleFeeDraft(
                    categoryId: _resaleFeeCategoryId,
                    accountId: _defaultAccountId,
                    amount: Money.parsePositive(fee),
                  ),
                ],
      ),
    );
    return id;
  }

  Future<int> seedCourierTopUpThenConsumeAll() async {
    final courierId = await _ledger.createCourierAccount(
      CourierAccountDraft(
        name: '测试快递${DateTime.now().microsecondsSinceEpoch}',
        openingBalance: Money.zero,
        businessDate: LocalDate.parse('2026-10-01'),
      ),
    );
    await _ledger.recordCourierTopUp(
      courierTopUp(
        courierAccountId: courierId,
        scope: const BusinessScope.public(),
        amount: '10',
      ),
    );
    final topUp = (await _ledger.getCourierAccountDetail(
      courierId,
    )).events.singleWhere((event) => event.eventType == CourierEventType.topUp);
    await _ledger.recordCourierConsume(
      CourierConsumeDraft(
        courierAccountId: courierId,
        scope: const BusinessScope.public(),
        businessDate: LocalDate.parse('2026-10-15'),
        amount: Money.parsePositive('10'),
      ),
    );
    return topUp.id;
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
    _ledger = SqliteLedgerRepository(
      database: _ledgerDatabase.database,
      cashBills: _cashBills,
    );
    _dashboard = SqliteDashboardRepository(_ledgerDatabase.database);
  }
}

final class _PreparedPrivacy implements LedgerPrivacy {
  const _PreparedPrivacy(this.path);

  final String path;

  @override
  Future<PreparedLedgerDirectory> prepareLedgerDirectory() async =>
      PreparedLedgerDirectory(path: path, backupExcludedVerified: true);
}
