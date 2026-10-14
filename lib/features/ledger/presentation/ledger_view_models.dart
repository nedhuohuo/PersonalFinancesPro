import 'package:flutter/foundation.dart' hide Category;
import 'package:personal_finances_pro/core/domain/local_date.dart';
import 'package:personal_finances_pro/core/domain/money.dart';
import 'package:personal_finances_pro/features/catalog/domain/catalog_models.dart';
import 'package:personal_finances_pro/features/catalog/domain/catalog_repository.dart';
import 'package:personal_finances_pro/features/ledger/domain/cash_bill_repository.dart';
import 'package:personal_finances_pro/features/ledger/domain/ledger_models.dart';

final class CashLedgerViewModel extends ChangeNotifier {
  CashLedgerViewModel({
    required CashBillRepository cashBillRepository,
    required CatalogRepository catalogRepository,
    DateTime Function()? now,
  }) : _cashBillRepository = cashBillRepository,
       _catalogRepository = catalogRepository,
       _now = now ?? DateTime.now {
    beginNewCashBill();
  }

  final CashBillRepository _cashBillRepository;
  final CatalogRepository _catalogRepository;
  final DateTime Function() _now;
  var _disposed = false;

  bool isLoading = false;
  bool isSaving = false;
  bool lastSaveCommitted = false;
  String? errorMessage;
  List<CashBill> bills = const [];
  List<Shop> shops = const [];
  List<AccountLabel> accounts = const [];
  List<Party> parties = const [];
  List<Category> categories = const [];

  String startDateText = '';
  String endDateText = '';
  BusinessScope? filterScope;
  int? filterCategoryId;
  int? filterPartyId;
  String noteQueryText = '';
  bool includeVoid = false;

  int? editingBillId;
  String businessDateText = '';
  CashDirection direction = CashDirection.expense;
  String amountText = '';
  int? shopId;
  int? categoryId;
  int? accountId;
  int? partyId;
  String noteText = '';
  bool _currentFormCommitted = false;
  final Set<int> _statusRefreshRequired = {};

  bool canChangeStatus(CashBill bill) =>
      !isSaving && !isLoading && !_statusRefreshRequired.contains(bill.id);

  bool get canSubmit => !isSaving && !_currentFormCommitted;

  List<Category> get activeCategories =>
      categories.where((category) => category.isActive).toList();
  List<Category> get activeDirectionCategories =>
      categories
          .where(
            (category) => category.isActive && category.direction == direction,
          )
          .toList();
  List<AccountLabel> get activeAccounts =>
      accounts.where((account) => account.isActive).toList();
  List<Party> get activeParties =>
      parties.where((party) => party.isActive).toList();
  List<Shop> get activeShops => shops.where((shop) => shop.isActive).toList();

  Future<void> reload() async {
    isLoading = true;
    errorMessage = null;
    _notify();
    try {
      await _reloadCatalogs();
      bills = await _cashBillRepository.listCashBills(_filter());
      _statusRefreshRequired.clear();
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      isLoading = false;
      _notify();
    }
  }

  Future<void> applyFilters() => reload();

  void beginNewCashBill() {
    editingBillId = null;
    businessDateText = LocalDate.todayLocal(_now()).value;
    direction = CashDirection.expense;
    amountText = '';
    shopId = null;
    categoryId = null;
    accountId = null;
    partyId = null;
    noteText = '';
    lastSaveCommitted = false;
    _currentFormCommitted = false;
    errorMessage = null;
    _notify();
  }

  void beginEditCashBill(CashBill bill) {
    editingBillId = bill.id;
    businessDateText = bill.businessDate.value;
    direction = bill.direction;
    amountText = bill.amount.format().replaceAll(',', '');
    shopId = bill.scope.shopId;
    categoryId = bill.categoryId;
    accountId = bill.accountId;
    partyId = bill.partyId;
    noteText = bill.note;
    lastSaveCommitted = false;
    _currentFormCommitted = false;
    errorMessage = null;
    _notify();
  }

  void setDirection(CashDirection value) {
    direction = value;
    if (categoryId != null &&
        !categories.any(
          (category) =>
              category.id == categoryId && category.direction == value,
        )) {
      categoryId = null;
    }
    _notify();
  }

  Future<void> saveFromForm() => _saveCashBill(_draftFromForm);

  Future<void> saveCashBill(CashBillDraft draft) => _saveCashBill(() => draft);

  Future<void> _saveCashBill(CashBillDraft Function() buildDraft) async {
    if (isSaving) return;
    if (_currentFormCommitted) {
      lastSaveCommitted = true;
      errorMessage = '已保存，请返回列表刷新；不会重复提交同一张现金账。';
      _notify();
      return;
    }
    isSaving = true;
    lastSaveCommitted = false;
    errorMessage = null;
    _notify();
    try {
      final draft = buildDraft();
      if (editingBillId == null) {
        await _cashBillRepository.createCashBill(draft);
      } else {
        await _cashBillRepository.updateCashBill(
          id: editingBillId!,
          draft: draft,
        );
      }
      _currentFormCommitted = true;
      lastSaveCommitted = true;
      await reload();
      if (errorMessage != null) {
        errorMessage = '已保存，但刷新失败：$errorMessage';
      }
    } catch (error) {
      lastSaveCommitted = false;
      errorMessage = error.toString();
    } finally {
      isSaving = false;
      _notify();
    }
  }

  /// Returns true only once the status mutation committed, even if refresh failed.
  Future<bool> voidBill(CashBill bill, String reason) =>
      _changeStatus(bill, reason, makeVoid: true);

  Future<bool> restoreBill(CashBill bill, String reason) =>
      _changeStatus(bill, reason, makeVoid: false);

  Future<bool> _changeStatus(
    CashBill bill,
    String reason, {
    required bool makeVoid,
  }) async {
    if (isSaving) return false;
    if (bill.isVoid == makeVoid ||
        _statusRefreshRequired.contains(bill.id) ||
        billById(bill.id)?.isVoid != bill.isVoid) {
      errorMessage = '状态已变更，请刷新；不会重复提交。';
      _notify();
      return false;
    }
    final action = makeVoid ? '作废' : '恢复';
    final trimmed = reason.trim();
    if (trimmed.isEmpty) {
      errorMessage = '请填写$action原因';
      _notify();
      return false;
    }
    isSaving = true;
    errorMessage = null;
    _notify();
    try {
      if (makeVoid) {
        await _cashBillRepository.voidCashBill(bill.id, reason: trimmed);
      } else {
        await _cashBillRepository.restoreCashBill(bill.id, reason: trimmed);
      }
      _statusRefreshRequired.add(bill.id);
      await reload();
      if (errorMessage != null) {
        errorMessage = '已$action，但刷新失败：$errorMessage';
      }
      return true;
    } catch (error) {
      errorMessage = error.toString();
      return false;
    } finally {
      isSaving = false;
      _notify();
    }
  }

  CashBill? billById(int id) {
    for (final bill in bills) {
      if (bill.id == id) return bill;
    }
    return null;
  }

  String shopName(int? id) =>
      id == null ? '公共' : shops.firstWhere((shop) => shop.id == id).name;
  String categoryName(int id) =>
      categories.firstWhere((category) => category.id == id).name;
  String accountName(int id) =>
      accounts.firstWhere((account) => account.id == id).name;
  String? partyName(int? id) =>
      id == null ? null : parties.firstWhere((party) => party.id == id).name;

  Future<void> _reloadCatalogs() async {
    shops = await _catalogRepository.listShops(includeInactive: true);
    accounts = await _catalogRepository.listAccountLabels(
      includeInactive: true,
    );
    parties = await _catalogRepository.listParties(includeInactive: true);
    categories = await _catalogRepository.listCategories(includeInactive: true);
    _selectDefaults();
  }

  void _selectDefaults() {
    accountId ??= activeAccounts.isEmpty ? null : activeAccounts.first.id;
    categoryId ??=
        activeDirectionCategories.isEmpty
            ? null
            : activeDirectionCategories.first.id;
  }

  CashBillFilter _filter() => CashBillFilter(
    startDate: _optionalDate(startDateText),
    endDate: _optionalDate(endDateText),
    scope: filterScope,
    categoryId: filterCategoryId,
    partyId: filterPartyId,
    noteQuery: noteQueryText.trim().isEmpty ? null : noteQueryText.trim(),
    includeVoid: includeVoid,
  );

  CashBillDraft _draftFromForm() {
    final selectedCategoryId = categoryId;
    final selectedAccountId = accountId;
    if (selectedCategoryId == null) throw const FormatException('请选择分类');
    if (selectedAccountId == null) throw const FormatException('请选择账户');
    return CashBillDraft(
      businessDate: LocalDate.parse(businessDateText.trim()),
      direction: direction,
      amount: Money.parsePositive(amountText),
      scope:
          shopId == null
              ? const BusinessScope.public()
              : BusinessScope.shop(shopId),
      categoryId: selectedCategoryId,
      accountId: selectedAccountId,
      partyId: partyId,
      note: noteText.trim(),
    );
  }

  LocalDate? _optionalDate(String text) {
    final trimmed = text.trim();
    return trimmed.isEmpty ? null : LocalDate.parse(trimmed);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
