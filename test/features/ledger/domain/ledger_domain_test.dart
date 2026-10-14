import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finances_pro/core/domain/local_date.dart';
import 'package:personal_finances_pro/core/domain/money.dart';
import 'package:personal_finances_pro/features/catalog/domain/catalog_models.dart';
import 'package:personal_finances_pro/features/dashboard/domain/dashboard_snapshots.dart';
import 'package:personal_finances_pro/features/ledger/domain/ledger_models.dart';

void main() {
  test('draft and snapshot collections are defensively immutable', () {
    final items = [
      PurchaseItemDraft(
        description: 'goods',
        quantity: 2,
        unitPrice: Money.fromCents(300),
      ),
    ];
    final draft = PurchaseDraft(
      supplierId: 1,
      scope: const BusinessScope.public(),
      businessDate: LocalDate.parse('2026-01-01'),
      items: items,
      supplierFreight: Money.zero,
    );
    items.clear();

    expect(draft.items, hasLength(1));
    expect(() => draft.items.add(draft.items.single), throwsUnsupportedError);

    final bills = [
      CashBill(
        id: 1,
        businessDate: LocalDate.parse('2026-01-01'),
        direction: CashDirection.expense,
        amount: Money.fromCents(100),
        scope: const BusinessScope.public(),
        categoryId: 1,
        accountId: 1,
        partyId: null,
        note: '',
        entrySource: EntrySource.manual,
        businessOrigin: BusinessOrigin.ordinary,
        linkedType: null,
        linkedId: null,
        isVoid: false,
        createdAtUtc: DateTime.utc(2026),
        updatedAtUtc: DateTime.utc(2026),
      ),
    ];
    final snapshot = DashboardSnapshot(
      monthCashExpense: Money.zero,
      supplierPayable: Money.zero,
      monthResaleIncome: Money.zero,
      recentBills: bills,
    );
    bills.clear();

    expect(snapshot.recentBills, hasLength(1));
    expect(() => snapshot.recentBills.clear(), throwsUnsupportedError);
  });
}
