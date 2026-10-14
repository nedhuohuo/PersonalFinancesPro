# Local Ledger Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the approved local SQLite ledger stage with persisted catalog records, cash bills, procurement/payment rules, problem-goods resale, courier prepaid records, real snapshot totals and reachable manual Cupertino flows, while keeping AI send/key/confirmation disabled.

**Architecture:** Pure Dart domain models and repository contracts sit under `lib/features/*/domain` and `lib/core/domain`; SQLite, native privacy setup and row mapping sit in `data` folders; existing Cupertino router/page shell remains the UI entry point and uses provider/ChangeNotifier for manual flows. The database opens only after backup-exclusion setup succeeds, all linked business writes use one SQLite transaction, and UI state refreshes only after committed repository results.

**Tech Stack:** Flutter stable 3.29.2 / Dart 3.7.2, Cupertino, provider, go_router, existing `Money`, `sqflite` 2.4.2, `path` 1.9.1, dev-only `sqflite_common_ffi` 2.3.5, flutter_test.

**Spec:** `docs/superpowers/specs/2026-10-13-shop-ledger-design.md`

## Global Constraints

- Flutter 开发，支持 Android 与 iOS；两端统一采用 Apple 风格 Cupertino 界面。
- 应用标识使用 `dev.nedhuohuo.personalfinancespro`。
- 本地优先：SQLite 保存业务数据，支持手动备份、恢复；本计划只实现本地账本，不实现 CSV/report subsystem、完整 JSON 备份/恢复或真实 AI。
- 首版以人民币为唯一货币。
- 金额以整数分存储和计算，不用 `double` 处理金额；单笔及汇总金额不得超过 `9,000,000,000,000,000` 分，越界拒绝操作。
- 金额输入从十进制字符串精确解析，最多两位小数；超出精度要求用户改正，不静默舍入。
- 业务日期以严格 `YYYY-MM-DD` 保存；审计时间以 UTC 保存。
- Runtime data libraries are pinned to `sqflite: 2.4.2` and `path: 1.9.1`; actual DB tests use dev-only `sqflite_common_ffi: 2.3.5` with temporary SQL files and reopen checks.
- domain 是纯 Dart，不导入 Flutter、SQLite、HTTP 或插件；`tool/check_domain_boundaries.dart` remains a required gate.
- 使用 provider 进行依赖注入，不使用全局 Service Locator、generic BaseRepository、EventBus、one-implementation interface scaffold or code generation.
- Stable local IDs use SQLite-generated `INTEGER PRIMARY KEY AUTOINCREMENT`; no homegrown UUID generator.
- 已有账目引用的资料不允许物理删除；停用保留历史账单。
- 账户标签只标记收付款来源，不计算真实银行/微信/支付宝余额。
- 采购单、付款、厂家退款、问题件收入及关联费用、快递预付事件必须在事务内原子保存；linked bills cannot be edited or voided through generic cash flows.
- Procurement rules preserve `0 <= paidNet <= effective payable`; no supplier prepayment in this stage.
- Courier consume creates no second cash expense; backdated/history voids cannot make any later ledger balance negative.
- Business origin and linked IDs are authoritative for resale income/refunds/snapshots; renamed category text must not change classification.
- Monetary aggregation for snapshots must not rely on SQLite `SUM()` over money columns; aggregate cents in Dart with `BigInt` guard before converting to `Money`.
- BEFORE first production data write, exclude the ledger DB from automatic system cloud backup; failed privacy setup blocks opening/writing with a clear error and never clears or replaces the store.
- Catalog presets are generic categories/account labels only; no fake shops, parties, transactions or demonstration rows.
- Preserve `.gitignore` database/WAL/backup/key/native-cache protections.
- AI send/key/confirmation remains disabled in Flutter UI for this stage.
- Public docs use `$FLUTTER_SDK` examples, never local machine SDK paths.

---

## Scope split and coverage

| Unit | Independent review boundary | Main risk covered |
|---|---|---|
| 1 | Pure domain contracts, value objects and calculations | Exact money/date/quantity rules and method names for all other units |
| 2 | SQLite dependencies, privacy gate, schema, catalog and generic cash storage | Real persistence, reopen, native backup exclusion, no fake rows |
| 3 | Business transactional repository | Procurement, refunds, problem resale fees and courier invariants remain atomic |
| 4 | Provider bootstrap, dashboard/ledger/catalog manual UI | Existing shell reads real data and keeps AI disabled |
| 5 | Manual procurement/resale/courier/detail/status UI | Reachable native forms for the required business flows |
| 6 | Integration checks, CI/docs/privacy verification | End-to-end proof, stale placeholder expectations updated honestly |

## File map

### Existing files to modify

- `pubspec.yaml`: add pinned SQLite runtime libs and dev-only FFI test lib.
- `lib/core/domain/money.dart`: keep exact existing API; add `Money.checkedProduct({required int quantity, required Money unitPrice})` and `Money.sumCents(Iterable<int> centsValues)` if Task 1 tests require them.
- `lib/app/app.dart`: inject dependencies with provider and keep one `StatefulShellRoute.indexedStack` + one `CupertinoTabBar`.
- `lib/app/presentation/dashboard_page.dart`: replace placeholder cards with repository-backed snapshot cards.
- `lib/app/presentation/ledger_page.dart`: replace placeholder ledger sections with real list/detail entry points.
- `lib/app/presentation/settings_page.dart`: add reachable catalog and data-safety rows; no enabled backup/AI credential flows.
- `lib/app/presentation/ai_page.dart`: keep send and confirmation disabled, with copy updated only if tests need exact stage wording.
- `test/app/navigation_test.dart`: update expectations from placeholders to real empty persisted state and disabled AI.
- `tool/check_domain_boundaries.dart`: keep existing decoded import/export scanner; include new domain folders in the normal `lib` scan.
- `android/app/src/main/AndroidManifest.xml`: add backup exclusion attributes before database writes.
- `ios/Runner/AppDelegate.swift`: add a minimal MethodChannel for iOS ledger directory backup exclusion.
- `.gitignore`, `README.md`, `.github/workflows/flutter.yml`: verify protections and commands include the new checks.

### New files to create

- `lib/core/domain/local_date.dart`
- `test/core/domain/local_date_test.dart`
- `test/core/domain/money_product_test.dart`
- `lib/core/data/ledger_privacy.dart`
- `lib/core/data/ledger_database.dart`
- `lib/core/data/ledger_schema.dart`
- `lib/core/data/sqlite_statement.dart`
- `test/core/data/ledger_privacy_test.dart`
- `test/core/data/ledger_schema_test.dart`
- `test/core/data/backup_exclusion_static_test.dart`
- `lib/features/catalog/domain/catalog_models.dart`
- `lib/features/catalog/domain/catalog_repository.dart`
- `lib/features/catalog/data/sqlite_catalog_repository.dart`
- `lib/features/catalog/presentation/catalog_view_model.dart`
- `lib/features/catalog/presentation/catalog_pages.dart`
- `test/features/catalog/data/sqlite_catalog_repository_test.dart`
- `test/features/catalog/presentation/catalog_view_model_test.dart`
- `lib/features/ledger/domain/ledger_models.dart`
- `lib/features/ledger/domain/ledger_repository.dart`
- `lib/features/ledger/data/sqlite_ledger_repository.dart`
- `lib/features/ledger/presentation/ledger_view_models.dart`
- `lib/features/ledger/presentation/cash_bill_pages.dart`
- `lib/features/ledger/presentation/procurement_pages.dart`
- `lib/features/ledger/presentation/problem_resale_pages.dart`
- `lib/features/ledger/presentation/courier_pages.dart`
- `lib/features/ledger/presentation/ledger_detail_pages.dart`
- `test/features/ledger/domain/ledger_domain_test.dart`
- `test/features/ledger/data/sqlite_cash_bill_repository_test.dart`
- `test/features/ledger/data/sqlite_business_transaction_test.dart`
- `test/features/ledger/presentation/ledger_view_model_test.dart`
- `test/features/ledger/presentation/manual_flow_widget_test.dart`
- `lib/features/dashboard/domain/dashboard_snapshots.dart`
- `lib/features/dashboard/domain/dashboard_repository.dart`
- `lib/features/dashboard/data/sqlite_dashboard_repository.dart`
- `lib/features/dashboard/presentation/dashboard_view_model.dart`
- `test/features/dashboard/data/sqlite_dashboard_repository_test.dart`
- `test/features/dashboard/presentation/dashboard_view_model_test.dart`
- `lib/app/app_dependencies.dart`
- `test/app/app_bootstrap_test.dart`
- `android/app/src/main/res/xml/backup_rules.xml`
- `android/app/src/main/res/xml/data_extraction_rules.xml`

## Shared domain contract

Tasks must use these exact names so separately implemented units compose without renaming.

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
enum CategoryBusinessOrigin {
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
  const BusinessScope.public();
  const BusinessScope.shop(this.shopId);
  final int? shopId;
  BusinessScopeType get type;
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
  const Category({
    required this.id,
    required this.name,
    required this.direction,
    required this.businessOrigin,
    required this.isSystem,
    required this.isActive,
  });
  final int id;
  final String name;
  final CashDirection direction;
  final CategoryBusinessOrigin businessOrigin;
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

  Future<List<Category>> listCategories({CashDirection? direction, bool includeInactive = false});
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
enum CashBillSource {
  manual,
  purchasePayment,
  supplierRefund,
  openingDebtPayment,
  resaleIncome,
  resaleFee,
  courierTopUp,
  courierRefund,
}

enum LinkedBillType {
  purchasePayment,
  supplierRefund,
  openingDebtPayment,
  problemResaleIncome,
  problemResaleFee,
  courierTopUp,
  courierRefund,
}

enum PurchaseAdjustmentKind { unpaidWaiver, paidRefund }
enum CourierEventType { opening, topUp, consume, refund }

final class CashBillDraft {
  const CashBillDraft({
    required this.businessDate,
    required this.direction,
    required this.amount,
    required this.scope,
    required this.categoryId,
    required this.accountId,
    this.partyId,
    this.note = '',
  });
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
  const CashBill({
    required this.id,
    required this.businessDate,
    required this.direction,
    required this.amount,
    required this.scope,
    required this.categoryId,
    required this.accountId,
    required this.partyId,
    required this.note,
    required this.source,
    required this.businessOrigin,
    required this.linkedType,
    required this.linkedId,
    required this.isVoid,
    required this.createdAtUtc,
    required this.updatedAtUtc,
  });
  final int id;
  final LocalDate businessDate;
  final CashDirection direction;
  final Money amount;
  final BusinessScope scope;
  final int categoryId;
  final int accountId;
  final int? partyId;
  final String note;
  final CashBillSource source;
  final CategoryBusinessOrigin businessOrigin;
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
  const PurchasePaymentDraft({required this.businessDate, required this.amount, required this.accountId, this.note = ''});
  final LocalDate businessDate;
  final Money amount;
  final int accountId;
  final String note;
}

final class PurchaseAdjustmentDraft {
  const PurchaseAdjustmentDraft({required this.purchaseId, required this.kind, required this.amount, required this.reason, this.businessDate, this.accountId});
  final int purchaseId;
  final PurchaseAdjustmentKind kind;
  final Money amount;
  final String reason;
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
  const ProblemResaleDraft({
    required this.scope,
    required this.businessDate,
    required this.description,
    required this.quantity,
    required this.incomeAmount,
    required this.incomeAccountId,
    required this.buyerId,
    required this.channelId,
    required this.issueNote,
    required this.fees,
  });
  final BusinessScope scope;
  final LocalDate businessDate;
  final String description;
  final int quantity;
  final Money incomeAmount;
  final int incomeAccountId;
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
```

```dart
// lib/features/ledger/domain/ledger_repository.dart
abstract interface class LedgerRepository {
  Future<CashBill> createCashBill(CashBillDraft draft);
  Future<CashBill> updateCashBill({required int id, required CashBillDraft draft});
  Future<void> voidCashBill(int id, {required String reason});
  Future<void> restoreCashBill(int id, {required String reason});
  Future<List<CashBill>> listCashBills(CashBillFilter filter);

  Future<int> createPurchase(PurchaseDraft draft, {PurchasePaymentDraft? initialPayment});
  Future<void> recordPurchasePayment({required int purchaseId, required PurchasePaymentDraft payment});
  Future<void> voidPurchaseWithoutPayments({required int purchaseId, required String reason});
  Future<void> adjustPurchase(PurchaseAdjustmentDraft draft);
  Future<int> createSupplierOpeningDebt(SupplierOpeningDebtDraft draft);
  Future<void> paySupplierOpeningDebt({required int openingDebtId, required PurchasePaymentDraft payment});

  Future<int> createProblemResale(ProblemResaleDraft draft);
  Future<void> voidProblemResale({required int resaleId, required String reason});

  Future<int> createCourierAccount(CourierAccountDraft draft);
  Future<void> recordCourierTopUp({required int courierAccountId, required LocalDate businessDate, required Money amount, required int accountId, required String note});
  Future<void> recordCourierConsume({required int courierAccountId, required LocalDate businessDate, required Money amount, required String note});
  Future<void> recordCourierRefund({required int courierAccountId, required LocalDate businessDate, required Money amount, required int accountId, required String note});
  Future<void> voidCourierEvent({required int eventId, required String reason});
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
  const LedgerDetailSnapshot({
    required this.cashIncome,
    required this.cashExpense,
    required this.cashNet,
    required this.purchaseEffective,
    required this.purchasePaidNet,
    required this.purchasePayable,
    required this.resaleIncome,
    required this.resaleFees,
    required this.resaleNetRecovery,
    required this.courierTopUp,
    required this.courierConsume,
    required this.courierRecordedBalance,
  });
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
  final Money courierRecordedBalance;
}
```

```dart
// lib/features/dashboard/domain/dashboard_repository.dart
abstract interface class DashboardRepository {
  Future<DashboardSnapshot> loadDashboardSnapshot({required LocalDate monthStart, required LocalDate monthEnd, BusinessScope? scope});
  Future<LedgerDetailSnapshot> loadLedgerDetailSnapshot({required LocalDate startDate, required LocalDate endDate, BusinessScope? scope});
}
```

## SQLite schema contract

Task 2 writes this exact schema through `LedgerSchema.createV1(Database db)`. Use `INTEGER` for booleans with values 0/1. Use UTC ISO-8601 strings ending in `Z` for audit timestamps. All foreign keys are enforced with `PRAGMA foreign_keys = ON` in `onConfigure`.

```sql
CREATE TABLE shops (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE,
  is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
  created_at_utc TEXT NOT NULL,
  updated_at_utc TEXT NOT NULL
);

CREATE TABLE account_labels (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE,
  is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
  created_at_utc TEXT NOT NULL,
  updated_at_utc TEXT NOT NULL
);

CREATE TABLE parties (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  kind TEXT NOT NULL CHECK (kind IN ('supplier', 'buyer', 'courier', 'other')),
  is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
  created_at_utc TEXT NOT NULL,
  updated_at_utc TEXT NOT NULL,
  UNIQUE (name, kind)
);

CREATE TABLE categories (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  direction TEXT NOT NULL CHECK (direction IN ('income', 'expense')),
  business_origin TEXT NOT NULL CHECK (business_origin IN ('ordinary', 'purchasePayment', 'supplierRefund', 'resaleIncome', 'resaleFee', 'courierTopUp', 'courierRefund', 'openingDebtPayment')),
  is_system INTEGER NOT NULL DEFAULT 0 CHECK (is_system IN (0, 1)),
  is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
  created_at_utc TEXT NOT NULL,
  updated_at_utc TEXT NOT NULL,
  UNIQUE (name, direction)
);

CREATE TABLE resale_channels (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE,
  is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
  created_at_utc TEXT NOT NULL,
  updated_at_utc TEXT NOT NULL
);

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
  source TEXT NOT NULL CHECK (source IN ('manual', 'purchasePayment', 'supplierRefund', 'openingDebtPayment', 'resaleIncome', 'resaleFee', 'courierTopUp', 'courierRefund')),
  business_origin TEXT NOT NULL CHECK (business_origin IN ('ordinary', 'purchasePayment', 'supplierRefund', 'resaleIncome', 'resaleFee', 'courierTopUp', 'courierRefund', 'openingDebtPayment')),
  linked_type TEXT CHECK (linked_type IN ('purchasePayment', 'supplierRefund', 'openingDebtPayment', 'problemResaleIncome', 'problemResaleFee', 'courierTopUp', 'courierRefund')),
  linked_id INTEGER,
  is_void INTEGER NOT NULL DEFAULT 0 CHECK (is_void IN (0, 1)),
  created_at_utc TEXT NOT NULL,
  updated_at_utc TEXT NOT NULL,
  voided_at_utc TEXT,
  CHECK ((scope_type = 'public' AND shop_id IS NULL) OR (scope_type = 'shop' AND shop_id IS NOT NULL)),
  CHECK ((linked_type IS NULL AND linked_id IS NULL AND source = 'manual') OR (linked_type IS NOT NULL AND linked_id IS NOT NULL AND source <> 'manual'))
);

CREATE INDEX cash_bills_filter_idx ON cash_bills(business_date, scope_type, shop_id, category_id, party_id, is_void);
CREATE INDEX cash_bills_link_idx ON cash_bills(linked_type, linked_id);

CREATE TABLE purchases (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  supplier_id INTEGER NOT NULL REFERENCES parties(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
  business_date TEXT NOT NULL,
  scope_type TEXT NOT NULL CHECK (scope_type IN ('public', 'shop')),
  shop_id INTEGER REFERENCES shops(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
  item_total_cents INTEGER NOT NULL CHECK (item_total_cents >= 0 AND item_total_cents <= 9000000000000000),
  supplier_freight_cents INTEGER NOT NULL CHECK (supplier_freight_cents >= 0 AND supplier_freight_cents <= 9000000000000000),
  original_total_cents INTEGER NOT NULL CHECK (original_total_cents > 0 AND original_total_cents <= 9000000000000000),
  effective_total_cents INTEGER NOT NULL CHECK (effective_total_cents >= 0 AND effective_total_cents <= 9000000000000000),
  note TEXT NOT NULL DEFAULT '',
  is_void INTEGER NOT NULL DEFAULT 0 CHECK (is_void IN (0, 1)),
  created_at_utc TEXT NOT NULL,
  updated_at_utc TEXT NOT NULL,
  voided_at_utc TEXT,
  CHECK ((scope_type = 'public' AND shop_id IS NULL) OR (scope_type = 'shop' AND shop_id IS NOT NULL))
);

CREATE TABLE purchase_items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  purchase_id INTEGER NOT NULL REFERENCES purchases(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
  description TEXT NOT NULL,
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  unit_price_cents INTEGER NOT NULL CHECK (unit_price_cents > 0 AND unit_price_cents <= 9000000000000000),
  line_total_cents INTEGER NOT NULL CHECK (line_total_cents > 0 AND line_total_cents <= 9000000000000000)
);

CREATE TABLE purchase_payments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  purchase_id INTEGER NOT NULL REFERENCES purchases(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
  cash_bill_id INTEGER NOT NULL UNIQUE REFERENCES cash_bills(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
  amount_cents INTEGER NOT NULL CHECK (amount_cents > 0 AND amount_cents <= 9000000000000000),
  is_void INTEGER NOT NULL DEFAULT 0 CHECK (is_void IN (0, 1)),
  created_at_utc TEXT NOT NULL
);

CREATE TABLE purchase_adjustments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  purchase_id INTEGER NOT NULL REFERENCES purchases(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
  kind TEXT NOT NULL CHECK (kind IN ('unpaidWaiver', 'paidRefund')),
  amount_cents INTEGER NOT NULL CHECK (amount_cents > 0 AND amount_cents <= 9000000000000000),
  cash_bill_id INTEGER UNIQUE REFERENCES cash_bills(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
  reason TEXT NOT NULL,
  is_void INTEGER NOT NULL DEFAULT 0 CHECK (is_void IN (0, 1)),
  created_at_utc TEXT NOT NULL,
  CHECK ((kind = 'paidRefund' AND cash_bill_id IS NOT NULL) OR (kind = 'unpaidWaiver' AND cash_bill_id IS NULL))
);

CREATE TABLE supplier_opening_debts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  supplier_id INTEGER NOT NULL REFERENCES parties(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
  business_date TEXT NOT NULL,
  scope_type TEXT NOT NULL CHECK (scope_type IN ('public', 'shop')),
  shop_id INTEGER REFERENCES shops(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
  amount_cents INTEGER NOT NULL CHECK (amount_cents > 0 AND amount_cents <= 9000000000000000),
  paid_cents INTEGER NOT NULL DEFAULT 0 CHECK (paid_cents >= 0 AND paid_cents <= 9000000000000000),
  note TEXT NOT NULL DEFAULT '',
  is_void INTEGER NOT NULL DEFAULT 0 CHECK (is_void IN (0, 1)),
  created_at_utc TEXT NOT NULL,
  updated_at_utc TEXT NOT NULL,
  CHECK (paid_cents <= amount_cents),
  CHECK ((scope_type = 'public' AND shop_id IS NULL) OR (scope_type = 'shop' AND shop_id IS NOT NULL))
);

CREATE TABLE supplier_opening_debt_payments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  opening_debt_id INTEGER NOT NULL REFERENCES supplier_opening_debts(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
  cash_bill_id INTEGER NOT NULL UNIQUE REFERENCES cash_bills(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
  amount_cents INTEGER NOT NULL CHECK (amount_cents > 0 AND amount_cents <= 9000000000000000),
  is_void INTEGER NOT NULL DEFAULT 0 CHECK (is_void IN (0, 1)),
  created_at_utc TEXT NOT NULL
);

CREATE TABLE problem_resales (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  business_date TEXT NOT NULL,
  scope_type TEXT NOT NULL CHECK (scope_type IN ('public', 'shop')),
  shop_id INTEGER REFERENCES shops(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
  description TEXT NOT NULL,
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  income_cents INTEGER NOT NULL CHECK (income_cents > 0 AND income_cents <= 9000000000000000),
  income_cash_bill_id INTEGER NOT NULL UNIQUE REFERENCES cash_bills(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
  buyer_id INTEGER NOT NULL REFERENCES parties(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
  channel_id INTEGER NOT NULL REFERENCES resale_channels(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
  issue_note TEXT NOT NULL,
  is_void INTEGER NOT NULL DEFAULT 0 CHECK (is_void IN (0, 1)),
  created_at_utc TEXT NOT NULL,
  updated_at_utc TEXT NOT NULL,
  CHECK ((scope_type = 'public' AND shop_id IS NULL) OR (scope_type = 'shop' AND shop_id IS NOT NULL))
);

CREATE TABLE problem_resale_fees (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  resale_id INTEGER NOT NULL REFERENCES problem_resales(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
  cash_bill_id INTEGER NOT NULL UNIQUE REFERENCES cash_bills(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
  category_id INTEGER NOT NULL REFERENCES categories(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
  account_id INTEGER NOT NULL REFERENCES account_labels(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
  amount_cents INTEGER NOT NULL CHECK (amount_cents > 0 AND amount_cents <= 9000000000000000),
  created_at_utc TEXT NOT NULL
);

CREATE TABLE courier_accounts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE,
  is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
  created_at_utc TEXT NOT NULL,
  updated_at_utc TEXT NOT NULL
);

CREATE TABLE courier_events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  courier_account_id INTEGER NOT NULL REFERENCES courier_accounts(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
  business_date TEXT NOT NULL,
  event_type TEXT NOT NULL CHECK (event_type IN ('opening', 'topUp', 'consume', 'refund')),
  amount_cents INTEGER NOT NULL CHECK (amount_cents >= 0 AND amount_cents <= 9000000000000000),
  cash_bill_id INTEGER UNIQUE REFERENCES cash_bills(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
  balance_after_cents INTEGER NOT NULL CHECK (balance_after_cents >= 0 AND balance_after_cents <= 9000000000000000),
  note TEXT NOT NULL DEFAULT '',
  is_void INTEGER NOT NULL DEFAULT 0 CHECK (is_void IN (0, 1)),
  created_at_utc TEXT NOT NULL,
  updated_at_utc TEXT NOT NULL,
  CHECK ((event_type IN ('topUp', 'refund') AND cash_bill_id IS NOT NULL) OR (event_type IN ('opening', 'consume') AND cash_bill_id IS NULL))
);

CREATE TABLE audit_logs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  entity_type TEXT NOT NULL,
  entity_id INTEGER NOT NULL,
  action TEXT NOT NULL,
  reason TEXT NOT NULL DEFAULT '',
  snapshot_json TEXT NOT NULL,
  created_at_utc TEXT NOT NULL
);

PRAGMA user_version = 1;
```

## Task 1: Pure domain contracts and calculations

**Files:**
- Create: `lib/core/domain/local_date.dart`
- Modify: `lib/core/domain/money.dart`
- Create: `lib/features/catalog/domain/catalog_models.dart`
- Create: `lib/features/catalog/domain/catalog_repository.dart`
- Create: `lib/features/ledger/domain/ledger_models.dart`
- Create: `lib/features/ledger/domain/ledger_repository.dart`
- Create: `lib/features/dashboard/domain/dashboard_snapshots.dart`
- Create: `lib/features/dashboard/domain/dashboard_repository.dart`
- Test: `test/core/domain/local_date_test.dart`
- Test: `test/core/domain/money_product_test.dart`
- Test: `test/features/ledger/domain/ledger_domain_test.dart`

**Interfaces:**
- Consumes: existing `Money.fromCents(int)`, `Money.parsePositive(String)`, `Money.zero`, `Money.add(Money)`, `Money.format()`.
- Produces: every type and method in the Shared domain contract above.

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
    expect(
      () => Money.checkedProduct(quantity: 1000000000, unitPrice: Money.fromCents(9000000000000000)),
      throwsFormatException,
    );
  });

  test('sums money in Dart without SQL integer overflow', () {
    expect(Money.sumCents([1, 2, -3]).cents, 0);
    expect(() => Money.sumCents([9000000000000000, 1]), throwsFormatException);
  });
}
```

Run: `"$FLUTTER_SDK/bin/flutter" test test/core/domain/money_product_test.dart`
Expected: FAIL because `checkedProduct` and `sumCents` do not exist.

- [ ] **Step 3: Add the minimal domain code.**

```dart
final class LocalDate implements Comparable<LocalDate> {
  const LocalDate._(this.value);
  final String value;

  factory LocalDate.parse(String input) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(input);
    if (match == null) throw const FormatException('日期必须是YYYY-MM-DD');
    final year = int.parse(match[1]!);
    final month = int.parse(match[2]!);
    final day = int.parse(match[3]!);
    final maxDay = switch (month) {
      1 || 3 || 5 || 7 || 8 || 10 || 12 => 31,
      4 || 6 || 9 || 11 => 30,
      2 => _isLeapYear(year) ? 29 : 28,
      _ => 0,
    };
    if (day < 1 || day > maxDay) throw const FormatException('日期不存在');
    return LocalDate._(input);
  }

  factory LocalDate.todayLocal(DateTime now) {
    final local = now.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return LocalDate._('${local.year}-${two(local.month)}-${two(local.day)}');
  }

  @override
  int compareTo(LocalDate other) => value.compareTo(other.value);

  static bool _isLeapYear(int year) => year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);
}
```

Add to `Money` without changing existing callers:

```dart
static Money checkedProduct({required int quantity, required Money unitPrice}) {
  if (quantity <= 0) throw const FormatException('数量必须大于零');
  final value = BigInt.from(quantity) * BigInt.from(unitPrice.cents);
  if (value <= BigInt.zero || value > BigInt.from(maxCents)) {
    throw const FormatException('金额超出允许范围');
  }
  return Money._(value.toInt());
}

static Money sumCents(Iterable<int> centsValues) {
  var total = BigInt.zero;
  for (final cents in centsValues) {
    total += BigInt.from(cents);
  }
  if (total < BigInt.from(-maxCents) || total > BigInt.from(maxCents)) {
    throw const FormatException('金额超出允许范围');
  }
  return Money._(total.toInt());
}
```

- [ ] **Step 4: Add the domain model and repository contract files exactly as shown in Shared domain contract.** Keep constructors immutable and do not import Flutter, sqflite, provider, HTTP or native plugins in any `domain` folder.

- [ ] **Step 5: Write repository contract compile tests.**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finances_pro/core/domain/local_date.dart';
import 'package:personal_finances_pro/core/domain/money.dart';
import 'package:personal_finances_pro/features/catalog/domain/catalog_models.dart';
import 'package:personal_finances_pro/features/ledger/domain/ledger_models.dart';

void main() {
  test('cash bill draft preserves business origin inputs without category text matching', () {
    final draft = CashBillDraft(
      businessDate: LocalDate.parse('2026-10-14'),
      direction: CashDirection.expense,
      amount: Money.parsePositive('12.34'),
      scope: const BusinessScope.public(),
      categoryId: 1,
      accountId: 2,
      note: '包装袋',
    );
    expect(draft.amount.cents, 1234);
    expect(draft.scope.type, BusinessScopeType.public);
  });
}
```

Run: `"$FLUTTER_SDK/bin/flutter" test test/core/domain/local_date_test.dart test/core/domain/money_product_test.dart test/features/ledger/domain/ledger_domain_test.dart`
Expected: PASS after implementation.

- [ ] **Step 6: Run the domain boundary gate.**

Run: `"$FLUTTER_SDK/bin/dart" run tool/check_domain_boundaries.dart`
Expected: PASS with new domain folders included by the existing `lib` scan.

- [ ] **Step 7: Commit Task 1.**

```bash
git add lib/core/domain/money.dart lib/core/domain/local_date.dart lib/features/catalog/domain lib/features/ledger/domain lib/features/dashboard/domain test/core/domain test/features/ledger/domain
git commit -m "feat: define local ledger domain contract"
```

## Task 2: SQLite schema, privacy gate, catalog and cash storage

**Files:**
- Modify: `pubspec.yaml`, `pubspec.lock`
- Create: `lib/core/data/ledger_privacy.dart`
- Create: `lib/core/data/ledger_database.dart`
- Create: `lib/core/data/ledger_schema.dart`
- Create: `lib/core/data/sqlite_statement.dart`
- Create: `lib/features/catalog/data/sqlite_catalog_repository.dart`
- Create: `lib/features/ledger/data/sqlite_ledger_repository.dart`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Create: `android/app/src/main/res/xml/backup_rules.xml`
- Create: `android/app/src/main/res/xml/data_extraction_rules.xml`
- Modify: `ios/Runner/AppDelegate.swift`
- Test: `test/core/data/ledger_privacy_test.dart`
- Test: `test/core/data/ledger_schema_test.dart`
- Test: `test/core/data/backup_exclusion_static_test.dart`
- Test: `test/features/catalog/data/sqlite_catalog_repository_test.dart`
- Test: `test/features/ledger/data/sqlite_cash_bill_repository_test.dart`

**Interfaces:**
- Consumes: Task 1 domain contracts.
- Produces: `LedgerDatabase.open({required LedgerPrivacy privacy, String? databasePathOverride})`, `LedgerDatabase.close()`, `LedgerDatabase.database`, `SqliteCatalogRepository`, `SqliteLedgerRepository` generic cash methods and catalog methods.

- [ ] **Step 1: Add pinned libraries.**

```sh
"$FLUTTER_SDK/bin/flutter" pub add sqflite:2.4.2 path:1.9.1
"$FLUTTER_SDK/bin/flutter" pub add --dev sqflite_common_ffi:2.3.5
"$FLUTTER_SDK/bin/flutter" pub get
```

Expected: `pubspec.lock` resolves with Dart SDK `3.7.2`; if pub rejects a version, stop and record the resolver error instead of changing versions without approval.

- [ ] **Step 2: Write privacy gate tests.**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finances_pro/core/data/ledger_database.dart';
import 'package:personal_finances_pro/core/data/ledger_privacy.dart';

final class FakePrivacy implements LedgerPrivacy {
  FakePrivacy(this.result);
  final bool result;
  @override
  Future<bool> prepareLedgerStorage() async => result;
}

void main() {
  test('database open is blocked when backup exclusion fails', () async {
    final db = LedgerDatabase();
    await expectLater(
      db.open(privacy: FakePrivacy(false), databasePathOverride: ':memory:'),
      throwsA(isA<LedgerPrivacyException>()),
    );
  });
}
```

Run: `"$FLUTTER_SDK/bin/flutter" test test/core/data/ledger_privacy_test.dart`
Expected: FAIL because data files do not exist.

- [ ] **Step 3: Implement the privacy interface and database open gate.**

```dart
abstract interface class LedgerPrivacy {
  Future<bool> prepareLedgerStorage();
}

final class LedgerPrivacyException implements Exception {
  const LedgerPrivacyException(this.message);
  final String message;
  @override
  String toString() => message;
}
```

`LedgerDatabase.open` must call `prepareLedgerStorage()` before `openDatabase`. It must throw `LedgerPrivacyException('无法确认账本已排除系统自动备份')` on `false` and must not create, delete or reset a database in that path.

- [ ] **Step 4: Write actual SQL reopen tests.**

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finances_pro/core/data/ledger_database.dart';
import 'package:personal_finances_pro/core/data/ledger_privacy.dart';
import 'package:personal_finances_pro/core/domain/local_date.dart';
import 'package:personal_finances_pro/core/domain/money.dart';
import 'package:personal_finances_pro/features/catalog/data/sqlite_catalog_repository.dart';
import 'package:personal_finances_pro/features/catalog/domain/catalog_models.dart';
import 'package:personal_finances_pro/features/ledger/data/sqlite_ledger_repository.dart';
import 'package:personal_finances_pro/features/ledger/domain/ledger_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

final class OkPrivacy implements LedgerPrivacy {
  @override
  Future<bool> prepareLedgerStorage() async => true;
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('catalog and cash bill persist after close and reopen', () async {
    final dir = await Directory.systemTemp.createTemp('ledger-sql-');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/ledger.db';

    final first = LedgerDatabase();
    await first.open(privacy: OkPrivacy(), databasePathOverride: path);
    final catalog = SqliteCatalogRepository(first.database);
    await catalog.ensureDefaultCatalogs();
    final account = await catalog.createAccountLabel(name: '微信');
    final category = await catalog.createCategory(name: '包装采购', direction: CashDirection.expense);
    final ledger = SqliteLedgerRepository(first.database);
    await ledger.createCashBill(CashBillDraft(
      businessDate: LocalDate.parse('2026-10-14'),
      direction: CashDirection.expense,
      amount: Money.parsePositive('18.50'),
      scope: const BusinessScope.public(),
      categoryId: category.id,
      accountId: account.id,
      note: '纸箱',
    ));
    await first.close();

    final reopened = LedgerDatabase();
    await reopened.open(privacy: OkPrivacy(), databasePathOverride: path);
    final bills = await SqliteLedgerRepository(reopened.database).listCashBills(const CashBillFilter());
    expect(bills.single.amount.cents, 1850);
    expect(bills.single.businessOrigin, CategoryBusinessOrigin.ordinary);
    await reopened.close();
  });
}
```

Run: `"$FLUTTER_SDK/bin/flutter" test test/core/data/ledger_schema_test.dart test/features/ledger/data/sqlite_cash_bill_repository_test.dart`
Expected: FAIL before schema/repositories exist.

- [ ] **Step 5: Implement `LedgerSchema.createV1` with the schema block above.** `LedgerDatabase` must use:

```dart
await openDatabase(
  path,
  version: 1,
  onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
  onCreate: (db, version) async => LedgerSchema.createV1(db),
);
```

For test-only `databasePathOverride == ':memory:'`, use in-memory open from sqflite; for file paths use the provided path. Production path uses `getDatabasesPath()` + `path.join(directory, 'personal_finances_ledger.db')` after privacy succeeds.

- [ ] **Step 6: Implement catalog defaults without fake business data.** `ensureDefaultCatalogs()` inserts only these system rows when absent:

```dart
const defaultAccountLabels = ['现金', '银行卡', '微信', '支付宝'];
const defaultExpenseCategories = ['厂家付款', '采购退款调整', '包装配件', '快递充值', '快递退款', '问题件费用', '其他经营支出'];
const defaultIncomeCategories = ['厂家退款回收', '问题件二次销售', '其他经营收入'];
const defaultResaleChannels = ['线下转卖', '闲置平台', '其他渠道'];
```

Map system business origins during insertion:

```dart
{
  '厂家付款': CategoryBusinessOrigin.purchasePayment,
  '采购退款调整': CategoryBusinessOrigin.supplierRefund,
  '快递充值': CategoryBusinessOrigin.courierTopUp,
  '快递退款': CategoryBusinessOrigin.courierRefund,
  '问题件费用': CategoryBusinessOrigin.resaleFee,
  '厂家退款回收': CategoryBusinessOrigin.supplierRefund,
  '问题件二次销售': CategoryBusinessOrigin.resaleIncome,
}
```

Rows not in the map use `ordinary`. No shops, suppliers, buyers, couriers or cash bills are inserted by defaults.

- [ ] **Step 7: Implement generic cash methods with linked-bill protections.** `createCashBill` writes `source='manual'`, `business_origin` from the category row, and `linked_type/linked_id` null. `updateCashBill`, `voidCashBill` and `restoreCashBill` must reject any row where `source <> 'manual'` with `StateError('关联账单只能在所属业务中修改')`. `listCashBills` excludes void rows by default and filters by date/scope/category/party/note.

- [ ] **Step 8: Write category rename classification regression.**

```dart
test('renaming a category does not change business classification', () async {
  final category = await catalog.createCategory(name: '其它收入', direction: CashDirection.income);
  await ledger.createCashBill(CashBillDraft(
    businessDate: LocalDate.parse('2026-10-14'),
    direction: CashDirection.income,
    amount: Money.parsePositive('30'),
    scope: const BusinessScope.public(),
    categoryId: category.id,
    accountId: account.id,
  ));
  await catalog.renameCategory(id: category.id, name: '问题件二次销售');
  final bill = (await ledger.listCashBills(const CashBillFilter())).single;
  expect(bill.businessOrigin, CategoryBusinessOrigin.ordinary);
});
```

Run: `"$FLUTTER_SDK/bin/flutter" test test/features/ledger/data/sqlite_cash_bill_repository_test.dart`
Expected: PASS after origin is stored on the bill.

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
    <cloud-backup>
        <exclude domain="database" path="." />
        <exclude domain="file" path="ledger" />
    </cloud-backup>
    <device-transfer>
        <exclude domain="database" path="." />
        <exclude domain="file" path="ledger" />
    </device-transfer>
</data-extraction-rules>
```

Add iOS MethodChannel in `AppDelegate.swift` named `dev.nedhuohuo.personalfinancespro/ledger_privacy` with method `prepareLedgerDirectory`. It creates `Application Support/ledger`, sets `URLResourceKey.isExcludedFromBackupKey` to `true`, reads the value back, and returns `true` only when the value is true. Dart `MethodChannelLedgerPrivacy` implements `LedgerPrivacy` and returns false on channel exceptions.

Static test:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('android backup exclusion is declared', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains('android:allowBackup="false"'));
    expect(manifest, contains('android:dataExtractionRules="@xml/data_extraction_rules"'));
    expect(File('android/app/src/main/res/xml/backup_rules.xml').readAsStringSync(), contains('<exclude domain="database" path="." />'));
  });

  test('ios backup exclusion channel is registered', () {
    final source = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    expect(source, contains('dev.nedhuohuo.personalfinancespro/ledger_privacy'));
    expect(source, contains('isExcludedFromBackupKey'));
  });
}
```

Run: `"$FLUTTER_SDK/bin/flutter" test test/core/data/backup_exclusion_static_test.dart`
Expected: PASS. This proves source configuration, not real-device backup behavior.

- [ ] **Step 10: Run Task 2 checks.**

```sh
"$FLUTTER_SDK/bin/dart" format --output=none --set-exit-if-changed lib test tool
"$FLUTTER_SDK/bin/dart" run tool/check_domain_boundaries.dart
"$FLUTTER_SDK/bin/flutter" test test/core/data test/features/catalog/data test/features/ledger/data/sqlite_cash_bill_repository_test.dart
```

Expected: PASS.

- [ ] **Step 11: Commit Task 2.**

```bash
git add pubspec.yaml pubspec.lock lib/core/data lib/features/catalog/data lib/features/ledger/data android/app/src/main/AndroidManifest.xml android/app/src/main/res/xml ios/Runner/AppDelegate.swift test/core/data test/features/catalog/data test/features/ledger/data/sqlite_cash_bill_repository_test.dart
git commit -m "feat: add sqlite ledger storage foundation"
```

## Task 3: Business transactional repository

**Files:**
- Modify: `lib/features/ledger/data/sqlite_ledger_repository.dart`
- Create or extend: `test/features/ledger/data/sqlite_business_transaction_test.dart`
- Create or extend: `test/features/dashboard/data/sqlite_dashboard_repository_test.dart`
- Create: `lib/features/dashboard/data/sqlite_dashboard_repository.dart`

**Interfaces:**
- Consumes: Task 2 repositories and schema.
- Produces: all non-generic methods in `LedgerRepository`; `SqliteDashboardRepository` implementing `DashboardRepository`.

- [ ] **Step 1: Write procurement partial-payment invariant tests.**

```dart
test('purchase creation with initial payment writes one linked cash expense atomically', () async {
  final purchaseId = await ledger.createPurchase(
    PurchaseDraft(
      supplierId: supplier.id,
      scope: const BusinessScope.public(),
      businessDate: LocalDate.parse('2026-10-14'),
      items: [PurchaseItemDraft(description: '发夹', quantity: 2, unitPrice: Money.parsePositive('10'))],
      supplierFreight: Money.parsePositive('3'),
    ),
    initialPayment: PurchasePaymentDraft(
      businessDate: LocalDate.parse('2026-10-14'),
      amount: Money.parsePositive('8'),
      accountId: account.id,
    ),
  );
  expect(purchaseId, greaterThan(0));
  final bills = await ledger.listCashBills(const CashBillFilter());
  expect(bills.single.amount.cents, 800);
  expect(bills.single.source, CashBillSource.purchasePayment);
  expect(bills.single.direction, CashDirection.expense);
});

test('overpayment rolls back purchase payment cash bill', () async {
  final purchaseId = await createPurchaseTotal2300();
  await expectLater(
    ledger.recordPurchasePayment(
      purchaseId: purchaseId,
      payment: PurchasePaymentDraft(
        businessDate: LocalDate.parse('2026-10-15'),
        amount: Money.parsePositive('24'),
        accountId: account.id,
      ),
    ),
    throwsA(isA<StateError>()),
  );
  final bills = await ledger.listCashBills(const CashBillFilter());
  expect(bills, isEmpty);
});
```

Run: `"$FLUTTER_SDK/bin/flutter" test test/features/ledger/data/sqlite_business_transaction_test.dart`
Expected: FAIL before methods are complete.

- [ ] **Step 2: Implement purchase creation and payment.** Compute item totals with `Money.checkedProduct`, sum in Dart with `Money.sumCents`, insert purchase/items/payment/cash bill/audit in one `transaction`. Reject zero items, non-supplier parties, inactive referenced catalog rows and overpayment. Set linked cash bill source `purchasePayment`, origin `purchasePayment`, linked type `purchasePayment`, linked id to the `purchase_payments.id` after inserting the payment row; update the bill's linked id inside the same transaction.

- [ ] **Step 3: Write unpaid waiver and paid refund tests.**

```dart
test('unpaid waiver reduces payable without cash income', () async {
  final purchaseId = await createPurchaseTotal2300();
  await ledger.adjustPurchase(PurchaseAdjustmentDraft(
    purchaseId: purchaseId,
    kind: PurchaseAdjustmentKind.unpaidWaiver,
    amount: Money.parsePositive('5'),
    reason: '少发货',
  ));
  expect(await cashBillCount(), 0);
  final detail = await dashboard.loadLedgerDetailSnapshot(
    startDate: LocalDate.parse('2026-10-01'),
    endDate: LocalDate.parse('2026-10-31'),
  );
  expect(detail.purchasePayable.cents, 1800);
});

test('paid refund reduces effective payable and writes linked cash income atomically', () async {
  final purchaseId = await createPurchaseTotal2300(initialPaid: '20');
  await ledger.adjustPurchase(PurchaseAdjustmentDraft(
    purchaseId: purchaseId,
    kind: PurchaseAdjustmentKind.paidRefund,
    amount: Money.parsePositive('7'),
    reason: '退回已付款',
    businessDate: LocalDate.parse('2026-10-16'),
    accountId: account.id,
  ));
  final bills = await ledger.listCashBills(const CashBillFilter());
  expect(bills.where((bill) => bill.direction == CashDirection.income).single.businessOrigin, CategoryBusinessOrigin.supplierRefund);
  final detail = await dashboard.loadLedgerDetailSnapshot(
    startDate: LocalDate.parse('2026-10-01'),
    endDate: LocalDate.parse('2026-10-31'),
  );
  expect(detail.purchasePaidNet.cents, 1300);
  expect(detail.purchasePayable.cents, 300);
});
```

Expected: PASS after implementation. Paid refund requires `businessDate` and `accountId`; unpaid waiver rejects them only if they would imply cash.

- [ ] **Step 4: Implement opening debt and payment.** Creating opening debt inserts no cash bill. Paying it updates `supplier_opening_debts.paid_cents`, inserts an expense cash bill with origin `openingDebtPayment`, inserts `supplier_opening_debt_payments`, audits both rows, and rejects overpayment in the same transaction.

- [ ] **Step 5: Write problem resale atomic fee tests.**

```dart
test('problem resale stores gross income and independent fee expense atomically', () async {
  await ledger.createProblemResale(ProblemResaleDraft(
    scope: const BusinessScope.public(),
    businessDate: LocalDate.parse('2026-10-17'),
    description: '退回有瑕疵发夹',
    quantity: 1,
    incomeAmount: Money.parsePositive('30'),
    incomeAccountId: incomeAccount.id,
    buyerId: buyer.id,
    channelId: channel.id,
    issueNote: '包装破损',
    fees: [ProblemResaleFeeDraft(categoryId: feeCategory.id, accountId: feeAccount.id, amount: Money.parsePositive('4'))],
  ));
  final bills = await ledger.listCashBills(const CashBillFilter());
  expect(bills.map((bill) => bill.direction), containsAll([CashDirection.income, CashDirection.expense]));
  expect(bills.firstWhere((bill) => bill.businessOrigin == CategoryBusinessOrigin.resaleIncome).amount.cents, 3000);
});

test('invalid resale fee category rolls back income bill', () async {
  await expectLater(createResaleWithMissingFeeCategory(), throwsA(isA<StateError>()));
  expect(await cashBillCount(), 0);
});
```

Implement `createProblemResale` so income and every fee use independent account IDs supplied by the user. Never infer fee account from income account.

- [ ] **Step 6: Write courier history invariant tests.**

```dart
test('courier consume changes recorded balance without cash expense', () async {
  final courierId = await ledger.createCourierAccount(CourierAccountDraft(
    name: '顺丰',
    openingBalance: Money.parsePositive('20'),
    businessDate: LocalDate.parse('2026-10-01'),
  ));
  await ledger.recordCourierTopUp(
    courierAccountId: courierId,
    businessDate: LocalDate.parse('2026-10-02'),
    amount: Money.parsePositive('50'),
    accountId: account.id,
    note: '充值',
  );
  await ledger.recordCourierConsume(
    courierAccountId: courierId,
    businessDate: LocalDate.parse('2026-10-03'),
    amount: Money.parsePositive('12'),
    note: '寄件扣费',
  );
  final bills = await ledger.listCashBills(const CashBillFilter());
  expect(bills.length, 1);
  expect(bills.single.businessOrigin, CategoryBusinessOrigin.courierTopUp);
});

test('voiding old courier topup is rejected when later balance would go negative', () async {
  final topUpEventId = await createCourierTopUpThenConsumeAll();
  await expectLater(
    ledger.voidCourierEvent(eventId: topUpEventId, reason: '冲正'),
    throwsA(isA<StateError>()),
  );
});
```

Implement courier balance recalculation ordered by `(business_date, id)`. On insert or void, recompute later active events in the same transaction; reject the operation if any balance becomes negative. Top-up and refund create linked cash bills; opening and consume do not.

- [ ] **Step 7: Implement status changes and linked bill guards.** Generic cash void/restore remains blocked for linked rows. Owning methods void linked rows and audit once per business operation. `voidPurchaseWithoutPayments` only succeeds when no active payment or paid refund exists. `voidProblemResale` voids income and fees together. Restore methods are limited to generic manual cash bills and courier events in this stage; complex restore can be achieved by entering explicit reverse/adjustment flows already listed.

- [ ] **Step 8: Implement dashboard repository without SQLite money SUM.** Fetch `amount_cents` rows and call `Money.sumCents`. Month cash expense includes active cash expense bills in the period, including linked purchase/courier/resale fees; supplier payable is current total effective purchase/debt minus paid net and ignores month truncation; resale income uses `business_origin='resaleIncome'`; ledger detail snapshot exposes cash totals, procurement totals, resale net and courier recorded balance.

- [ ] **Step 9: Add dashboard category-rename and overflow regressions.**

```dart
test('dashboard resale total uses stored business origin not renamed category text', () async {
  await createResaleIncome();
  await catalog.renameCategory(id: resaleIncomeCategory.id, name: '普通收入');
  final snapshot = await dashboard.loadDashboardSnapshot(
    monthStart: LocalDate.parse('2026-10-01'),
    monthEnd: LocalDate.parse('2026-10-31'),
  );
  expect(snapshot.monthResaleIncome.cents, 3000);
});

test('dashboard aggregation rejects overflow in Dart before returning a fake total', () async {
  await insertManualExpenseCents(9000000000000000);
  await insertManualExpenseCents(1);
  await expectLater(
    dashboard.loadDashboardSnapshot(
      monthStart: LocalDate.parse('2026-10-01'),
      monthEnd: LocalDate.parse('2026-10-31'),
    ),
    throwsFormatException,
  );
});
```

- [ ] **Step 10: Run Task 3 checks.**

```sh
"$FLUTTER_SDK/bin/dart" format --output=none --set-exit-if-changed lib test tool
"$FLUTTER_SDK/bin/dart" run tool/check_domain_boundaries.dart
"$FLUTTER_SDK/bin/flutter" test test/features/ledger/data/sqlite_business_transaction_test.dart test/features/dashboard/data/sqlite_dashboard_repository_test.dart
```

Expected: PASS.

- [ ] **Step 11: Commit Task 3.**

```bash
git add lib/features/ledger/data/sqlite_ledger_repository.dart lib/features/dashboard/data/sqlite_dashboard_repository.dart test/features/ledger/data/sqlite_business_transaction_test.dart test/features/dashboard/data/sqlite_dashboard_repository_test.dart
git commit -m "feat: add ledger business transactions"
```

## Task 4: Provider bootstrap, basic manual cash/catalog UI and real snapshots

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
- Test: `test/app/app_bootstrap_test.dart`
- Test: `test/app/navigation_test.dart`
- Test: `test/features/catalog/presentation/catalog_view_model_test.dart`
- Test: `test/features/ledger/presentation/ledger_view_model_test.dart`
- Test: `test/features/dashboard/presentation/dashboard_view_model_test.dart`

**Interfaces:**
- Consumes: Task 2/3 repositories.
- Produces: `AppDependencies.open()`, `DashboardViewModel.reload()`, `CashLedgerViewModel`, `CatalogViewModel`, real cash bill create/edit/void/restore UI.

- [ ] **Step 1: Write bootstrap privacy failure widget test.**

```dart
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finances_pro/app/app.dart';
import 'package:personal_finances_pro/app/app_dependencies.dart';

final class FailingDependencies implements AppDependenciesFactory {
  @override
  Future<AppDependencies> open() => Future<AppDependencies>.error(Exception('无法确认账本已排除系统自动备份'));
}

void main() {
  testWidgets('privacy setup failure blocks ledger pages with clear error', (tester) async {
    await tester.pumpWidget(ShopLedgerApp(dependenciesFactory: FailingDependencies()));
    await tester.pumpAndSettle();
    expect(find.textContaining('无法确认账本已排除系统自动备份'), findsOneWidget);
    expect(find.text('还没有账目'), findsNothing);
  });
}
```

Expected: FAIL until app accepts an injectable dependency factory.

- [ ] **Step 2: Implement dependency bootstrap.**

```dart
abstract interface class AppDependenciesFactory {
  Future<AppDependencies> open();
}

final class AppDependencies {
  AppDependencies({required this.catalogRepository, required this.ledgerRepository, required this.dashboardRepository, required this.close});
  final CatalogRepository catalogRepository;
  final LedgerRepository ledgerRepository;
  final DashboardRepository dashboardRepository;
  final Future<void> Function() close;
}
```

`ShopLedgerApp` default factory opens `LedgerDatabase` with `MethodChannelLedgerPrivacy`, runs `ensureDefaultCatalogs()`, then provides repositories/ViewModels. On open failure, show a Cupertino page with the exact error and no fake empty ledger. Dispose closes the database.

- [ ] **Step 3: Write ViewModel commit/refresh failure tests.**

```dart
test('cash view model does not report success when refresh fails after commit', () async {
  final repo = FakeLedgerRepository(commitSucceeds: true, refreshThrows: true);
  final vm = CashLedgerViewModel(ledgerRepository: repo, catalogRepository: fakeCatalog);
  await vm.saveCashBill(validDraft);
  expect(vm.lastSaveCommitted, isTrue);
  expect(vm.errorMessage, contains('已保存，但刷新失败'));
  expect(vm.isSaving, isFalse);
});

test('failed validation keeps user input and prevents duplicate saves', () async {
  final vm = CashLedgerViewModel(ledgerRepository: fakeLedger, catalogRepository: fakeCatalog);
  vm.amountText = '18.005';
  await vm.saveFromForm();
  expect(vm.amountText, '18.005');
  expect(vm.errorMessage, contains('金额最多两位小数'));
  expect(fakeLedger.createCashBillCalls, 0);
});
```

Implement `isSaving` guard, input preservation on validation failure, and `lastSaveCommitted` to distinguish committed-save refresh failure from failed commit.

- [ ] **Step 4: Implement Dashboard page real empty and non-empty cards.** It calls `DashboardViewModel.reload()` on first build and after save notifications. Empty DB displays zeros with stage copy that says no records yet, not placeholder incapability. Cards: `本月实付支出`, `当前厂家待付款`, `本月问题件回收`, recent bills. Never label cash net as profit.

- [ ] **Step 5: Implement Ledger page list/filter/detail entry.** Cash tab lists active cash bills with date, direction, amount, scope and note. Filter controls: start/end date, shop/public, category, party, note search, include void. Generic edit/void/restore buttons appear only for `source == CashBillSource.manual`; linked rows show owning-business copy.

- [ ] **Step 6: Implement basic cash bill form.** Required fields: date default `LocalDate.todayLocal(DateTime.now())`, income/expense, amount text parsed by `Money.parsePositive`, public/shop selector, category, account, optional party, note. Date input uses Cupertino text field and strict `YYYY-MM-DD` validation. Save button disabled while saving; after commit, route returns to list and triggers reload. Failed save keeps fields.

- [ ] **Step 7: Implement catalog settings pages.** Settings rows open shop/account/party/category/resale-channel pages. Each page supports create, rename and deactivate. Deactivation remains available for referenced rows because history keeps IDs; physical delete is absent from UI and repository. Party page includes kind picker for supplier/buyer/courier/other.

- [ ] **Step 8: Update navigation tests.** Replace stale placeholder expectations with persisted empty-state expectations:

```dart
expect(find.text('本月实付支出'), findsOneWidget);
expect(find.text('0.00'), findsWidgets);
await tapTab(tester, '账本');
expect(find.text('新增现金账'), findsOneWidget);
await tapTab(tester, 'AI记账');
expect(find.text('AI功能尚未接入'), findsOneWidget);
expect(tester.widget<CupertinoButton>(find.byKey(const ValueKey('ai-send-button'))).onPressed, isNull);
```

Keep existing width 320/390/430, text scale 1.5, top/bottom safe-area and keyboard tests. Add coverage that form save buttons remain visible at width 320 with keyboard open.

- [ ] **Step 9: Run Task 4 checks.**

```sh
"$FLUTTER_SDK/bin/dart" format --output=none --set-exit-if-changed lib test tool
"$FLUTTER_SDK/bin/flutter" analyze
"$FLUTTER_SDK/bin/flutter" test test/app test/features/catalog/presentation test/features/ledger/presentation/ledger_view_model_test.dart test/features/dashboard/presentation
```

Expected: PASS.

- [ ] **Step 10: Commit Task 4.**

```bash
git add lib/app lib/features/catalog/presentation lib/features/ledger/presentation lib/features/dashboard/presentation test/app test/features/catalog/presentation test/features/ledger/presentation/ledger_view_model_test.dart test/features/dashboard/presentation
git commit -m "feat: connect ledger shell to persisted data"
```

## Task 5: Manual procurement, resale, courier and detail/status UI

**Files:**
- Modify: `lib/app/app.dart`
- Modify: `lib/app/presentation/ledger_page.dart`
- Create: `lib/features/ledger/presentation/procurement_pages.dart`
- Create: `lib/features/ledger/presentation/problem_resale_pages.dart`
- Create: `lib/features/ledger/presentation/courier_pages.dart`
- Create: `lib/features/ledger/presentation/ledger_detail_pages.dart`
- Modify: `lib/features/ledger/presentation/ledger_view_models.dart`
- Test: `test/features/ledger/presentation/manual_flow_widget_test.dart`
- Extend: `test/app/navigation_test.dart`

**Interfaces:**
- Consumes: Task 3 business repository methods and Task 4 dependency setup.
- Produces: reachable native Cupertino manual flows for purchases/payments/refunds/opening debt/problem resale/courier/detail snapshots.

- [ ] **Step 1: Add routes under the existing shell.**

Routes remain in one `GoRouter`:

```dart
GoRoute(path: '/ledger/cash/new', builder: (_, __) => const CashBillFormPage()),
GoRoute(path: '/ledger/purchases/new', builder: (_, __) => const PurchaseFormPage()),
GoRoute(path: '/ledger/purchases/:id/payment', builder: (context, state) => PurchasePaymentPage(purchaseId: int.parse(state.pathParameters['id']!))),
GoRoute(path: '/ledger/purchases/:id/adjust', builder: (context, state) => PurchaseAdjustmentPage(purchaseId: int.parse(state.pathParameters['id']!))),
GoRoute(path: '/ledger/opening-debts/new', builder: (_, __) => const SupplierOpeningDebtPage()),
GoRoute(path: '/ledger/resales/new', builder: (_, __) => const ProblemResaleFormPage()),
GoRoute(path: '/ledger/courier/accounts/new', builder: (_, __) => const CourierAccountFormPage()),
GoRoute(path: '/ledger/courier/:id/topup', builder: (context, state) => CourierTopUpPage(courierAccountId: int.parse(state.pathParameters['id']!))),
GoRoute(path: '/ledger/courier/:id/consume', builder: (context, state) => CourierConsumePage(courierAccountId: int.parse(state.pathParameters['id']!))),
GoRoute(path: '/ledger/courier/:id/refund', builder: (context, state) => CourierRefundPage(courierAccountId: int.parse(state.pathParameters['id']!))),
GoRoute(path: '/ledger/detail', builder: (_, __) => const LedgerDetailPage()),
```

- [ ] **Step 2: Write procurement form widget tests.**

```dart
testWidgets('purchase form keeps input on overpayment error and disables duplicate save', (tester) async {
  await pumpLedgerAppWithFakes(tester, ledger: FakeLedgerRepository(overpaymentError: true));
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

Implement purchase page with supplier, public/shop, date, dynamic item rows, supplier freight, optional initial payment account/amount, note. It displays computed payable using domain money and explains that unpaid purchase is not a cash expense.

- [ ] **Step 3: Implement purchase status pages.** Purchase detail shows original amount, effective amount, paid net and payable. Payment page records partial payments and rejects overpayment. Adjustment page has two explicit modes: `减少未付货款` for unpaid waiver and `退回已付货款` for paid refund with account/date. Void purchase button appears only when no active payment/refund exists; otherwise copy says to use refund/adjustment flows.

- [ ] **Step 4: Write problem resale fee account widget test.**

```dart
testWidgets('problem resale requires independent fee account and saves gross income', (tester) async {
  final fake = FakeLedgerRepository();
  await pumpLedgerAppWithFakes(tester, ledger: fake);
  await tester.tap(find.text('问题件二次销售'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const ValueKey('resale-income-amount')), '30');
  await tester.enterText(find.byKey(const ValueKey('resale-fee-amount-0')), '4');
  await tester.tap(find.byKey(const ValueKey('resale-save-button')));
  await tester.pumpAndSettle();
  expect(fake.lastProblemResale!.incomeAmount.cents, 3000);
  expect(fake.lastProblemResale!.fees.single.amount.cents, 400);
  expect(fake.lastProblemResale!.fees.single.accountId, isNot(fake.lastProblemResale!.incomeAccountId));
});
```

Implement problem resale page with original shop/public selector, date, description, quantity, gross income, income account, buyer, channel, issue note and one or more fee rows. Fee account is a required field per row and never prefilled from income account unless the user actively selects it.

- [ ] **Step 5: Implement courier pages.** Courier account page creates account with opening balance and date. Top-up page creates cash expense plus balance increase. Consume page reduces recorded balance and shows copy `不产生第二笔现金支出`. Refund page reduces recorded balance and creates cash income. History list shows opening/top-up/consume/refund and rejects void actions when repository returns negative-balance errors.

- [ ] **Step 6: Implement ledger detail snapshot page.** Page shows selected period cash income, cash expense, cash net with note `不含平台主要收入，不代表利润或亏损`, purchase effective amount, paid net, payable, problem resale income/fees/net recovery, courier top-up/consume/recorded balance. Use dashboard repository; no SQL in presentation.

- [ ] **Step 7: Add width/keyboard widget checks for new forms.** For width 320, 390 and 430 with text scale 1.5, open purchase, resale and courier consume pages, focus last input, set keyboard inset 300, and assert final save button rect bottom is `<= logicalHeight - keyboard` after scrolling.

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
- Consumes: all previous tasks.
- Produces: reviewer-ready proof that local ledger works offline, tests use real SQL for storage, native backup-exclusion source is checked, and docs do not claim excluded stages.

- [ ] **Step 1: Write an end-to-end local SQL integration test.**

```dart
test('offline local ledger flow persists and snapshots use business links', () async {
  final env = await openTempLedger();
  await env.catalog.ensureDefaultCatalogs();
  final shop = await env.catalog.createShop(name: '一店');
  final supplier = await env.catalog.createParty(name: '厂家A', kind: PartyKind.supplier);
  final buyer = await env.catalog.createParty(name: '买家B', kind: PartyKind.buyer);
  final account = await env.catalog.createAccountLabel(name: '测试账户');
  final channel = (await env.catalog.listResaleChannels()).first;

  await env.ledger.createPurchase(
    PurchaseDraft(
      supplierId: supplier.id,
      scope: BusinessScope.shop(shop.id),
      businessDate: LocalDate.parse('2026-10-14'),
      items: [PurchaseItemDraft(description: '发夹', quantity: 2, unitPrice: Money.parsePositive('10'))],
      supplierFreight: Money.parsePositive('3'),
    ),
    initialPayment: PurchasePaymentDraft(
      businessDate: LocalDate.parse('2026-10-14'),
      amount: Money.parsePositive('8'),
      accountId: account.id,
    ),
  );

  await env.ledger.createProblemResale(ProblemResaleDraft(
    scope: BusinessScope.shop(shop.id),
    businessDate: LocalDate.parse('2026-10-15'),
    description: '问题件',
    quantity: 1,
    incomeAmount: Money.parsePositive('30'),
    incomeAccountId: account.id,
    buyerId: buyer.id,
    channelId: channel.id,
    issueNote: '破损',
    fees: [],
  ));

  await env.closeAndReopen();
  final snapshot = await env.dashboard.loadDashboardSnapshot(
    monthStart: LocalDate.parse('2026-10-01'),
    monthEnd: LocalDate.parse('2026-10-31'),
    scope: BusinessScope.shop(shop.id),
  );
  expect(snapshot.monthCashExpense.cents, 800);
  expect(snapshot.supplierPayable.cents, 1500);
  expect(snapshot.monthResaleIncome.cents, 3000);
});
```

Expected: PASS after previous tasks.

- [ ] **Step 2: Add CI commands for storage tests.** Keep the existing workflow, with no credentials. Ensure it runs:

```yaml
- run: flutter pub get
- run: dart format --output=none --set-exit-if-changed lib test tool
- run: dart run tool/check_domain_boundaries.dart
- run: flutter analyze
- run: flutter test
```

The existing Android debug build remains main-branch only. Do not add publish, signing, license acceptance or global SDK changes.

- [ ] **Step 3: Update README stage status.** Mark local SQLite ledger, catalog, manual cash bills, procurement/payment/refund, problem resale, courier prepaid and snapshot totals as implemented after this stage. Keep CSV, full JSON backup/restore, real AI, native device backup proof and store publishing marked outside this stage. Document the pinned library versions and test command examples using `$FLUTTER_SDK` only.

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

## Self-review checklist for this plan

- Spec coverage: covers foundation-compatible local SQLite storage, catalog create/rename/deactivate, public/shop scope, account labels, ordinary cash CRUD/void/restore/filter/audit, procurement purchase/payment/opening debt/refund invariants, problem resale income and fee atomicity, courier prepaid balance history, dashboard/detail snapshot totals and reachable Cupertino manual flows. Excludes CSV/report subsystem, full JSON backup/restore and real AI as required by this stage.
- Interface consistency: repository signatures in the shared contract are consumed by data, dashboard and UI tasks without alternate names. Linked cash sources/business origins are stable enum values and are stored on cash rows so category rename cannot change statistics.
- Placeholder scan: task steps use exact file paths, method names, schema, tests and commands; no task relies on vague filler text.
- Ownership: Task 1 owns domain files; Task 2 owns schema/privacy/catalog/generic cash; Task 3 owns transactional business rules and snapshots; Task 4 owns bootstrap/basic UI; Task 5 owns complex manual UI; Task 6 owns integration/docs/CI.
- Residual concerns: real Android/iOS backup-exclusion behavior still needs device validation after local tooling and licenses allow it; this plan includes static/channel checks and the required write-blocking gate but does not claim device proof.
