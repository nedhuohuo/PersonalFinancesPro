import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finances_pro/app/app.dart';
import 'package:personal_finances_pro/app/app_dependencies.dart';
import 'package:personal_finances_pro/core/domain/local_date.dart';
import 'package:personal_finances_pro/core/domain/money.dart';
import 'package:personal_finances_pro/features/catalog/domain/catalog_models.dart';
import 'package:personal_finances_pro/features/catalog/domain/catalog_repository.dart';
import 'package:personal_finances_pro/features/dashboard/domain/dashboard_repository.dart';
import 'package:personal_finances_pro/features/dashboard/domain/dashboard_snapshots.dart';
import 'package:personal_finances_pro/features/ledger/domain/cash_bill_repository.dart';
import 'package:personal_finances_pro/features/ledger/domain/ledger_models.dart';
import 'package:personal_finances_pro/features/ledger/domain/ledger_repository.dart';

final validDraft = CashBillDraft(
  businessDate: LocalDate.parse('2026-10-14'),
  direction: CashDirection.expense,
  amount: Money.fromCents(100),
  scope: const BusinessScope.public(),
  categoryId: 1,
  accountId: 1,
);

final class FakeAppRepositories {
  FakeAppRepositories({
    required this.catalog,
    required this.cashBills,
    required this.ledger,
    required this.dashboard,
  });

  factory FakeAppRepositories.withLedgerError(Object error) {
    return FakeAppRepositories(
      catalog: RecordingCatalogRepository(error: error),
      cashBills: RecordingCashBillRepository(refreshError: error),
      ledger: RecordingLedgerRepository(error: error),
      dashboard: RecordingDashboardRepository(error: error),
    );
  }

  factory FakeAppRepositories.empty() {
    final catalog = RecordingCatalogRepository();
    final cashBills = RecordingCashBillRepository();
    return FakeAppRepositories(
      catalog: catalog,
      cashBills: cashBills,
      ledger: RecordingLedgerRepository(),
      dashboard: RecordingDashboardRepository(cashBills: cashBills),
    );
  }

  final CatalogRepository catalog;
  final CashBillRepository cashBills;
  final LedgerRepository ledger;
  final DashboardRepository dashboard;
}

Future<void> pumpLedgerAppWithRepositories(
  WidgetTester tester,
  FakeAppRepositories repositories,
) async {
  await tester.pumpWidget(
    ShopLedgerApp(dependenciesBootstrap: _FakeBootstrap(repositories)),
  );
  await tester.pumpAndSettle();
}

final class _FakeBootstrap implements AppDependenciesBootstrap {
  const _FakeBootstrap(this.repositories);

  final FakeAppRepositories repositories;

  @override
  Future<AppDependencies> open() async => AppDependencies(
    catalogRepository: repositories.catalog,
    cashBillRepository: repositories.cashBills,
    ledgerRepository: repositories.ledger,
    dashboardRepository: repositories.dashboard,
    close: () async {},
  );
}

final class RecordingCatalogRepository implements CatalogRepository {
  RecordingCatalogRepository({
    List<Shop> shops = const [],
    List<Category> categories = const [],
    List<AccountLabel> accounts = const [],
    List<Party> parties = const [],
    List<ResaleChannel> channels = const [],
    this.error,
  }) : _shops =
           shops.isEmpty
               ? [const Shop(id: 1, name: '测试店铺', isActive: true)]
               : List.of(shops),
       _categories =
           categories.isEmpty
               ? [
                 const Category(
                   id: 1,
                   name: '测试支出',
                   direction: CashDirection.expense,
                   role: CategoryRole.ordinary,
                   isSystem: false,
                   isActive: true,
                 ),
                 const Category(
                   id: 2,
                   name: '测试收入',
                   direction: CashDirection.income,
                   role: CategoryRole.ordinary,
                   isSystem: false,
                   isActive: true,
                 ),
               ]
               : List.of(categories),
       _accounts =
           accounts.isEmpty
               ? [const AccountLabel(id: 1, name: '测试账户', isActive: true)]
               : List.of(accounts),
       _parties = List.of(parties),
       _channels =
           channels.isEmpty
               ? [const ResaleChannel(id: 1, name: '测试渠道', isActive: true)]
               : List.of(channels);

  final Object? error;
  int _listCategoriesCalls = 0;
  int get listCategoriesCalls => _listCategoriesCalls;
  final List<Shop> _shops;
  final List<Category> _categories;
  final List<AccountLabel> _accounts;
  final List<Party> _parties;
  final List<ResaleChannel> _channels;

  @override
  Future<void> ensureDefaultCatalogs() async {}

  @override
  Future<List<Shop>> listShops({bool includeInactive = false}) async {
    _maybeThrow();
    return _shops.where((item) => includeInactive || item.isActive).toList();
  }

  @override
  Future<Shop> createShop({required String name}) async {
    final item = Shop(id: _shops.length + 1, name: name, isActive: true);
    _shops.add(item);
    return item;
  }

  @override
  Future<Shop> renameShop({required int id, required String name}) async {
    final old = _shops.firstWhere((item) => item.id == id);
    final item = Shop(id: id, name: name, isActive: old.isActive);
    _shops[_shops.indexOf(old)] = item;
    return item;
  }

  @override
  Future<void> deactivateShop(int id) async => _replaceShop(id, false);

  @override
  Future<List<AccountLabel>> listAccountLabels({
    bool includeInactive = false,
  }) async {
    _maybeThrow();
    return _accounts.where((item) => includeInactive || item.isActive).toList();
  }

  @override
  Future<AccountLabel> createAccountLabel({required String name}) async {
    final item = AccountLabel(
      id: _accounts.length + 1,
      name: name,
      isActive: true,
    );
    _accounts.add(item);
    return item;
  }

  @override
  Future<AccountLabel> renameAccountLabel({
    required int id,
    required String name,
  }) async {
    final old = _accounts.firstWhere((item) => item.id == id);
    final item = AccountLabel(id: id, name: name, isActive: old.isActive);
    _accounts[_accounts.indexOf(old)] = item;
    return item;
  }

  @override
  Future<void> deactivateAccountLabel(int id) async =>
      _replaceAccount(id, false);

  @override
  Future<List<Party>> listParties({
    PartyKind? kind,
    bool includeInactive = false,
  }) async {
    _maybeThrow();
    return _parties
        .where(
          (item) =>
              (includeInactive || item.isActive) &&
              (kind == null || item.kind == kind),
        )
        .toList();
  }

  @override
  Future<Party> createParty({
    required String name,
    required PartyKind kind,
  }) async {
    final item = Party(
      id: _parties.length + 1,
      name: name,
      kind: kind,
      isActive: true,
    );
    _parties.add(item);
    return item;
  }

  @override
  Future<Party> renameParty({required int id, required String name}) async {
    final old = _parties.firstWhere((item) => item.id == id);
    final item = Party(
      id: id,
      name: name,
      kind: old.kind,
      isActive: old.isActive,
    );
    _parties[_parties.indexOf(old)] = item;
    return item;
  }

  @override
  Future<void> deactivateParty(int id) async => _replaceParty(id, false);

  @override
  Future<List<Category>> listCategories({
    CashDirection? direction,
    CategoryRole? role,
    bool includeInactive = false,
  }) async {
    _listCategoriesCalls++;
    _maybeThrow();
    return _categories
        .where(
          (item) =>
              (includeInactive || item.isActive) &&
              (direction == null || item.direction == direction) &&
              (role == null || item.role == role),
        )
        .toList();
  }

  @override
  Future<Category> createCategory({
    required String name,
    required CashDirection direction,
  }) async {
    final item = Category(
      id: _categories.length + 1,
      name: name,
      direction: direction,
      role: CategoryRole.ordinary,
      isSystem: false,
      isActive: true,
    );
    _categories.add(item);
    return item;
  }

  @override
  Future<Category> renameCategory({
    required int id,
    required String name,
  }) async {
    final old = _categories.firstWhere((item) => item.id == id);
    final item = Category(
      id: id,
      name: name,
      direction: old.direction,
      role: old.role,
      isSystem: old.isSystem,
      isActive: old.isActive,
    );
    _categories[_categories.indexOf(old)] = item;
    return item;
  }

  @override
  Future<void> deactivateCategory(int id) async => _replaceCategory(id, false);

  @override
  Future<List<ResaleChannel>> listResaleChannels({
    bool includeInactive = false,
  }) async {
    _maybeThrow();
    return _channels.where((item) => includeInactive || item.isActive).toList();
  }

  @override
  Future<ResaleChannel> createResaleChannel({required String name}) async {
    final item = ResaleChannel(
      id: _channels.length + 1,
      name: name,
      isActive: true,
    );
    _channels.add(item);
    return item;
  }

  @override
  Future<ResaleChannel> renameResaleChannel({
    required int id,
    required String name,
  }) async {
    final old = _channels.firstWhere((item) => item.id == id);
    final item = ResaleChannel(id: id, name: name, isActive: old.isActive);
    _channels[_channels.indexOf(old)] = item;
    return item;
  }

  @override
  Future<void> deactivateResaleChannel(int id) async =>
      _replaceChannel(id, false);

  void _replaceShop(int id, bool active) {
    final old = _shops.firstWhere((item) => item.id == id);
    _shops[_shops.indexOf(old)] = Shop(
      id: id,
      name: old.name,
      isActive: active,
    );
  }

  void _replaceAccount(int id, bool active) {
    final old = _accounts.firstWhere((item) => item.id == id);
    _accounts[_accounts.indexOf(old)] = AccountLabel(
      id: id,
      name: old.name,
      isActive: active,
    );
  }

  void _replaceParty(int id, bool active) {
    final old = _parties.firstWhere((item) => item.id == id);
    _parties[_parties.indexOf(old)] = Party(
      id: id,
      name: old.name,
      kind: old.kind,
      isActive: active,
    );
  }

  void _replaceCategory(int id, bool active) {
    final old = _categories.firstWhere((item) => item.id == id);
    _categories[_categories.indexOf(old)] = Category(
      id: id,
      name: old.name,
      direction: old.direction,
      role: old.role,
      isSystem: old.isSystem,
      isActive: active,
    );
  }

  void _replaceChannel(int id, bool active) {
    final old = _channels.firstWhere((item) => item.id == id);
    _channels[_channels.indexOf(old)] = ResaleChannel(
      id: id,
      name: old.name,
      isActive: active,
    );
  }

  void _maybeThrow() {
    final value = error;
    if (value != null) throw value;
  }
}

final class RecordingCashBillRepository implements CashBillRepository {
  RecordingCashBillRepository({
    this.refreshThrows = false,
    this.commitThrows = false,
    Object? refreshError,
    List<CashBill> bills = const [],
  }) : refreshError = refreshError ?? Exception('刷新失败'),
       _bills = List.of(bills);

  bool refreshThrows;
  bool commitThrows;
  Object? statusError;
  Future<void>? statusGate;
  CashBillFilter? lastFilter;
  final Object refreshError;
  final List<CashBill> _bills;
  int _nextId = 1;
  int _createCashBillCalls = 0;
  int get createCashBillCalls => _createCashBillCalls;
  int updateCashBillCalls = 0;
  int voidCashBillCalls = 0;
  int restoreCashBillCalls = 0;

  @override
  Future<CashBill> createCashBill(CashBillDraft draft) async {
    _createCashBillCalls++;
    if (commitThrows) throw Exception('提交失败');
    final bill = _billFromDraft(_nextId++, draft);
    _bills.add(bill);
    return bill;
  }

  @override
  Future<CashBill> updateCashBill({
    required int id,
    required CashBillDraft draft,
  }) async {
    updateCashBillCalls++;
    if (commitThrows) throw Exception('提交失败');
    final index = _bills.indexWhere((item) => item.id == id);
    final bill = _billFromDraft(id, draft);
    if (index >= 0) _bills[index] = bill;
    return bill;
  }

  @override
  Future<void> voidCashBill(int id, {required String reason}) async {
    voidCashBillCalls++;
    await statusGate;
    if (statusError != null) throw statusError!;
    _setVoid(id, true);
  }

  @override
  Future<void> restoreCashBill(int id, {required String reason}) async {
    restoreCashBillCalls++;
    await statusGate;
    if (statusError != null) throw statusError!;
    _setVoid(id, false);
  }

  @override
  Future<List<CashBill>> listCashBills(CashBillFilter filter) async {
    lastFilter = filter;
    if (refreshThrows) throw refreshError;
    return _bills
        .where(
          (bill) =>
              (filter.includeVoid || !bill.isVoid) &&
              (filter.startDate == null ||
                  bill.businessDate.value.compareTo(filter.startDate!.value) >=
                      0) &&
              (filter.endDate == null ||
                  bill.businessDate.value.compareTo(filter.endDate!.value) <=
                      0) &&
              (filter.scope == null ||
                  bill.scope.shopId == filter.scope!.shopId) &&
              (filter.categoryId == null ||
                  bill.categoryId == filter.categoryId) &&
              (filter.partyId == null || bill.partyId == filter.partyId) &&
              (filter.noteQuery == null ||
                  bill.note.contains(filter.noteQuery!)),
        )
        .toList();
  }

  CashBill _billFromDraft(int id, CashBillDraft draft) {
    final now = DateTime.utc(2026, 10, 14);
    return CashBill(
      id: id,
      businessDate: draft.businessDate,
      direction: draft.direction,
      amount: draft.amount,
      scope: draft.scope,
      categoryId: draft.categoryId,
      accountId: draft.accountId,
      partyId: draft.partyId,
      note: draft.note,
      entrySource: EntrySource.manual,
      businessOrigin: BusinessOrigin.ordinary,
      linkedType: null,
      linkedId: null,
      isVoid: false,
      createdAtUtc: now,
      updatedAtUtc: now,
    );
  }

  void _setVoid(int id, bool value) {
    final old = _bills.firstWhere((item) => item.id == id);
    _bills[_bills.indexOf(old)] = CashBill(
      id: old.id,
      businessDate: old.businessDate,
      direction: old.direction,
      amount: old.amount,
      scope: old.scope,
      categoryId: old.categoryId,
      accountId: old.accountId,
      partyId: old.partyId,
      note: old.note,
      entrySource: old.entrySource,
      businessOrigin: old.businessOrigin,
      linkedType: old.linkedType,
      linkedId: old.linkedId,
      isVoid: value,
      createdAtUtc: old.createdAtUtc,
      updatedAtUtc: old.updatedAtUtc,
    );
  }
}

final class RecordingDashboardRepository implements DashboardRepository {
  RecordingDashboardRepository({
    this.error,
    RecordingCashBillRepository? cashBills,
  }) : _cashBills = cashBills;

  final Object? error;
  final RecordingCashBillRepository? _cashBills;

  @override
  Future<DashboardSnapshot> loadDashboardSnapshot({
    required LocalDate monthStart,
    required LocalDate monthEnd,
    BusinessScope? scope,
  }) async {
    final value = error;
    if (value != null) throw value;
    final bills =
        await (_cashBills?.listCashBills(const CashBillFilter()) ??
            Future.value(<CashBill>[]));
    final expense = Money.sumCents(
      bills
          .where((bill) => bill.direction == CashDirection.expense)
          .map((bill) => bill.amount.cents),
    );
    final resaleIncome = Money.sumCents(
      bills
          .where((bill) => bill.businessOrigin == BusinessOrigin.resaleIncome)
          .map((bill) => bill.amount.cents),
    );
    return DashboardSnapshot(
      monthCashExpense: expense,
      supplierPayable: Money.zero,
      monthResaleIncome: resaleIncome,
      recentBills: bills.reversed.take(5),
    );
  }

  @override
  Future<LedgerDetailSnapshot> loadLedgerDetailSnapshot({
    required LocalDate startDate,
    required LocalDate endDate,
    BusinessScope? scope,
  }) async => const LedgerDetailSnapshot(
    cashIncome: Money.zero,
    cashExpense: Money.zero,
    cashNet: Money.zero,
    purchaseEffective: Money.zero,
    purchasePaidNet: Money.zero,
    purchasePayable: Money.zero,
    resaleIncome: Money.zero,
    resaleFees: Money.zero,
    resaleNetRecovery: Money.zero,
    courierTopUp: Money.zero,
    courierConsume: Money.zero,
    globalCourierRecordedBalance: Money.zero,
  );
}

final class RecordingLedgerRepository implements LedgerRepository {
  RecordingLedgerRepository({this.error});
  Object? error;
  Future<void>? purchaseGate;
  Object? purchaseDetailError;
  PurchaseDetail? purchaseDetail;
  int createPurchaseCalls = 0;
  PurchaseDraft? lastPurchaseDraft;
  PurchasePaymentDraft? lastInitialPayment;

  Never _throw() =>
      throw (error ?? UnimplementedError('not used in widget tests'));

  @override
  Future<int> createPurchase(
    PurchaseDraft draft, {
    PurchasePaymentDraft? initialPayment,
  }) async {
    createPurchaseCalls++;
    lastPurchaseDraft = draft;
    lastInitialPayment = initialPayment;
    await purchaseGate;
    if (error != null) throw error!;
    return purchaseDetail?.purchase.id ?? _throw();
  }

  @override
  Future<void> recordPurchasePayment({
    required int purchaseId,
    required PurchasePaymentDraft payment,
  }) async => _throw();
  @override
  Future<void> voidPurchasePayment({
    required int paymentId,
    required String reason,
  }) async => _throw();
  @override
  Future<void> restorePurchasePayment({
    required int paymentId,
    required String reason,
  }) async => _throw();
  @override
  Future<void> voidPurchaseWithoutActivePayments({
    required int purchaseId,
    required String reason,
  }) async => _throw();
  @override
  Future<void> restorePurchase({
    required int purchaseId,
    required String reason,
  }) async => _throw();
  @override
  Future<void> adjustPurchase(PurchaseAdjustmentDraft draft) async => _throw();
  @override
  Future<void> voidPurchaseAdjustment({
    required int adjustmentId,
    required String reason,
  }) async => _throw();
  @override
  Future<void> restorePurchaseAdjustment({
    required int adjustmentId,
    required String reason,
  }) async => _throw();
  @override
  Future<List<Purchase>> listPurchases(PurchaseFilter filter) async => const [];
  @override
  Future<PurchaseDetail> getPurchaseDetail(int purchaseId) async {
    if (purchaseDetailError != null) throw purchaseDetailError!;
    return purchaseDetail ?? _throw();
  }

  @override
  Future<int> createSupplierOpeningDebt(SupplierOpeningDebtDraft draft) async =>
      _throw();
  @override
  Future<void> paySupplierOpeningDebt({
    required int openingDebtId,
    required PurchasePaymentDraft payment,
  }) async => _throw();
  @override
  Future<void> voidSupplierOpeningDebtPayment({
    required int paymentId,
    required String reason,
  }) async => _throw();
  @override
  Future<void> restoreSupplierOpeningDebtPayment({
    required int paymentId,
    required String reason,
  }) async => _throw();
  @override
  Future<List<SupplierOpeningDebt>> listSupplierOpeningDebts({
    BusinessScope? scope,
    int? supplierId,
    bool includeVoid = false,
  }) async => const [];
  @override
  Future<SupplierOpeningDebtDetail> getSupplierOpeningDebtDetail(
    int openingDebtId,
  ) async => _throw();
  @override
  Future<int> createProblemResale(ProblemResaleDraft draft) async => _throw();
  @override
  Future<void> voidProblemResale({
    required int resaleId,
    required String reason,
  }) async => _throw();
  @override
  Future<void> restoreProblemResale({
    required int resaleId,
    required String reason,
  }) async => _throw();
  @override
  Future<List<ProblemResale>> listProblemResales(
    ProblemResaleFilter filter,
  ) async => const [];
  @override
  Future<ProblemResaleDetail> getProblemResaleDetail(int resaleId) async =>
      _throw();
  @override
  Future<int> createCourierAccount(CourierAccountDraft draft) async => _throw();
  @override
  Future<void> recordCourierTopUp(CourierCashEventDraft draft) async =>
      _throw();
  @override
  Future<void> recordCourierConsume(CourierConsumeDraft draft) async =>
      _throw();
  @override
  Future<void> recordCourierRefund(CourierCashEventDraft draft) async =>
      _throw();
  @override
  Future<void> voidCourierEvent({
    required int eventId,
    required String reason,
  }) async => _throw();
  @override
  Future<void> restoreCourierEvent({
    required int eventId,
    required String reason,
  }) async => _throw();
  @override
  Future<List<CourierAccount>> listCourierAccounts({
    bool includeInactive = false,
  }) async => const [];
  @override
  Future<CourierAccountDetail> getCourierAccountDetail(
    int courierAccountId,
  ) async => _throw();
}
