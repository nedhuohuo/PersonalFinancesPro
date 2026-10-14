# Local Ledger Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the approved local SQLite ledger stage with persisted catalog records, ordinary cash bills, procurement/payment rules, problem-goods resale, courier prepaid records, real snapshot totals and reachable manual Cupertino flows, while keeping AI send/key/confirmation disabled.

**Architecture:** Pure Dart domain models/repository contracts sit under `lib/features/*/domain` and `lib/core/domain`; SQLite, privacy setup and row mapping sit in `data` folders; the existing Cupertino router/page shell stays the UI entry point and uses provider/ChangeNotifier. Production database opening is bound to a backup-excluded ledger directory returned by the privacy contract, linked business writes use one SQLite transaction, aggregate caps are checked before commit, and UI state refreshes only after committed repository results.

**Tech Stack:** Flutter stable 3.29.2 / Dart 3.7.2, Cupertino, provider, go_router, existing `Money`, `sqflite` 2.4.2, `path` 1.9.1, dev-only `sqflite_common_ffi` 2.3.5, flutter_test.

**Spec:** `docs/superpowers/specs/2026-10-13-shop-ledger-design.md`

## Global Constraints

- Flutter 开发，支持 Android 与 iOS；两端统一采用 Apple 风格 Cupertino 界面。
- 应用标识使用 `dev.nedhuohuo.personalfinancespro`。
- 本地优先：SQLite 保存业务数据；本计划只实现本地账本，不实现 CSV/report subsystem、完整 JSON 备份/恢复或真实 AI。
- 首版以人民币为唯一货币。
- 金额以整数分存储和计算，不用 `double` 处理金额；单笔及汇总金额不得超过 `9,000,000,000,000,000` 分，越界拒绝操作。
- 金额输入从十进制字符串精确解析，最多两位小数；超出精度要求用户改正，不静默舍入。
- 业务日期以严格 `YYYY-MM-DD` 保存；审计时间以 UTC 保存。
- Runtime data libraries are pinned to `sqflite: 2.4.2` and `path: 1.9.1`; actual DB tests use dev-only `sqflite_common_ffi: 2.3.5` with temporary SQL files and reopen checks.
- Domain is pure Dart and must not import Flutter, SQLite, HTTP or plugins; `tool/check_domain_boundaries.dart` remains a required gate.
- Clean boundaries use small repository contracts where the UI/domain require them; do not add generic BaseRepository/EventBus/service locator, one interface per table/DTO, or production stubs.
- Stable local IDs use SQLite-generated `INTEGER PRIMARY KEY AUTOINCREMENT`; no homegrown UUID generator.
- 已有账目引用的资料不允许物理删除；停用保留历史账单；unchanged edits/restores may keep inactive historical references, but new assignments require active references.
- 账户标签只标记收付款来源，不计算真实银行/微信/支付宝余额。
- 采购单、付款、厂家退款、问题件收入及关联费用、快递预付事件必须在事务内原子保存；linked bills cannot be edited or voided through generic cash flows.
- Procurement rules preserve `0 <= paidNet <= effective payable`; no supplier prepayment in this stage.
- Courier consume creates no second cash expense; backdated/history void/restore cannot make any later ledger balance negative.
- Operation links are authoritative for resale income/refunds/snapshots; category names/roles never determine business identity.
- Monetary aggregation for snapshots and write guards must not rely on SQLite `SUM()` over money columns; aggregate cents in Dart with `BigInt` before converting to `Money`.
- BEFORE first production data write, exclude the actual ledger DB directory from automatic system cloud backup; failed privacy setup blocks opening/writing with a clear error and never clears or replaces the store.
- Catalog presets are generic categories/account labels only; no fake shops, parties, transactions or demonstration rows.
- Preserve `.gitignore` database/WAL/backup/key/native-cache protections.
- AI send/key/confirmation remains disabled in Flutter UI for this stage.
- Public docs use `$FLUTTER_SDK` examples, never local machine SDK paths.

---

## Scope split and ownership

| Unit | Independent review boundary | Main risk covered |
|---|---|---|
| 1 | Pure domain contracts, read DTOs, value objects and calculation functions | Exact APIs, status lifecycle names, courier scope and aggregate rules for later units |
| 2 | SQLite dependencies, privacy-bound database open, schema, catalog store and ordinary cash store | Real persistence/reopen, native backup source checks, no fake rows, completed cash-only contract |
| 3 | Full business repository and dashboard repository | Procurement, refunds, resale fees, courier invariants, lifecycle operations, read models and write-time aggregate guards |
| 4 | Provider bootstrap, dashboard/ledger/catalog/manual cash UI | Existing shell reads real data, bootstrap privacy errors block fake stores, AI stays disabled |
| 5 | Manual procurement/resale/courier/detail/status UI | Reachable native forms and status flows for required business operations |
| 6 | Integration checks, docs, CI and privacy verification | End-to-end SQL proof, reusable fixtures, README/CI/.gitignore evidence |

## File map

### Existing files to modify

- `pubspec.yaml`: add pinned SQLite runtime libs and dev-only FFI test lib.
- `lib/core/domain/money.dart`: keep exact existing API; add `Money.checkedProduct({required int quantity, required Money unitPrice})` and `Money.sumCents(Iterable<int> centsValues)`.
- `lib/app/app.dart`: inject dependencies with provider and keep one `StatefulShellRoute.indexedStack` + one `CupertinoTabBar`.
- `lib/app/presentation/dashboard_page.dart`: replace placeholders with repository-backed snapshot cards.
- `lib/app/presentation/ledger_page.dart`: replace placeholders with real empty state, lists and entry points.
- `lib/app/presentation/settings_page.dart`: add reachable catalog and data-safety rows; no enabled backup/AI credential flows.
- `lib/app/presentation/ai_page.dart`: keep send and confirmation disabled.
- `test/app/navigation_test.dart`: update expectations from placeholders to real empty persisted state and disabled AI.
- `tool/check_domain_boundaries.dart`: keep decoded import/export scanner; the normal `lib` scan covers new domain folders.
- `android/app/src/main/AndroidManifest.xml`: add backup exclusion attributes before database writes.
- `ios/Runner/AppDelegate.swift`: add a minimal MethodChannel for iOS ledger directory backup exclusion.
- `.gitignore`, `README.md`, `.github/workflows/flutter.yml`: verify protections and commands.

### New files to create

- `lib/core/domain/local_date.dart`
- `lib/core/data/ledger_privacy.dart`
- `lib/core/data/ledger_database.dart`
- `lib/core/data/ledger_schema.dart`
- `lib/core/data/sqlite_aggregate_guard.dart`
- `lib/core/data/sqlite_statement.dart`
- `lib/features/catalog/domain/catalog_models.dart`
- `lib/features/catalog/domain/catalog_repository.dart`
- `lib/features/catalog/data/sqlite_catalog_repository.dart`
- `lib/features/catalog/presentation/catalog_view_model.dart`
- `lib/features/catalog/presentation/catalog_pages.dart`
- `lib/features/ledger/domain/ledger_models.dart`
- `lib/features/ledger/domain/cash_bill_repository.dart`
- `lib/features/ledger/domain/ledger_repository.dart`
- `lib/features/ledger/domain/ledger_calculations.dart`
- `lib/features/ledger/data/sqlite_cash_bill_repository.dart`
- `lib/features/ledger/data/sqlite_ledger_repository.dart`
- `lib/features/ledger/presentation/ledger_view_models.dart`
- `lib/features/ledger/presentation/cash_bill_pages.dart`
- `lib/features/ledger/presentation/procurement_pages.dart`
- `lib/features/ledger/presentation/problem_resale_pages.dart`
- `lib/features/ledger/presentation/courier_pages.dart`
- `lib/features/ledger/presentation/ledger_detail_pages.dart`
- `lib/features/dashboard/domain/dashboard_snapshots.dart`
- `lib/features/dashboard/domain/dashboard_repository.dart`
- `lib/features/dashboard/data/sqlite_dashboard_repository.dart`
- `lib/features/dashboard/presentation/dashboard_view_model.dart`
- `lib/app/app_dependencies.dart`
- `android/app/src/main/res/xml/backup_rules.xml`
- `android/app/src/main/res/xml/data_extraction_rules.xml`
- `test/support/sqlite_ledger_test_harness.dart`
- `test/support/widget_test_app.dart`
- Domain/data/UI tests listed inside each task.

## Shared domain contract

Tasks must use these exact names so independently reviewed units compose without renaming.

```dart
// lib/core/domain/local_date.dart
final class LocalDate implements Comparable<LocalDate> {
  const LocalDate._(this.value);
  final String value;
  factory LocalDate.parse(String input);
  factory LocalDate.todayLocal(DateTime now);
  @override
  int compareTo(LocalDate other);
}
```

```dart
// lib/features/catalog/domain/catalog_models.dart
enum BusinessScopeType { public, shop }
enum PartyKind { supplier, buyer, courier, other }
enum CashDirection { income, expense }

enum CategoryRole {
  ordinary,
  purchasePayment,
  supplierRefund,
  resaleIncome,
  resaleFee,
  courierTopUp,
  courierRefund,
  openingDebtPayment,
}

typedef CatalogId = int;

final class BusinessScope {
  const BusinessScope.public() : shopId = null;
  const BusinessScope.shop(this.shopId);
  final int? shopId;
  BusinessScopeType get type => shopId == null ? BusinessScopeType.public : BusinessScopeType.shop;
}

final class Shop {
  const Shop({required this.id, required this.name, required this.isActive});
  final int id;
  final String name;
  final bool isActive;
}

final class AccountLabel {
  const AccountLabel({required this.id, required this.name, required this.isActive});
  final int id;
  final String name;
  final bool isActive;
}

final class Party {
  const Party({required this.id, required this.name, required this.kind, required this.isActive});
  final int id;
  final String name;
  final PartyKind kind;
  final bool isActive;
}

final class Category {
  const Category({required this.id, required this.name, required this.direction, required this.role, required this.isSystem, required this.isActive});
  final int id;
  final String name;
  final CashDirection direction;
  final CategoryRole role; // suggestion/default role only; never determines business identity.
  final bool isSystem;
  final bool isActive;
}

final class ResaleChannel {
  const ResaleChannel({required this.id, required this.name, required this.isActive});
  final int id;
  final String name;
  final bool isActive;
}
```

```dart
// lib/features/catalog/domain/catalog_repository.dart
abstract interface class CatalogRepository {
  Future<void> ensureDefaultCatalogs();
  Future<List<Shop>> listShops({bool includeInactive = false});
  Future<Shop> createShop({required String name});
  Future<Shop> renameShop({required int id, required String name});
  Future<void> deactivateShop(int id);

  Future<List<AccountLabel>> listAccountLabels({bool includeInactive = false});
  Future<AccountLabel> createAccountLabel({required String name});
  Future<AccountLabel> renameAccountLabel({required int id, required String name});
  Future<void> deactivateAccountLabel(int id);

  Future<List<Party>> listParties({PartyKind? kind, bool includeInactive = false});
  Future<Party> createParty({required String name, required PartyKind kind});
  Future<Party> renameParty({required int id, required String name});
  Future<void> deactivateParty(int id);

  Future<List<Category>> listCategories({CashDirection? direction, CategoryRole? role, bool includeInactive = false});
  Future<Category> createCategory({required String name, required CashDirection direction});
  Future<Category> renameCategory({required int id, required String name});
  Future<void> deactivateCategory(int id);

  Future<List<ResaleChannel>> listResaleChannels({bool includeInactive = false});
  Future<ResaleChannel> createResaleChannel({required String name});
  Future<ResaleChannel> renameResaleChannel({required int id, required String name});
  Future<void> deactivateResaleChannel(int id);
}
```

```dart
// lib/features/ledger/domain/ledger_models.dart
enum EntrySource { manual, ai }
enum BusinessOrigin { ordinary, purchasePayment, supplierRefund, resaleIncome, resaleFee, courierTopUp, courierRefund, openingDebtPayment }
enum LinkedBillType { purchasePayment, supplierRefund, openingDebtPayment, problemResaleIncome, problemResaleFee, courierTopUp, courierRefund }
enum PurchaseAdjustmentKind { unpaidWaiver, paidRefund }
enum CourierEventType { opening, topUp, consume, refund }

final class CashBillDraft {
  const CashBillDraft({required this.businessDate, required this.direction, required this.amount, required this.scope, required this.categoryId, required this.accountId, this.partyId, this.note = ''});
  final LocalDate businessDate;
  final CashDirection direction;
  final Money amount;
  final BusinessScope scope;
  final int categoryId;
  final int accountId;
  final int? partyId;
  final String note;
}

final class CashBill {
  const CashBill({required this.id, required this.businessDate, required this.direction, required this.amount, required this.scope, required this.categoryId, required this.accountId, required this.partyId, required this.note, required this.entrySource, required this.businessOrigin, required this.linkedType, required this.linkedId, required this.isVoid, required this.createdAtUtc, required this.updatedAtUtc});
  final int id;
  final LocalDate businessDate;
  final CashDirection direction;
  final Money amount;
  final BusinessScope scope;
  final int categoryId;
  final int accountId;
  final int? partyId;
  final String note;
  final EntrySource entrySource;
  final BusinessOrigin businessOrigin;
  final LinkedBillType? linkedType;
  final int? linkedId;
  final bool isVoid;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
}

final class CashBillFilter {
  const CashBillFilter({this.startDate, this.endDate, this.scope, this.categoryId, this.partyId, this.noteQuery, this.includeVoid = false});
  final LocalDate? startDate;
  final LocalDate? endDate;
  final BusinessScope? scope;
  final int? categoryId;
  final int? partyId;
  final String? noteQuery;
  final bool includeVoid;
}

final class PurchaseItemDraft {
  const PurchaseItemDraft({required this.description, required this.quantity, required this.unitPrice});
  final String description;
  final int quantity;
  final Money unitPrice;
}

final class PurchaseDraft {
  const PurchaseDraft({required this.supplierId, required this.scope, required this.businessDate, required this.items, required this.supplierFreight, this.note = ''});
  final int supplierId;
  final BusinessScope scope;
  final LocalDate businessDate;
  final List<PurchaseItemDraft> items;
  final Money supplierFreight;
  final String note;
}

final class PurchasePaymentDraft {
  const PurchasePaymentDraft({required this.businessDate, required this.amount, required this.accountId, required this.categoryId, this.note = ''});
  final LocalDate businessDate;
  final Money amount;
  final int accountId;
  final int categoryId;
  final String note;
}

final class PurchaseAdjustmentDraft {
  const PurchaseAdjustmentDraft({required this.purchaseId, required this.kind, required this.amount, required this.reason, required this.categoryId, this.businessDate, this.accountId});
  final int purchaseId;
  final PurchaseAdjustmentKind kind;
  final Money amount;
  final String reason;
  final int categoryId;
  final LocalDate? businessDate;
  final int? accountId;
}

final class SupplierOpeningDebtDraft {
  const SupplierOpeningDebtDraft({required this.supplierId, required this.scope, required this.businessDate, required this.amount, this.note = ''});
  final int supplierId;
  final BusinessScope scope;
  final LocalDate businessDate;
  final Money amount;
  final String note;
}

final class ProblemResaleFeeDraft {
  const ProblemResaleFeeDraft({required this.categoryId, required this.accountId, required this.amount, this.partyId, this.note = ''});
  final int categoryId;
  final int accountId;
  final Money amount;
  final int? partyId;
  final String note;
}

final class ProblemResaleDraft {
  const ProblemResaleDraft({required this.scope, required this.businessDate, required this.description, required this.quantity, required this.incomeAmount, required this.incomeAccountId, required this.incomeCategoryId, required this.buyerId, required this.channelId, required this.issueNote, required this.fees});
  final BusinessScope scope;
  final LocalDate businessDate;
  final String description;
  final int quantity;
  final Money incomeAmount;
  final int incomeAccountId;
  final int incomeCategoryId;
  final int buyerId;
  final int channelId;
  final String issueNote;
  final List<ProblemResaleFeeDraft> fees;
}

final class CourierAccountDraft {
  const CourierAccountDraft({required this.name, required this.openingBalance, required this.businessDate});
  final String name;
  final Money openingBalance;
  final LocalDate businessDate;
}

final class CourierCashEventDraft {
  const CourierCashEventDraft({required this.courierAccountId, required this.scope, required this.businessDate, required this.amount, required this.accountId, required this.categoryId, this.note = ''});
  final int courierAccountId;
  final BusinessScope scope;
  final LocalDate businessDate;
  final Money amount;
  final int accountId;
  final int categoryId;
  final String note;
}

final class CourierConsumeDraft {
  const CourierConsumeDraft({required this.courierAccountId, required this.scope, required this.businessDate, required this.amount, this.note = ''});
  final int courierAccountId;
  final BusinessScope scope;
  final LocalDate businessDate;
  final Money amount;
  final String note;
}
```

```dart
// lib/features/ledger/domain/ledger_models.dart continued: read models
final class PurchaseItem { const PurchaseItem({required this.id, required this.description, required this.quantity, required this.unitPrice, required this.lineTotal}); final int id; final String description; final int quantity; final Money unitPrice; final Money lineTotal; }
final class PurchasePayment { const PurchasePayment({required this.id, required this.purchaseId, required this.cashBillId, required this.amount, required this.isVoid}); final int id; final int purchaseId; final int cashBillId; final Money amount; final bool isVoid; }
final class PurchaseAdjustment { const PurchaseAdjustment({required this.id, required this.purchaseId, required this.kind, required this.amount, required this.cashBillId, required this.reason, required this.isVoid}); final int id; final int purchaseId; final PurchaseAdjustmentKind kind; final Money amount; final int? cashBillId; final String reason; final bool isVoid; }
final class PurchasePosition { const PurchasePosition({required this.effectiveTotal, required this.paidNet, required this.payable}); final Money effectiveTotal; final Money paidNet; final Money payable; }
final class Purchase { const Purchase({required this.id, required this.supplierId, required this.scope, required this.businessDate, required this.originalTotal, required this.supplierFreight, required this.note, required this.isVoid, required this.position}); final int id; final int supplierId; final BusinessScope scope; final LocalDate businessDate; final Money originalTotal; final Money supplierFreight; final String note; final bool isVoid; final PurchasePosition position; }
final class PurchaseDetail { const PurchaseDetail({required this.purchase, required this.items, required this.payments, required this.adjustments}); final Purchase purchase; final List<PurchaseItem> items; final List<PurchasePayment> payments; final List<PurchaseAdjustment> adjustments; }
final class PurchaseFilter { const PurchaseFilter({this.scope, this.supplierId, this.includeVoid = false}); final BusinessScope? scope; final int? supplierId; final bool includeVoid; }

final class SupplierOpeningDebt { const SupplierOpeningDebt({required this.id, required this.supplierId, required this.scope, required this.businessDate, required this.amount, required this.paid, required this.isVoid, required this.note}); final int id; final int supplierId; final BusinessScope scope; final LocalDate businessDate; final Money amount; final Money paid; final bool isVoid; final String note; }
final class SupplierOpeningDebtPayment { const SupplierOpeningDebtPayment({required this.id, required this.openingDebtId, required this.cashBillId, required this.amount, required this.isVoid}); final int id; final int openingDebtId; final int cashBillId; final Money amount; final bool isVoid; }
final class SupplierOpeningDebtDetail { const SupplierOpeningDebtDetail({required this.debt, required this.payments}); final SupplierOpeningDebt debt; final List<SupplierOpeningDebtPayment> payments; }

final class ProblemResaleFee { const ProblemResaleFee({required this.id, required this.cashBillId, required this.categoryId, required this.accountId, required this.amount}); final int id; final int cashBillId; final int categoryId; final int accountId; final Money amount; }
final class ProblemResale { const ProblemResale({required this.id, required this.scope, required this.businessDate, required this.description, required this.quantity, required this.incomeAmount, required this.incomeCashBillId, required this.buyerId, required this.channelId, required this.issueNote, required this.isVoid}); final int id; final BusinessScope scope; final LocalDate businessDate; final String description; final int quantity; final Money incomeAmount; final int incomeCashBillId; final int buyerId; final int channelId; final String issueNote; final bool isVoid; }
final class ProblemResaleDetail { const ProblemResaleDetail({required this.resale, required this.fees, required this.netRecovery}); final ProblemResale resale; final List<ProblemResaleFee> fees; final Money netRecovery; }
final class ProblemResaleFilter { const ProblemResaleFilter({this.scope, this.channelId, this.includeVoid = false}); final BusinessScope? scope; final int? channelId; final bool includeVoid; }

final class CourierAccount { const CourierAccount({required this.id, required this.name, required this.isActive, required this.recordedBalance}); final int id; final String name; final bool isActive; final Money recordedBalance; }
final class CourierEvent { const CourierEvent({required this.id, required this.courierAccountId, required this.scope, required this.businessDate, required this.eventType, required this.amount, required this.cashBillId, required this.balanceAfter, required this.note, required this.isVoid}); final int id; final int courierAccountId; final BusinessScope? scope; final LocalDate businessDate; final CourierEventType eventType; final Money amount; final int? cashBillId; final Money balanceAfter; final String note; final bool isVoid; }
final class CourierAccountDetail { const CourierAccountDetail({required this.account, required this.events}); final CourierAccount account; final List<CourierEvent> events; }
```

```dart
// lib/features/ledger/domain/cash_bill_repository.dart
abstract interface class CashBillRepository {
  Future<CashBill> createCashBill(CashBillDraft draft);
  Future<CashBill> updateCashBill({required int id, required CashBillDraft draft});
  Future<void> voidCashBill(int id, {required String reason});
  Future<void> restoreCashBill(int id, {required String reason});
  Future<List<CashBill>> listCashBills(CashBillFilter filter);
}
```

```dart
// lib/features/ledger/domain/ledger_repository.dart
abstract interface class LedgerRepository {
  Future<int> createPurchase(PurchaseDraft draft, {PurchasePaymentDraft? initialPayment});
  Future<void> recordPurchasePayment({required int purchaseId, required PurchasePaymentDraft payment});
  Future<void> voidPurchasePayment({required int paymentId, required String reason});
  Future<void> restorePurchasePayment({required int paymentId, required String reason});
  Future<void> voidPurchaseWithoutActivePayments({required int purchaseId, required String reason});
  Future<void> restorePurchase({required int purchaseId, required String reason});
  Future<void> adjustPurchase(PurchaseAdjustmentDraft draft);
  Future<void> voidPurchaseAdjustment({required int adjustmentId, required String reason});
  Future<void> restorePurchaseAdjustment({required int adjustmentId, required String reason});
  Future<List<Purchase>> listPurchases(PurchaseFilter filter);
  Future<PurchaseDetail> getPurchaseDetail(int purchaseId);

  Future<int> createSupplierOpeningDebt(SupplierOpeningDebtDraft draft);
  Future<void> paySupplierOpeningDebt({required int openingDebtId, required PurchasePaymentDraft payment});
  Future<void> voidSupplierOpeningDebtPayment({required int paymentId, required String reason});
  Future<void> restoreSupplierOpeningDebtPayment({required int paymentId, required String reason});
  Future<List<SupplierOpeningDebt>> listSupplierOpeningDebts({BusinessScope? scope, int? supplierId, bool includeVoid = false});
  Future<SupplierOpeningDebtDetail> getSupplierOpeningDebtDetail(int openingDebtId);

  Future<int> createProblemResale(ProblemResaleDraft draft);
  Future<void> voidProblemResale({required int resaleId, required String reason});
  Future<void> restoreProblemResale({required int resaleId, required String reason});
  Future<List<ProblemResale>> listProblemResales(ProblemResaleFilter filter);
  Future<ProblemResaleDetail> getProblemResaleDetail(int resaleId);

  Future<int> createCourierAccount(CourierAccountDraft draft);
  Future<void> recordCourierTopUp(CourierCashEventDraft draft);
  Future<void> recordCourierConsume(CourierConsumeDraft draft);
  Future<void> recordCourierRefund(CourierCashEventDraft draft);
  Future<void> voidCourierEvent({required int eventId, required String reason});
  Future<void> restoreCourierEvent({required int eventId, required String reason});
  Future<List<CourierAccount>> listCourierAccounts({bool includeInactive = false});
  Future<CourierAccountDetail> getCourierAccountDetail(int courierAccountId);
}
```

```dart
// lib/features/ledger/domain/ledger_calculations.dart
abstract final class LedgerCalculations {
  static PurchasePosition purchasePosition({required Money originalTotal, required Iterable<Money> unpaidWaivers, required Iterable<Money> paidRefunds, required Iterable<Money> activePayments});
  static List<CourierEvent> recalculateCourierTimeline(Iterable<CourierEvent> events);
  static void assertCappedAggregate(Iterable<int> activeCentsValues);
}
```

```dart
// lib/features/dashboard/domain/dashboard_snapshots.dart
final class DashboardSnapshot {
  const DashboardSnapshot({required this.monthCashExpense, required this.supplierPayable, required this.monthResaleIncome, required this.recentBills});
  final Money monthCashExpense;
  final Money supplierPayable;
  final Money monthResaleIncome;
  final List<CashBill> recentBills;
}

final class LedgerDetailSnapshot {
  const LedgerDetailSnapshot({required this.cashIncome, required this.cashExpense, required this.cashNet, required this.purchaseEffective, required this.purchasePaidNet, required this.purchasePayable, required this.resaleIncome, required this.resaleFees, required this.resaleNetRecovery, required this.courierTopUp, required this.courierConsume, required this.globalCourierRecordedBalance});
  final Money cashIncome;
  final Money cashExpense;
  final Money cashNet;
  final Money purchaseEffective;
  final Money purchasePaidNet;
  final Money purchasePayable;
  final Money resaleIncome;
  final Money resaleFees;
  final Money resaleNetRecovery;
  final Money courierTopUp;
  final Money courierConsume;
  final Money? globalCourierRecordedBalance; // null for selected-shop detail when a global wallet balance would be misleading.
}
```

```dart
// lib/features/dashboard/domain/dashboard_repository.dart
abstract interface class DashboardRepository {
  Future<DashboardSnapshot> loadDashboardSnapshot({required LocalDate monthStart, required LocalDate monthEnd, BusinessScope? scope});
  Future<LedgerDetailSnapshot> loadLedgerDetailSnapshot({required LocalDate startDate, required LocalDate endDate, BusinessScope? scope});
}
```

## Privacy, database and test fixture contracts

```dart
// lib/core/data/ledger_privacy.dart
final class PreparedLedgerDirectory {
  const PreparedLedgerDirectory({required this.path, required this.backupExcludedVerified});
  final String path;
  final bool backupExcludedVerified;
}

abstract interface class LedgerPrivacy {
  Future<PreparedLedgerDirectory> prepareLedgerDirectory();
}

final class LedgerPrivacyException implements Exception {
  const LedgerPrivacyException(this.message);
  final String message;
  @override
  String toString() => message;
}
```

```dart
// lib/core/data/ledger_database.dart
final class LedgerDatabase {
  Future<void> open({required LedgerPrivacy privacy, DatabaseFactory? databaseFactoryOverride, String? preparedDirectoryOverride});
  Database get database;
  Future<void> close();
}
```

`LedgerDatabase.open` must call `privacy.prepareLedgerDirectory()` before `openDatabase`. It must canonicalize the returned directory and optional test directory with `Directory(path).absolute.resolveSymbolicLinks()`. Production opens `path.join(prepared.path, 'personal_finances_ledger.db')` and never calls an independent `getDatabasesPath()` fallback. If `backupExcludedVerified` is false, directory canonicalization fails, or `preparedDirectoryOverride` is supplied and differs from the prepared canonical path, throw `LedgerPrivacyException('无法确认账本已排除系统自动备份')` before creating/opening a DB file. Host tests inject both a `databaseFactoryOverride` and an explicitly prepared temp directory; production uses the default factory.

```dart
// test/support/sqlite_ledger_test_harness.dart
final class SqliteLedgerTestHarness {
  static Future<SqliteLedgerTestHarness> open();
  CatalogRepository get catalog;
  CashBillRepository get cashBills;
  LedgerRepository get ledger;
  DashboardRepository get dashboard;
  int get unusedExpenseCategoryId;
  int get resaleIncomeCategoryId;
  Future<AccountLabel> createAccount(String name);
  Future<Category> createCategory({required String name, required CashDirection direction});
  Future<Party> createParty({required String name, required PartyKind kind});
  Future<Shop> createShop(String name);
  PurchasePaymentDraft purchasePayment({required String amount});
  CourierCashEventDraft courierTopUp({required int courierAccountId, required BusinessScope scope, required String amount});
  Future<int> seedPurchase({required String total, String paid = '0'});
  Future<int> seedPaidRefund({required int purchaseId, required String amount});
  Future<CashBill> linkedCashBillForAdjustment(int adjustmentId);
  Future<void> seedOrdinaryIncomeUsingResaleCategory({required String amount});
  Future<int> seedProblemResale({required String amount, String fee = '0'});
  Future<int> seedCourierTopUpThenConsumeAll();
  Future<void> seedManualExpenseCents(int cents);
  Future<int> cashBillCount();
  Future<int> auditLogCount();
  Future<void> closeAndReopen();
  Future<void> close();
}
```

The harness owns `sqfliteFfiInit()`, sets no production global locator, passes `databaseFactoryFfi` into `LedgerDatabase.open`, creates a unique temp directory, returns unique account/category names, and calls `ensureDefaultCatalogs()` once. Tests must not create a second default `微信` after defaults seed it; use unique names such as `测试账户A`.

```dart
// test/support/widget_test_app.dart
final class FakeAppRepositories {
  FakeAppRepositories({required this.catalog, required this.cashBills, required this.ledger, required this.dashboard});
  factory FakeAppRepositories.withLedgerError(Object error);
  final CatalogRepository catalog;
  final CashBillRepository cashBills;
  final LedgerRepository ledger;
  final DashboardRepository dashboard;
}

final validDraft = CashBillDraft(
  businessDate: LocalDate.parse('2026-10-14'),
  direction: CashDirection.expense,
  amount: Money.fromCents(100),
  scope: const BusinessScope.public(),
  categoryId: 1,
  accountId: 1,
);

final class RecordingCatalogRepository implements CatalogRepository {
  RecordingCatalogRepository({List<Category> categories = const [], List<AccountLabel> accounts = const []});
  int get listCategoriesCalls;
}
final class RecordingCashBillRepository implements CashBillRepository {
  RecordingCashBillRepository({this.refreshThrows = false, this.commitThrows = false});
  final bool refreshThrows;
  final bool commitThrows;
  int get createCashBillCalls;
}

Future<void> pumpLedgerAppWithRepositories(WidgetTester tester, FakeAppRepositories repositories);
```

Fake repositories implement the small domain repository contracts, record calls, and never access SQLite. Widget tests import this helper instead of defining hidden `pumpLedgerAppWithFakes` or `testDependencies` functions.

## SQLite schema contract

Task 2 writes this schema through `LedgerSchema.createV1(Database db)`. Use `INTEGER` booleans 0/1. Use UTC ISO-8601 strings ending in `Z` for audit timestamps. All foreign keys are enforced with `PRAGMA foreign_keys = ON` in `onConfigure`. The `cash_bills.entry_source` records input provenance; `cash_bills.business_origin` and `linked_type/linked_id` are assigned only by business operations. For linked rows, `cash_bills.linked_id` is the owning aggregate ID (`purchase_id`, `opening_debt_id`, `problem_resale_id` or `courier_account_id`); child tables keep exact child-to-cash IDs for payment/event status updates.

```sql
CREATE TABLE shops (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL UNIQUE, is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)), created_at_utc TEXT NOT NULL, updated_at_utc TEXT NOT NULL);
CREATE TABLE account_labels (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL UNIQUE, is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)), created_at_utc TEXT NOT NULL, updated_at_utc TEXT NOT NULL);
CREATE TABLE parties (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, kind TEXT NOT NULL CHECK (kind IN ('supplier', 'buyer', 'courier', 'other')), is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)), created_at_utc TEXT NOT NULL, updated_at_utc TEXT NOT NULL, UNIQUE (name, kind));
CREATE TABLE categories (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, direction TEXT NOT NULL CHECK (direction IN ('income', 'expense')), role TEXT NOT NULL CHECK (role IN ('ordinary', 'purchasePayment', 'supplierRefund', 'resaleIncome', 'resaleFee', 'courierTopUp', 'courierRefund', 'openingDebtPayment')), is_system INTEGER NOT NULL DEFAULT 0 CHECK (is_system IN (0, 1)), is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)), created_at_utc TEXT NOT NULL, updated_at_utc TEXT NOT NULL, UNIQUE (name, direction));
CREATE TABLE resale_channels (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL UNIQUE, is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)), created_at_utc TEXT NOT NULL, updated_at_utc TEXT NOT NULL);

CREATE TABLE cash_bills (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  business_date TEXT NOT NULL,
  direction TEXT NOT NULL CHECK (direction IN ('income', 'expense')),
  amount_cents INTEGER NOT NULL CHECK (amount_cents > 0 AND amount_cents <= 9000000000000000),
  scope_type TEXT NOT NULL CHECK (scope_type IN ('public', 'shop')),
  shop_id INTEGER REFERENCES shops(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
  category_id INTEGER NOT NULL REFERENCES categories(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
  account_id INTEGER NOT NULL REFERENCES account_labels(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
  party_id INTEGER REFERENCES parties(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
  note TEXT NOT NULL DEFAULT '',
  entry_source TEXT NOT NULL CHECK (entry_source IN ('manual', 'ai')),
  business_origin TEXT NOT NULL CHECK (business_origin IN ('ordinary', 'purchasePayment', 'supplierRefund', 'resaleIncome', 'resaleFee', 'courierTopUp', 'courierRefund', 'openingDebtPayment')),
  linked_type TEXT CHECK (linked_type IN ('purchasePayment', 'supplierRefund', 'openingDebtPayment', 'problemResaleIncome', 'problemResaleFee', 'courierTopUp', 'courierRefund')),
  linked_id INTEGER,
  is_void INTEGER NOT NULL DEFAULT 0 CHECK (is_void IN (0, 1)),
  created_at_utc TEXT NOT NULL,
  updated_at_utc TEXT NOT NULL,
  voided_at_utc TEXT,
  CHECK ((scope_type = 'public' AND shop_id IS NULL) OR (scope_type = 'shop' AND shop_id IS NOT NULL)),
  CHECK ((business_origin = 'ordinary' AND linked_type IS NULL AND linked_id IS NULL) OR (business_origin <> 'ordinary' AND linked_type IS NOT NULL AND linked_id IS NOT NULL))
);
CREATE INDEX cash_bills_filter_idx ON cash_bills(business_date, scope_type, shop_id, category_id, party_id, is_void);
CREATE INDEX cash_bills_link_idx ON cash_bills(linked_type, linked_id);

CREATE TABLE purchases (id INTEGER PRIMARY KEY AUTOINCREMENT, supplier_id INTEGER NOT NULL REFERENCES parties(id) ON UPDATE RESTRICT ON DELETE RESTRICT, business_date TEXT NOT NULL, scope_type TEXT NOT NULL CHECK (scope_type IN ('public', 'shop')), shop_id INTEGER REFERENCES shops(id) ON UPDATE RESTRICT ON DELETE RESTRICT, item_total_cents INTEGER NOT NULL CHECK (item_total_cents >= 0 AND item_total_cents <= 9000000000000000), supplier_freight_cents INTEGER NOT NULL CHECK (supplier_freight_cents >= 0 AND supplier_freight_cents <= 9000000000000000), original_total_cents INTEGER NOT NULL CHECK (original_total_cents > 0 AND original_total_cents <= 9000000000000000), effective_total_cents INTEGER NOT NULL CHECK (effective_total_cents >= 0 AND effective_total_cents <= 9000000000000000), note TEXT NOT NULL DEFAULT '', is_void INTEGER NOT NULL DEFAULT 0 CHECK (is_void IN (0, 1)), created_at_utc TEXT NOT NULL, updated_at_utc TEXT NOT NULL, voided_at_utc TEXT, CHECK ((scope_type = 'public' AND shop_id IS NULL) OR (scope_type = 'shop' AND shop_id IS NOT NULL)));
CREATE TABLE purchase_items (id INTEGER PRIMARY KEY AUTOINCREMENT, purchase_id INTEGER NOT NULL REFERENCES purchases(id) ON UPDATE RESTRICT ON DELETE RESTRICT, description TEXT NOT NULL, quantity INTEGER NOT NULL CHECK (quantity > 0), unit_price_cents INTEGER NOT NULL CHECK (unit_price_cents > 0 AND unit_price_cents <= 9000000000000000), line_total_cents INTEGER NOT NULL CHECK (line_total_cents > 0 AND line_total_cents <= 9000000000000000));
CREATE TABLE purchase_payments (id INTEGER PRIMARY KEY AUTOINCREMENT, purchase_id INTEGER NOT NULL REFERENCES purchases(id) ON UPDATE RESTRICT ON DELETE RESTRICT, cash_bill_id INTEGER NOT NULL UNIQUE REFERENCES cash_bills(id) ON UPDATE RESTRICT ON DELETE RESTRICT, amount_cents INTEGER NOT NULL CHECK (amount_cents > 0 AND amount_cents <= 9000000000000000), is_void INTEGER NOT NULL DEFAULT 0 CHECK (is_void IN (0, 1)), voided_at_utc TEXT, created_at_utc TEXT NOT NULL, updated_at_utc TEXT NOT NULL);
CREATE TABLE purchase_adjustments (id INTEGER PRIMARY KEY AUTOINCREMENT, purchase_id INTEGER NOT NULL REFERENCES purchases(id) ON UPDATE RESTRICT ON DELETE RESTRICT, kind TEXT NOT NULL CHECK (kind IN ('unpaidWaiver', 'paidRefund')), amount_cents INTEGER NOT NULL CHECK (amount_cents > 0 AND amount_cents <= 9000000000000000), cash_bill_id INTEGER UNIQUE REFERENCES cash_bills(id) ON UPDATE RESTRICT ON DELETE RESTRICT, reason TEXT NOT NULL, is_void INTEGER NOT NULL DEFAULT 0 CHECK (is_void IN (0, 1)), voided_at_utc TEXT, created_at_utc TEXT NOT NULL, updated_at_utc TEXT NOT NULL, CHECK ((kind = 'paidRefund' AND cash_bill_id IS NOT NULL) OR (kind = 'unpaidWaiver' AND cash_bill_id IS NULL)));
CREATE TABLE supplier_opening_debts (id INTEGER PRIMARY KEY AUTOINCREMENT, supplier_id INTEGER NOT NULL REFERENCES parties(id) ON UPDATE RESTRICT ON DELETE RESTRICT, business_date TEXT NOT NULL, scope_type TEXT NOT NULL CHECK (scope_type IN ('public', 'shop')), shop_id INTEGER REFERENCES shops(id) ON UPDATE RESTRICT ON DELETE RESTRICT, amount_cents INTEGER NOT NULL CHECK (amount_cents > 0 AND amount_cents <= 9000000000000000), paid_cents INTEGER NOT NULL DEFAULT 0 CHECK (paid_cents >= 0 AND paid_cents <= 9000000000000000), note TEXT NOT NULL DEFAULT '', is_void INTEGER NOT NULL DEFAULT 0 CHECK (is_void IN (0, 1)), created_at_utc TEXT NOT NULL, updated_at_utc TEXT NOT NULL, CHECK (paid_cents <= amount_cents), CHECK ((scope_type = 'public' AND shop_id IS NULL) OR (scope_type = 'shop' AND shop_id IS NOT NULL)));
CREATE TABLE supplier_opening_debt_payments (id INTEGER PRIMARY KEY AUTOINCREMENT, opening_debt_id INTEGER NOT NULL REFERENCES supplier_opening_debts(id) ON UPDATE RESTRICT ON DELETE RESTRICT, cash_bill_id INTEGER NOT NULL UNIQUE REFERENCES cash_bills(id) ON UPDATE RESTRICT ON DELETE RESTRICT, amount_cents INTEGER NOT NULL CHECK (amount_cents > 0 AND amount_cents <= 9000000000000000), is_void INTEGER NOT NULL DEFAULT 0 CHECK (is_void IN (0, 1)), voided_at_utc TEXT, created_at_utc TEXT NOT NULL, updated_at_utc TEXT NOT NULL);

CREATE TABLE problem_resales (id INTEGER PRIMARY KEY AUTOINCREMENT, business_date TEXT NOT NULL, scope_type TEXT NOT NULL CHECK (scope_type IN ('public', 'shop')), shop_id INTEGER REFERENCES shops(id) ON UPDATE RESTRICT ON DELETE RESTRICT, description TEXT NOT NULL, quantity INTEGER NOT NULL CHECK (quantity > 0), income_cents INTEGER NOT NULL CHECK (income_cents > 0 AND income_cents <= 9000000000000000), income_cash_bill_id INTEGER UNIQUE REFERENCES cash_bills(id) ON UPDATE RESTRICT ON DELETE RESTRICT, buyer_id INTEGER NOT NULL REFERENCES parties(id) ON UPDATE RESTRICT ON DELETE RESTRICT, channel_id INTEGER NOT NULL REFERENCES resale_channels(id) ON UPDATE RESTRICT ON DELETE RESTRICT, issue_note TEXT NOT NULL, is_void INTEGER NOT NULL DEFAULT 0 CHECK (is_void IN (0, 1)), voided_at_utc TEXT, created_at_utc TEXT NOT NULL, updated_at_utc TEXT NOT NULL, CHECK ((scope_type = 'public' AND shop_id IS NULL) OR (scope_type = 'shop' AND shop_id IS NOT NULL)));
CREATE TABLE problem_resale_fees (id INTEGER PRIMARY KEY AUTOINCREMENT, resale_id INTEGER NOT NULL REFERENCES problem_resales(id) ON UPDATE RESTRICT ON DELETE RESTRICT, cash_bill_id INTEGER NOT NULL UNIQUE REFERENCES cash_bills(id) ON UPDATE RESTRICT ON DELETE RESTRICT, category_id INTEGER NOT NULL REFERENCES categories(id) ON UPDATE RESTRICT ON DELETE RESTRICT, account_id INTEGER NOT NULL REFERENCES account_labels(id) ON UPDATE RESTRICT ON DELETE RESTRICT, amount_cents INTEGER NOT NULL CHECK (amount_cents > 0 AND amount_cents <= 9000000000000000), created_at_utc TEXT NOT NULL);

CREATE TABLE courier_accounts (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL UNIQUE, is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)), created_at_utc TEXT NOT NULL, updated_at_utc TEXT NOT NULL);
CREATE TABLE courier_events (id INTEGER PRIMARY KEY AUTOINCREMENT, courier_account_id INTEGER NOT NULL REFERENCES courier_accounts(id) ON UPDATE RESTRICT ON DELETE RESTRICT, business_date TEXT NOT NULL, event_type TEXT NOT NULL CHECK (event_type IN ('opening', 'topUp', 'consume', 'refund')), amount_cents INTEGER NOT NULL CHECK (amount_cents >= 0 AND amount_cents <= 9000000000000000), scope_type TEXT CHECK (scope_type IN ('public', 'shop')), shop_id INTEGER REFERENCES shops(id) ON UPDATE RESTRICT ON DELETE RESTRICT, cash_bill_id INTEGER UNIQUE REFERENCES cash_bills(id) ON UPDATE RESTRICT ON DELETE RESTRICT, balance_after_cents INTEGER NOT NULL CHECK (balance_after_cents >= 0 AND balance_after_cents <= 9000000000000000), note TEXT NOT NULL DEFAULT '', is_void INTEGER NOT NULL DEFAULT 0 CHECK (is_void IN (0, 1)), voided_at_utc TEXT, created_at_utc TEXT NOT NULL, updated_at_utc TEXT NOT NULL, CHECK ((event_type = 'opening' AND scope_type IS NULL AND shop_id IS NULL AND cash_bill_id IS NULL) OR (event_type = 'consume' AND scope_type IS NOT NULL AND cash_bill_id IS NULL) OR (event_type IN ('topUp', 'refund') AND scope_type IS NOT NULL)), CHECK ((scope_type = 'public' AND shop_id IS NULL) OR (scope_type = 'shop' AND shop_id IS NOT NULL) OR (scope_type IS NULL AND shop_id IS NULL)));

CREATE TABLE audit_logs (id INTEGER PRIMARY KEY AUTOINCREMENT, entity_type TEXT NOT NULL, entity_id INTEGER NOT NULL, action TEXT NOT NULL, reason TEXT NOT NULL DEFAULT '', snapshot_json TEXT NOT NULL, created_at_utc TEXT NOT NULL);
PRAGMA user_version = 1;
```

## Task 1: Pure domain contracts and calculations

**Files:**
- Create: `lib/core/domain/local_date.dart`
- Modify: `lib/core/domain/money.dart`
- Create: `lib/features/catalog/domain/catalog_models.dart`
- Create: `lib/features/catalog/domain/catalog_repository.dart`
- Create: `lib/features/ledger/domain/ledger_models.dart`
- Create: `lib/features/ledger/domain/cash_bill_repository.dart`
- Create: `lib/features/ledger/domain/ledger_repository.dart`
- Create: `lib/features/ledger/domain/ledger_calculations.dart`
- Create: `lib/features/dashboard/domain/dashboard_snapshots.dart`
- Create: `lib/features/dashboard/domain/dashboard_repository.dart`
- Test: `test/core/domain/local_date_test.dart`
- Test: `test/core/domain/money_product_test.dart`
- Test: `test/features/ledger/domain/ledger_domain_test.dart`
- Test: `test/features/ledger/domain/ledger_calculations_test.dart`

**Interfaces:**
- Consumes: existing `Money.fromCents(int)`, `Money.parsePositive(String)`, `Money.zero`, `Money.add(Money)`, `Money.format()`.
- Produces: every type and method in Shared domain contract.

- [ ] **Step 1: Write strict date tests.**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finances_pro/core/domain/local_date.dart';

void main() {
  test('accepts real yyyy-mm-dd calendar dates only', () {
    expect(LocalDate.parse('2026-02-28').value, '2026-02-28');
    expect(LocalDate.parse('2024-02-29').value, '2024-02-29');
  });

  test('rejects rollover and non-padded dates', () {
    for (final input in ['2026-2-3', '2026-02-29', '2026-04-31', '2026-13-01', '20260203']) {
      expect(() => LocalDate.parse(input), throwsFormatException);
    }
  });
}
```

Run: `"$FLUTTER_SDK/bin/flutter" test test/core/domain/local_date_test.dart`
Expected: FAIL because `LocalDate` does not exist.

- [ ] **Step 2: Write checked product and aggregate tests.**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finances_pro/core/domain/money.dart';

void main() {
  test('checks quantity times unit price before converting to int cents', () {
    expect(Money.checkedProduct(quantity: 3, unitPrice: Money.fromCents(199)).cents, 597);
    expect(() => Money.checkedProduct(quantity: 1000000000, unitPrice: Money.fromCents(9000000000000000)), throwsFormatException);
  });

  test('sums money in Dart without SQL integer overflow', () {
    expect(Money.sumCents([1, 2, -3]).cents, 0);
    expect(() => Money.sumCents([9000000000000000, 1]), throwsFormatException);
  });
}
```

Run: `"$FLUTTER_SDK/bin/flutter" test test/core/domain/money_product_test.dart`
Expected: FAIL because `checkedProduct` and `sumCents` do not exist.

- [ ] **Step 3: Add minimal `LocalDate` and Money additions.** Implement the code from the Shared domain contract. `LocalDate.parse` must reject non-padded dates and invalid month/day combinations without DateTime rollover. `Money.checkedProduct` and `Money.sumCents` must use `BigInt` before converting to `int`.

- [ ] **Step 4: Add model and repository contract files exactly as shown in Shared domain contract.** Keep constructors immutable and do not import Flutter, sqflite, provider, HTTP or native plugins in any `domain` folder.

- [ ] **Step 5: Write calculation tests.**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finances_pro/core/domain/money.dart';
import 'package:personal_finances_pro/features/ledger/domain/ledger_calculations.dart';

void main() {
  test('purchase position preserves paid net invariant', () {
    final position = LedgerCalculations.purchasePosition(
      originalTotal: Money.fromCents(2300),
      unpaidWaivers: [Money.fromCents(500)],
      paidRefunds: [Money.fromCents(700)],
      activePayments: [Money.fromCents(1000)],
    );
    expect(position.effectiveTotal.cents, 1100);
    expect(position.paidNet.cents, 300);
    expect(() => LedgerCalculations.purchasePosition(originalTotal: Money.fromCents(2300), unpaidWaivers: [Money.fromCents(500)], paidRefunds: [Money.fromCents(700)], activePayments: [Money.fromCents(2000)]), throwsStateError);
  });

  test('aggregate cap rejects before a write can create unreadable totals', () {
    expect(() => LedgerCalculations.assertCappedAggregate([9000000000000000, 1]), throwsFormatException);
  });
}
```

Run: `"$FLUTTER_SDK/bin/flutter" test test/features/ledger/domain/ledger_calculations_test.dart`
Expected: FAIL before implementation, then PASS after the invariant function rejects `paidNet > effectiveTotal`.

- [ ] **Step 6: Run domain checks.**

```sh
"$FLUTTER_SDK/bin/dart" format --output=none --set-exit-if-changed lib test tool
"$FLUTTER_SDK/bin/dart" run tool/check_domain_boundaries.dart
"$FLUTTER_SDK/bin/flutter" test test/core/domain test/features/ledger/domain
```

Expected: PASS.

- [ ] **Step 7: Commit Task 1.**

```bash
git add lib/core/domain lib/features/catalog/domain lib/features/ledger/domain lib/features/dashboard/domain test/core/domain test/features/ledger/domain
git commit -m "feat: define local ledger domain contract"
```

## Task 2: SQLite schema, privacy gate, catalog store and ordinary cash store

**Files:**
- Modify: `pubspec.yaml`, `pubspec.lock`
- Create: `lib/core/data/ledger_privacy.dart`
- Create: `lib/core/data/ledger_database.dart`
- Create: `lib/core/data/ledger_schema.dart`
- Create: `lib/core/data/sqlite_aggregate_guard.dart`
- Create: `lib/core/data/sqlite_statement.dart`
- Create: `lib/features/catalog/data/sqlite_catalog_repository.dart`
- Create: `lib/features/ledger/data/sqlite_cash_bill_repository.dart`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Create: `android/app/src/main/res/xml/backup_rules.xml`
- Create: `android/app/src/main/res/xml/data_extraction_rules.xml`
- Modify: `ios/Runner/AppDelegate.swift`
- Create: `test/support/sqlite_ledger_test_harness.dart`
- Test: `test/core/data/ledger_privacy_test.dart`
- Test: `test/core/data/ledger_schema_test.dart`
- Test: `test/core/data/backup_exclusion_static_test.dart`
- Test: `test/features/catalog/data/sqlite_catalog_repository_test.dart`
- Test: `test/features/ledger/data/sqlite_cash_bill_repository_test.dart`

**Interfaces:**
- Consumes: Task 1 domain contracts.
- Produces: `LedgerDatabase`, `PreparedLedgerDirectory`, `SqliteLedgerTestHarness`, `SqliteCatalogRepository implements CatalogRepository`, `SqliteCashBillRepository implements CashBillRepository`. Task 2 does not create `SqliteLedgerRepository` and contains no production `UnsupportedError` stubs.

- [ ] **Step 1: Add pinned libraries.**

```sh
"$FLUTTER_SDK/bin/flutter" pub add sqflite:2.4.2 path:1.9.1
"$FLUTTER_SDK/bin/flutter" pub add --dev sqflite_common_ffi:2.3.5
"$FLUTTER_SDK/bin/flutter" pub get
```

Expected: `pubspec.lock` resolves with Dart SDK `3.7.2`; if pub rejects a version, stop and record the resolver error.

- [ ] **Step 2: Write privacy path gate tests.**

```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finances_pro/core/data/ledger_database.dart';
import 'package:personal_finances_pro/core/data/ledger_privacy.dart';

final class FakePrivacy implements LedgerPrivacy {
  FakePrivacy(this.directory);
  final PreparedLedgerDirectory directory;
  @override
  Future<PreparedLedgerDirectory> prepareLedgerDirectory() async => directory;
}

void main() {
  test('open rejects unverified directory before creating a db file', () async {
    final dir = await Directory.systemTemp.createTemp('ledger-privacy-');
    addTearDown(() => dir.delete(recursive: true));
    final db = LedgerDatabase();
    await expectLater(
      db.open(privacy: FakePrivacy(PreparedLedgerDirectory(path: dir.path, backupExcludedVerified: false)), preparedDirectoryOverride: dir.path),
      throwsA(isA<LedgerPrivacyException>()),
    );
    expect(File('${dir.path}/personal_finances_ledger.db').existsSync(), isFalse);
  });

  test('open rejects mismatched prepared path before creating a db file', () async {
    final prepared = await Directory.systemTemp.createTemp('ledger-prepared-');
    final other = await Directory.systemTemp.createTemp('ledger-other-');
    addTearDown(() async { await prepared.delete(recursive: true); await other.delete(recursive: true); });
    final db = LedgerDatabase();
    await expectLater(
      db.open(privacy: FakePrivacy(PreparedLedgerDirectory(path: prepared.path, backupExcludedVerified: true)), preparedDirectoryOverride: other.path),
      throwsA(isA<LedgerPrivacyException>()),
    );
    expect(File('${other.path}/personal_finances_ledger.db').existsSync(), isFalse);
  });
}
```

Run: `"$FLUTTER_SDK/bin/flutter" test test/core/data/ledger_privacy_test.dart`
Expected: FAIL before data files exist.

- [ ] **Step 3: Implement the privacy contract and database open.** `LedgerDatabase.open` must open only inside the verified prepared directory. iOS `MethodChannelLedgerPrivacy` calls channel `dev.nedhuohuo.personalfinancespro/ledger_privacy`, method `prepareLedgerDirectory`, expects a map `{'path': String, 'backupExcludedVerified': true}` and returns that path. Android production implementation returns the canonical database directory only because Task 2 source checks prove `database` domain exclusion is declared; no app code may open outside the returned directory.

- [ ] **Step 4: Write actual SQL reopen test using the reusable harness.**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finances_pro/core/domain/local_date.dart';
import 'package:personal_finances_pro/core/domain/money.dart';
import 'package:personal_finances_pro/features/catalog/domain/catalog_models.dart';
import 'package:personal_finances_pro/features/ledger/domain/ledger_models.dart';
import '../../support/sqlite_ledger_test_harness.dart';

void main() {
  test('catalog and ordinary cash bill persist after close and reopen', () async {
    final env = await SqliteLedgerTestHarness.open();
    addTearDown(env.close);
    final account = await env.createAccount('测试账户A');
    final category = await env.createCategory(name: '包装采购A', direction: CashDirection.expense);
    await env.cashBills.createCashBill(CashBillDraft(
      businessDate: LocalDate.parse('2026-10-14'),
      direction: CashDirection.expense,
      amount: Money.parsePositive('18.50'),
      scope: const BusinessScope.public(),
      categoryId: category.id,
      accountId: account.id,
      note: '纸箱',
    ));
    await env.closeAndReopen();
    final bills = await env.cashBills.listCashBills(const CashBillFilter());
    expect(bills.single.amount.cents, 1850);
    expect(bills.single.entrySource, EntrySource.manual);
    expect(bills.single.businessOrigin, BusinessOrigin.ordinary);
    expect(bills.single.linkedId, isNull);
  });
}
```

Run: `"$FLUTTER_SDK/bin/flutter" test test/core/data/ledger_schema_test.dart test/features/ledger/data/sqlite_cash_bill_repository_test.dart`
Expected: FAIL before schema/repositories exist.

- [ ] **Step 5: Implement `LedgerSchema.createV1` with the schema contract.** `LedgerDatabase` uses `openDatabase(path, version: 1, onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'), onCreate: (db, version) async => LedgerSchema.createV1(db))` with the injected or default `DatabaseFactory`.

- [ ] **Step 6: Implement catalog defaults with corrected directions.** `ensureDefaultCatalogs()` inserts only these system rows when absent:

```dart
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
```

No shops, suppliers, buyers, couriers or cash bills are inserted by defaults.

- [ ] **Step 7: Implement ordinary cash methods and active-reference validation.** `SqliteCashBillRepository.createCashBill` and `updateCashBill` always write `entry_source='manual'`, `business_origin='ordinary'`, `linked_type=NULL`, `linked_id=NULL`, regardless of selected category name or role. New category/account/party/shop assignments must be active and direction-compatible. Update/restore may keep the row's existing inactive historical references when the user does not change those fields. `voidCashBill` and `restoreCashBill` reject linked rows with `StateError('关联账单只能在所属业务中修改')`.

- [ ] **Step 8: Write operation-derived classification regression.**

```dart
test('ordinary cash with resale-named system category is excluded from resale totals', () async {
  final env = await SqliteLedgerTestHarness.open();
  addTearDown(env.close);
  final account = await env.createAccount('测试账户B');
  final resaleCategory = (await env.catalog.listCategories(direction: CashDirection.income, role: CategoryRole.resaleIncome)).single;
  await env.cashBills.createCashBill(CashBillDraft(
    businessDate: LocalDate.parse('2026-10-14'),
    direction: CashDirection.income,
    amount: Money.parsePositive('30'),
    scope: const BusinessScope.public(),
    categoryId: resaleCategory.id,
    accountId: account.id,
  ));
  final bills = await env.cashBills.listCashBills(const CashBillFilter());
  expect(bills.single.businessOrigin, BusinessOrigin.ordinary);
});
```

This Task 2 test proves the cash row is ordinary. Task 3 proves dashboard resale totals include only real linked resales.

- [ ] **Step 9: Add native backup exclusion source and static tests.** Android manifest application tag must include:

```xml
android:allowBackup="false"
android:fullBackupContent="@xml/backup_rules"
android:dataExtractionRules="@xml/data_extraction_rules"
```

`android/app/src/main/res/xml/backup_rules.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<full-backup-content>
    <exclude domain="database" path="." />
    <exclude domain="file" path="ledger" />
</full-backup-content>
```

`android/app/src/main/res/xml/data_extraction_rules.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<data-extraction-rules>
    <cloud-backup><exclude domain="database" path="." /><exclude domain="file" path="ledger" /></cloud-backup>
    <device-transfer><exclude domain="database" path="." /><exclude domain="file" path="ledger" /></device-transfer>
</data-extraction-rules>
```

`ios/Runner/AppDelegate.swift` registers the channel, creates `Application Support/ledger`, sets `URLResourceKey.isExcludedFromBackupKey`, reads that exact directory's value back, resolves the path, and returns `{'path': path, 'backupExcludedVerified': true}` only when readback is true.

- [ ] **Step 10: Run Task 2 checks.**

```sh
"$FLUTTER_SDK/bin/dart" format --output=none --set-exit-if-changed lib test tool
"$FLUTTER_SDK/bin/dart" run tool/check_domain_boundaries.dart
"$FLUTTER_SDK/bin/flutter" test test/core/data test/features/catalog/data test/features/ledger/data/sqlite_cash_bill_repository_test.dart
```

Expected: PASS.

- [ ] **Step 11: Commit Task 2.**

```bash
git add pubspec.yaml pubspec.lock lib/core/data lib/features/catalog/data lib/features/ledger/data/sqlite_cash_bill_repository.dart android/app/src/main/AndroidManifest.xml android/app/src/main/res/xml ios/Runner/AppDelegate.swift test/support/sqlite_ledger_test_harness.dart test/core/data test/features/catalog/data test/features/ledger/data/sqlite_cash_bill_repository_test.dart
git commit -m "feat: add sqlite cash ledger storage"
```

## Task 3: Full business repository, reads, lifecycle and snapshots

**Files:**
- Create: `lib/features/ledger/data/sqlite_ledger_repository.dart`
- Create: `lib/features/dashboard/data/sqlite_dashboard_repository.dart`
- Extend: `lib/core/data/sqlite_aggregate_guard.dart`
- Test: `test/features/ledger/data/sqlite_business_transaction_test.dart`
- Test: `test/features/dashboard/data/sqlite_dashboard_repository_test.dart`

**Interfaces:**
- Consumes: Task 2 `SqliteCatalogRepository`, `SqliteCashBillRepository`, schema and harness.
- Produces: `SqliteLedgerRepository({required Database database, required SqliteCashBillRepository cashBills}) implements LedgerRepository`; `SqliteDashboardRepository(Database database) implements DashboardRepository`; all read/list/detail and lifecycle methods in `LedgerRepository`.

- [ ] **Step 1: Write purchase and payment atomicity tests.**

```dart
test('purchase creation with initial payment writes one linked cash expense atomically', () async {
  final env = await SqliteLedgerTestHarness.open();
  addTearDown(env.close);
  final supplier = await env.createParty(name: '厂家A', kind: PartyKind.supplier);
  final account = await env.createAccount('测试账户C');
  final paymentCategory = await env.createCategory(name: '厂家付款A', direction: CashDirection.expense);
  final purchaseId = await env.ledger.createPurchase(
    PurchaseDraft(supplierId: supplier.id, scope: const BusinessScope.public(), businessDate: LocalDate.parse('2026-10-14'), items: [PurchaseItemDraft(description: '发夹', quantity: 2, unitPrice: Money.parsePositive('10'))], supplierFreight: Money.parsePositive('3')),
    initialPayment: PurchasePaymentDraft(businessDate: LocalDate.parse('2026-10-14'), amount: Money.parsePositive('8'), accountId: account.id, categoryId: paymentCategory.id),
  );
  final detail = await env.ledger.getPurchaseDetail(purchaseId);
  expect(detail.position.payable.cents, 1500);
  final bills = await env.cashBills.listCashBills(const CashBillFilter());
  expect(bills.single.businessOrigin, BusinessOrigin.purchasePayment);
  expect(bills.single.linkedType, LinkedBillType.purchasePayment);
});

test('overpayment rolls back purchase payment cash bill', () async {
  final env = await SqliteLedgerTestHarness.open();
  addTearDown(env.close);
  final purchaseId = await env.seedPurchase(total: '23');
  await expectLater(env.ledger.recordPurchasePayment(purchaseId: purchaseId, payment: env.purchasePayment(amount: '24')), throwsA(isA<StateError>()));
  expect(await env.cashBillCount(), 0);
});
```

`seedPurchase`, `purchasePayment` and `cashBillCount` are methods owned by `test/support/sqlite_ledger_test_harness.dart` and must be implemented before this test is committed.

- [ ] **Step 2: Implement purchase writes, reads and lifecycle.** Use one transaction for purchase/items/payment/cash/audit. Business operations pass explicit category IDs and validate active references/direction. Payment void/restore updates the stable `purchase_payments` row and linked cash bill status atomically, recalculates purchase position, audits both rows, and rejects restore if it would overpay or exceed aggregate caps. `voidPurchaseWithoutActivePayments` succeeds only when no active payment or paid refund exists; `restorePurchase` rechecks `0 <= paidNet <= effective payable`.

- [ ] **Step 3: Write unpaid waiver, paid refund and status tests.**

```dart
test('unpaid waiver reduces payable without cash income', () async {
  final env = await SqliteLedgerTestHarness.open();
  addTearDown(env.close);
  final purchaseId = await env.seedPurchase(total: '23');
  await env.ledger.adjustPurchase(PurchaseAdjustmentDraft(purchaseId: purchaseId, kind: PurchaseAdjustmentKind.unpaidWaiver, amount: Money.parsePositive('5'), reason: '少发货', categoryId: env.unusedExpenseCategoryId));
  expect(await env.cashBillCount(), 0);
  expect((await env.ledger.getPurchaseDetail(purchaseId)).purchase.position.payable.cents, 1800);
});

test('voiding and restoring a paid refund updates linked cash status with same ids', () async {
  final env = await SqliteLedgerTestHarness.open();
  addTearDown(env.close);
  final purchaseId = await env.seedPurchase(total: '23', paid: '20');
  final adjustmentId = await env.seedPaidRefund(purchaseId: purchaseId, amount: '7');
  final before = await env.linkedCashBillForAdjustment(adjustmentId);
  await env.ledger.voidPurchaseAdjustment(adjustmentId: adjustmentId, reason: '录错');
  await env.ledger.restorePurchaseAdjustment(adjustmentId: adjustmentId, reason: '恢复');
  final after = await env.linkedCashBillForAdjustment(adjustmentId);
  expect(after.id, before.id);
  expect(after.isVoid, isFalse);
});
```

- [ ] **Step 4: Implement supplier opening debt reads and correction.** Creating debt inserts no cash bill. Paying debt inserts a linked opening-debt payment cash expense, updates `paid_cents`, audits in one transaction, and rejects overpayment. Void/restore payment keeps the same payment and cash IDs and rechecks debt invariants.

- [ ] **Step 5: Write problem resale classification and lifecycle tests.**

```dart
test('real linked resale is included after category rename and ordinary resale-named income is excluded', () async {
  final env = await SqliteLedgerTestHarness.open();
  addTearDown(env.close);
  await env.seedOrdinaryIncomeUsingResaleCategory(amount: '99');
  final resaleId = await env.seedProblemResale(amount: '30');
  await env.catalog.renameCategory(id: env.resaleIncomeCategoryId, name: '普通收入改名');
  final snapshot = await env.dashboard.loadDashboardSnapshot(monthStart: LocalDate.parse('2026-10-01'), monthEnd: LocalDate.parse('2026-10-31'));
  expect(snapshot.monthResaleIncome.cents, 3000);
  expect((await env.ledger.getProblemResaleDetail(resaleId)).netRecovery.cents, 3000);
});

test('voiding and restoring resale group keeps income and fee ids and statuses together', () async {
  final env = await SqliteLedgerTestHarness.open();
  addTearDown(env.close);
  final resaleId = await env.seedProblemResale(amount: '30', fee: '4');
  final before = await env.ledger.getProblemResaleDetail(resaleId);
  await env.ledger.voidProblemResale(resaleId: resaleId, reason: '撤销');
  await env.ledger.restoreProblemResale(resaleId: resaleId, reason: '恢复');
  final after = await env.ledger.getProblemResaleDetail(resaleId);
  expect(after.resale.incomeCashBillId, before.resale.incomeCashBillId);
  expect(after.fees.single.cashBillId, before.fees.single.cashBillId);
});
```

- [ ] **Step 6: Implement problem resale writes/reads.** Income and each fee are inserted atomically with explicit category/account IDs. Insert the resale row, insert the income cash bill with `linked_id=resaleId`, update `problem_resales.income_cash_bill_id`, insert fee cash bills and fee rows, then verify the active resale has a non-null income cash bill before commit. The dashboard resale total joins active `problem_resales` to the linked active income bill; it never trusts category name, category role, or an unlinked `business_origin` alone.

- [ ] **Step 7: Write courier scope, wallet and history tests.**

```dart
test('shared courier wallet accepts two shops but shop detail does not claim global balance', () async {
  final env = await SqliteLedgerTestHarness.open();
  addTearDown(env.close);
  final shopA = await env.createShop('店A');
  final shopB = await env.createShop('店B');
  final courierId = await env.ledger.createCourierAccount(CourierAccountDraft(name: '顺丰A', openingBalance: Money.parsePositive('20'), businessDate: LocalDate.parse('2026-10-01')));
  await env.ledger.recordCourierTopUp(env.courierTopUp(courierAccountId: courierId, scope: BusinessScope.shop(shopA.id), amount: '50'));
  await env.ledger.recordCourierConsume(CourierConsumeDraft(courierAccountId: courierId, scope: BusinessScope.shop(shopB.id), businessDate: LocalDate.parse('2026-10-03'), amount: Money.parsePositive('12')));
  final wallet = await env.ledger.getCourierAccountDetail(courierId);
  expect(wallet.account.recordedBalance.cents, 5800);
  final shopDetail = await env.dashboard.loadLedgerDetailSnapshot(startDate: LocalDate.parse('2026-10-01'), endDate: LocalDate.parse('2026-10-31'), scope: BusinessScope.shop(shopA.id));
  expect(shopDetail.courierTopUp.cents, 5000);
  expect(shopDetail.globalCourierRecordedBalance, isNull);
});

test('voiding old courier topup is rejected when later balance would go negative', () async {
  final env = await SqliteLedgerTestHarness.open();
  addTearDown(env.close);
  final topUpEventId = await env.seedCourierTopUpThenConsumeAll();
  await expectLater(env.ledger.voidCourierEvent(eventId: topUpEventId, reason: '冲正'), throwsA(isA<StateError>()));
});
```

- [ ] **Step 8: Implement courier writes/reads/lifecycle.** Opening balance is global wallet value with null scope and no cash. Top-up/refund/consume each stores explicit `BusinessScope`; top-up/refund create linked cash bills with `linked_id=courierAccountId` and store the exact cash ID on the courier event, while consume creates no cash bill. Wallet balance is recalculated in `(business_date, id)` order for the whole courier account inside the same transaction on insert/void/restore. Restore rechecks negative history and aggregate caps.

- [ ] **Step 9: Add write-time aggregate guard tests.**

```dart
test('second active cash insert exceeding aggregate cap rolls back before commit', () async {
  final env = await SqliteLedgerTestHarness.open();
  addTearDown(env.close);
  await env.seedManualExpenseCents(9000000000000000);
  await expectLater(env.seedManualExpenseCents(1), throwsFormatException);
  final snapshot = await env.dashboard.loadDashboardSnapshot(monthStart: LocalDate.parse('2026-10-01'), monthEnd: LocalDate.parse('2026-10-31'));
  expect(snapshot.monthCashExpense.cents, 9000000000000000);
  expect(await env.auditLogCount(), 1);
});
```

Implement `SqliteAggregateGuard` used inside every transaction that changes active monetary state. It fetches affected active cents rows and calls `Money.sumCents` before commit. Read paths keep the same guard. Add comment in implementation: `// ponytail: O(n) aggregate scan, replace with materialized totals if ledger size makes writes slow.`

- [ ] **Step 10: Run Task 3 checks.**

```sh
"$FLUTTER_SDK/bin/dart" format --output=none --set-exit-if-changed lib test tool
"$FLUTTER_SDK/bin/dart" run tool/check_domain_boundaries.dart
"$FLUTTER_SDK/bin/flutter" test test/features/ledger/data/sqlite_business_transaction_test.dart test/features/dashboard/data/sqlite_dashboard_repository_test.dart
```

Expected: PASS.

- [ ] **Step 11: Commit Task 3.**

```bash
git add lib/core/data/sqlite_aggregate_guard.dart lib/features/ledger/data/sqlite_ledger_repository.dart lib/features/dashboard/data/sqlite_dashboard_repository.dart test/support/sqlite_ledger_test_harness.dart test/features/ledger/data/sqlite_business_transaction_test.dart test/features/dashboard/data/sqlite_dashboard_repository_test.dart
git commit -m "feat: add ledger business transactions"
```

## Task 4: Provider bootstrap, dashboard, catalog and manual cash UI

**Files:**
- Create: `lib/app/app_dependencies.dart`
- Modify: `lib/app/app.dart`
- Modify: `lib/app/presentation/dashboard_page.dart`
- Modify: `lib/app/presentation/ledger_page.dart`
- Modify: `lib/app/presentation/settings_page.dart`
- Modify: `lib/app/presentation/ai_page.dart`
- Create: `lib/features/catalog/presentation/catalog_view_model.dart`
- Create: `lib/features/catalog/presentation/catalog_pages.dart`
- Create: `lib/features/ledger/presentation/ledger_view_models.dart`
- Create: `lib/features/ledger/presentation/cash_bill_pages.dart`
- Create: `lib/features/dashboard/presentation/dashboard_view_model.dart`
- Create: `test/support/widget_test_app.dart`
- Test: `test/app/app_bootstrap_test.dart`
- Test: `test/app/navigation_test.dart`
- Test: `test/features/catalog/presentation/catalog_view_model_test.dart`
- Test: `test/features/ledger/presentation/ledger_view_model_test.dart`
- Test: `test/features/dashboard/presentation/dashboard_view_model_test.dart`

**Interfaces:**
- Consumes: Task 2/3 repositories.
- Produces: `AppDependenciesBootstrap.open()`, provider wiring for `CatalogRepository`, `CashBillRepository`, `LedgerRepository`, `DashboardRepository`, `DashboardViewModel.reload()`, `CashLedgerViewModel`, `CatalogViewModel`, and real ordinary cash create/edit/void/restore UI.

- [ ] **Step 1: Write bootstrap privacy failure widget test.**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finances_pro/app/app.dart';
import 'package:personal_finances_pro/app/app_dependencies.dart';

final class FailingBootstrap implements AppDependenciesBootstrap {
  @override
  Future<AppDependencies> open() => Future<AppDependencies>.error(Exception('无法确认账本已排除系统自动备份'));
}

void main() {
  testWidgets('privacy setup failure blocks ledger pages with clear error', (tester) async {
    await tester.pumpWidget(ShopLedgerApp(dependenciesBootstrap: FailingBootstrap()));
    await tester.pumpAndSettle();
    expect(find.textContaining('无法确认账本已排除系统自动备份'), findsOneWidget);
    expect(find.text('新增现金账'), findsNothing);
  });
}
```

- [ ] **Step 2: Implement dependency bootstrap.**

```dart
abstract interface class AppDependenciesBootstrap {
  Future<AppDependencies> open();
}

final class AppDependencies {
  AppDependencies({required this.catalogRepository, required this.cashBillRepository, required this.ledgerRepository, required this.dashboardRepository, required this.close});
  final CatalogRepository catalogRepository;
  final CashBillRepository cashBillRepository;
  final LedgerRepository ledgerRepository;
  final DashboardRepository dashboardRepository;
  final Future<void> Function() close;
}
```

Default bootstrap opens `LedgerDatabase` with production `LedgerPrivacy`, creates `SqliteCatalogRepository`, `SqliteCashBillRepository`, `SqliteLedgerRepository`, `SqliteDashboardRepository`, runs `ensureDefaultCatalogs()`, and provides them. On open failure, show a Cupertino page with the error and no fake empty store. Dispose closes the database.

- [ ] **Step 3: Write ViewModel commit/refresh tests using `test/support/widget_test_app.dart` fakes.**

```dart
test('cash view model reports committed save with refresh failure without duplicate retry', () async {
  final repo = RecordingCashBillRepository(refreshThrows: true);
  final vm = CashLedgerViewModel(cashBillRepository: repo, catalogRepository: RecordingCatalogRepository());
  await vm.saveCashBill(validDraft);
  expect(vm.lastSaveCommitted, isTrue);
  expect(vm.errorMessage, contains('已保存，但刷新失败'));
  await vm.saveCashBill(validDraft);
  expect(repo.createCashBillCalls, 1);
});

test('commit failure keeps user input and allows corrected retry', () async {
  final repo = RecordingCashBillRepository(commitThrows: true);
  final vm = CashLedgerViewModel(cashBillRepository: repo, catalogRepository: RecordingCatalogRepository());
  vm.amountText = '18.00';
  await vm.saveFromForm();
  expect(vm.amountText, '18.00');
  expect(vm.lastSaveCommitted, isFalse);
  expect(vm.isSaving, isFalse);
});
```

- [ ] **Step 4: Implement Dashboard page real empty/non-empty cards.** Show `本月实付支出`, `当前厂家待付款`, `本月问题件回收`, recent bills and zero amounts for an empty ledger. Do not label cash net as profit.

- [ ] **Step 5: Implement Ledger page ordinary cash list/filter/detail.** Generic edit/void/restore buttons appear only when `businessOrigin == BusinessOrigin.ordinary`; linked rows show owning-business copy and route to the owning business detail where Task 5 provides correction actions.

- [ ] **Step 6: Implement ordinary cash bill form.** Fields: strict date, income/expense, amount, public/shop, category, account, optional party, note. Save button is disabled while saving; failed validation/commit preserves fields; committed-save refresh failure shows the committed warning and disables duplicate create.

- [ ] **Step 7: Implement catalog settings pages.** Pages support create, rename and deactivate for shops/accounts/parties/categories/channels. No physical delete. New assignments hide inactive rows; unchanged historical inactive references remain displayable.

- [ ] **Step 8: Update navigation and layout tests.** Keep existing width 320/390/430, text scale 1.5, safe-area and keyboard tests. Replace stale placeholder expectations with `本月实付支出`, `0.00`, `新增现金账`, disabled AI send/confirm buttons and visible final save row above the keyboard.

- [ ] **Step 9: Run Task 4 checks.**

```sh
"$FLUTTER_SDK/bin/dart" format --output=none --set-exit-if-changed lib test tool
"$FLUTTER_SDK/bin/flutter" analyze
"$FLUTTER_SDK/bin/flutter" test test/app test/features/catalog/presentation test/features/ledger/presentation/ledger_view_model_test.dart test/features/dashboard/presentation
```

Expected: PASS.

- [ ] **Step 10: Commit Task 4.**

```bash
git add lib/app lib/features/catalog/presentation lib/features/ledger/presentation lib/features/dashboard/presentation test/support/widget_test_app.dart test/app test/features/catalog/presentation test/features/ledger/presentation/ledger_view_model_test.dart test/features/dashboard/presentation
git commit -m "feat: connect ledger shell to persisted data"
```

## Task 5: Manual procurement, resale, courier, detail and status UI

**Files:**
- Modify: `lib/app/app.dart`
- Modify: `lib/app/presentation/ledger_page.dart`
- Modify: `lib/features/ledger/presentation/ledger_view_models.dart`
- Create: `lib/features/ledger/presentation/procurement_pages.dart`
- Create: `lib/features/ledger/presentation/problem_resale_pages.dart`
- Create: `lib/features/ledger/presentation/courier_pages.dart`
- Create: `lib/features/ledger/presentation/ledger_detail_pages.dart`
- Test: `test/features/ledger/presentation/manual_flow_widget_test.dart`
- Extend: `test/app/navigation_test.dart`

**Interfaces:**
- Consumes: Task 3 `LedgerRepository` reads/writes/lifecycle methods and Task 4 bootstrap.
- Produces: reachable native Cupertino manual flows for purchases/payments/refunds/opening debt/problem resale/courier/detail snapshots and owning-business status operations.

- [ ] **Step 1: Add routes under the existing shell.** Add routes for `/ledger/cash/new`, `/ledger/purchases/new`, `/ledger/purchases/:id`, `/ledger/purchases/:id/payment`, `/ledger/purchases/:id/adjust`, `/ledger/opening-debts/new`, `/ledger/opening-debts/:id`, `/ledger/resales/new`, `/ledger/resales/:id`, `/ledger/courier/accounts/new`, `/ledger/courier/:id`, `/ledger/courier/:id/topup`, `/ledger/courier/:id/consume`, `/ledger/courier/:id/refund`, `/ledger/detail`.

- [ ] **Step 2: Implement purchase and opening-debt pages.** Purchase list/detail uses `listPurchases`/`getPurchaseDetail`; detail shows original, effective, paid net and payable. Payment, payment void/restore, unpaid waiver, paid refund, adjustment void/restore, purchase void/restore and opening-debt payment void/restore all call owning repository methods and preserve input on errors. UI copy states unpaid purchase is not a cash expense.

- [ ] **Step 3: Write procurement form/status widget tests.**

```dart
testWidgets('purchase form keeps input on overpayment error and disables duplicate save', (tester) async {
  final repos = FakeAppRepositories.withLedgerError(StateError('不得超过待付金额'));
  await pumpLedgerAppWithRepositories(tester, repos);
  await tester.tap(find.text('采购单'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const ValueKey('purchase-item-description-0')), '发夹');
  await tester.enterText(find.byKey(const ValueKey('purchase-item-quantity-0')), '2');
  await tester.enterText(find.byKey(const ValueKey('purchase-item-price-0')), '10');
  await tester.enterText(find.byKey(const ValueKey('purchase-initial-payment')), '25');
  await tester.tap(find.byKey(const ValueKey('purchase-save-button')));
  await tester.pump();
  expect(tester.widget<CupertinoButton>(find.byKey(const ValueKey('purchase-save-button'))).onPressed, isNull);
  await tester.pumpAndSettle();
  expect(find.textContaining('不得超过待付金额'), findsOneWidget);
  expect(find.text('25'), findsOneWidget);
});
```

- [ ] **Step 4: Implement problem resale pages.** List/detail uses `listProblemResales`/`getProblemResaleDetail`; form collects gross income category/account, buyer, channel and independent fee rows with fee category/account. Detail shows income, fees, net recovery and void/restore buttons that affect the group atomically.

- [ ] **Step 5: Implement courier pages with explicit scope.** Account detail uses `getCourierAccountDetail` and shows global recorded balance in the prepaid view. Top-up/refund/consume forms require public/shop scope for the event; consume copy says `不产生第二笔现金支出`. Selected-shop ledger detail does not display global wallet balance as that shop's balance.

- [ ] **Step 6: Implement ledger detail snapshot page.** Display period cash income, cash expense, cash net with `不含平台主要收入，不代表利润或亏损`, purchase effective/paid/payable, resale income/fees/net, courier top-up/consume and global prepaid balance only when the repository returns a non-null `globalCourierRecordedBalance`.

- [ ] **Step 7: Add layout tests for new forms.** At widths 320/390/430 with text scale 1.5, open purchase, resale and courier consume pages, focus the last input, set keyboard inset 300, scroll to final save row and assert the save button bottom is `<= logicalHeight - keyboard`.

- [ ] **Step 8: Run Task 5 checks.**

```sh
"$FLUTTER_SDK/bin/dart" format --output=none --set-exit-if-changed lib test tool
"$FLUTTER_SDK/bin/flutter" analyze
"$FLUTTER_SDK/bin/flutter" test test/features/ledger/presentation/manual_flow_widget_test.dart test/app/navigation_test.dart
```

Expected: PASS.

- [ ] **Step 9: Commit Task 5.**

```bash
git add lib/app/app.dart lib/app/presentation/ledger_page.dart lib/features/ledger/presentation test/features/ledger/presentation/manual_flow_widget_test.dart test/app/navigation_test.dart
git commit -m "feat: add manual ledger business flows"
```

## Task 6: Integration checks, docs, CI and privacy evidence

**Files:**
- Modify: `README.md`
- Modify: `.github/workflows/flutter.yml`
- Modify: `.gitignore` only if verification finds a missing privacy rule
- Create: `test/app/local_ledger_integration_test.dart`
- Extend: `test/check_domain_boundaries_test.dart` only if new domain paths expose a gap

**Interfaces:**
- Consumes: all previous tasks and `test/support/sqlite_ledger_test_harness.dart`.
- Produces: reviewer-ready proof that local ledger works offline, tests use real SQL, native backup-exclusion source is checked, and docs do not claim excluded stages.

- [ ] **Step 1: Write an end-to-end SQL integration test.**

```dart
test('offline local ledger flow persists and snapshots use business links', () async {
  final env = await SqliteLedgerTestHarness.open();
  addTearDown(env.close);
  final shop = await env.createShop('一店');
  final supplier = await env.createParty(name: '厂家A', kind: PartyKind.supplier);
  final buyer = await env.createParty(name: '买家B', kind: PartyKind.buyer);
  final account = await env.createAccount('测试账户Z');
  final channel = (await env.catalog.listResaleChannels()).first;
  final paymentCategory = await env.createCategory(name: '厂家付款Z', direction: CashDirection.expense);
  final incomeCategory = await env.createCategory(name: '问题件收入Z', direction: CashDirection.income);

  await env.ledger.createPurchase(
    PurchaseDraft(supplierId: supplier.id, scope: BusinessScope.shop(shop.id), businessDate: LocalDate.parse('2026-10-14'), items: [PurchaseItemDraft(description: '发夹', quantity: 2, unitPrice: Money.parsePositive('10'))], supplierFreight: Money.parsePositive('3')),
    initialPayment: PurchasePaymentDraft(businessDate: LocalDate.parse('2026-10-14'), amount: Money.parsePositive('8'), accountId: account.id, categoryId: paymentCategory.id),
  );

  await env.ledger.createProblemResale(ProblemResaleDraft(scope: BusinessScope.shop(shop.id), businessDate: LocalDate.parse('2026-10-15'), description: '问题件', quantity: 1, incomeAmount: Money.parsePositive('30'), incomeAccountId: account.id, incomeCategoryId: incomeCategory.id, buyerId: buyer.id, channelId: channel.id, issueNote: '破损', fees: []));

  await env.closeAndReopen();
  final snapshot = await env.dashboard.loadDashboardSnapshot(monthStart: LocalDate.parse('2026-10-01'), monthEnd: LocalDate.parse('2026-10-31'), scope: BusinessScope.shop(shop.id));
  expect(snapshot.monthCashExpense.cents, 800);
  expect(snapshot.supplierPayable.cents, 1500);
  expect(snapshot.monthResaleIncome.cents, 3000);
});
```

- [ ] **Step 2: Keep CI to format, boundary, analyze and full test.** The existing Android debug build remains main-branch only. Do not add publish, signing, license acceptance or global SDK changes.

- [ ] **Step 3: Update README stage status.** Mark local SQLite ledger, catalog, manual cash bills, procurement/payment/refund, problem resale, courier prepaid and snapshot totals as implemented after this stage. Keep CSV, full JSON backup/restore, real AI, native device backup proof and store publishing outside this stage. Document pinned library versions and commands using `$FLUTTER_SDK` only.

- [ ] **Step 4: Verify `.gitignore` protections.** Confirm these patterns remain present: `*.db`, `*.db-*`, `*.sqlite`, `*.sqlite-*`, `backups/`, `exports/`, `.env`, `.env.*`, `*.jks`, `*.keystore`, `**/key.properties`, `**/local.properties`, `**/Pods/`, `**/Flutter/ephemeral/`, `**/xcuserdata/`. Add a missing pattern only if absent.

- [ ] **Step 5: Run full validation.**

```sh
"$FLUTTER_SDK/bin/flutter" pub get
"$FLUTTER_SDK/bin/dart" format --output=none --set-exit-if-changed lib test tool
"$FLUTTER_SDK/bin/dart" run tool/check_domain_boundaries.dart
"$FLUTTER_SDK/bin/flutter" analyze
"$FLUTTER_SDK/bin/flutter" test
```

Expected: PASS. Android/iOS device validation remains separate if local licenses or tools block it; do not report unavailable native builds as passed.

- [ ] **Step 6: Commit Task 6.**

```bash
git add README.md .github/workflows/flutter.yml .gitignore test/app/local_ledger_integration_test.dart test/check_domain_boundaries_test.dart
git commit -m "test: verify local ledger integration"
```

## Self-review and F1-F8 correction record

- F1 privacy-path binding: closed. `PreparedLedgerDirectory` returns canonical path plus verification, `LedgerDatabase` opens only inside that directory, mismatch/unverified tests run before file creation, and iOS returns the exact excluded directory path.
- F2 operation-derived classification: closed. Ordinary cash always stores `BusinessOrigin.ordinary`; category roles are suggestions only; business operations pass explicit category IDs and assign operation links/origins; dashboard joins real resale links.
- F3 UI business read contracts: closed. Immutable read models, filters and list/get detail methods are defined for purchases, opening debts, resales and courier accounts/events.
- F4 Task2 boundary: closed. Task 2 produces complete `SqliteCashBillRepository implements CashBillRepository`; Task 3 creates the full `SqliteLedgerRepository`; no production stubs are allowed.
- F5 lifecycle: closed. Payment, adjustment, opening-debt payment, resale group and courier event void/restore operations keep stable IDs, update linked cash statuses atomically and recheck invariants.
- F6 courier scope: closed. Courier cash/consume events carry explicit `BusinessScope`; wallet balance is global and not presented as a selected-shop balance.
- F7 aggregate guards: closed. Write transactions use `SqliteAggregateGuard` before commit and tests assert rejected second write/restore rolls back state; read guards remain.
- F8 runnable tests/bootstrap: closed. Shared SQL harness, widget helper, database factory/path injection and `AppDependenciesBootstrap.open()` are defined; duplicate default `微信` fixture bug removed.
- Placeholder scan target: no forbidden placeholder markers or undefined helper names outside the declared support contracts.
- Residual concern: native backup source/static checks and iOS channel readback are planned; real device backup behavior remains a separate validation after implementation tooling is available.
