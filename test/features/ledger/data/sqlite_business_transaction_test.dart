import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finances_pro/core/domain/local_date.dart';
import 'package:personal_finances_pro/core/domain/money.dart';
import 'package:personal_finances_pro/features/catalog/domain/catalog_models.dart';
import 'package:personal_finances_pro/features/ledger/domain/ledger_models.dart';

import '../../../support/sqlite_ledger_test_harness.dart';

void main() {
  test(
    'purchase creation with initial payment writes one linked cash expense atomically',
    () async {
      final env = await SqliteLedgerTestHarness.open();
      addTearDown(env.close);
      final supplier = await env.createParty(
        name: '厂家A',
        kind: PartyKind.supplier,
      );
      final account = await env.createAccount('测试账户C');
      final paymentCategory = await env.createCategory(
        name: '厂家付款A',
        direction: CashDirection.expense,
      );
      final purchaseId = await env.ledger.createPurchase(
        PurchaseDraft(
          supplierId: supplier.id,
          scope: const BusinessScope.public(),
          businessDate: LocalDate.parse('2026-10-14'),
          items: [
            PurchaseItemDraft(
              description: '发夹',
              quantity: 2,
              unitPrice: Money.parsePositive('10'),
            ),
          ],
          supplierFreight: Money.parsePositive('3'),
        ),
        initialPayment: PurchasePaymentDraft(
          businessDate: LocalDate.parse('2026-10-14'),
          amount: Money.parsePositive('8'),
          accountId: account.id,
          categoryId: paymentCategory.id,
        ),
      );
      final detail = await env.ledger.getPurchaseDetail(purchaseId);
      expect(detail.purchase.position.payable.cents, 1500);
      final bills = await env.cashBills.listCashBills(const CashBillFilter());
      expect(bills.single.businessOrigin, BusinessOrigin.purchasePayment);
      expect(bills.single.linkedType, LinkedBillType.purchasePayment);
    },
  );

  test('overpayment rolls back purchase payment cash bill', () async {
    final env = await SqliteLedgerTestHarness.open();
    addTearDown(env.close);
    final purchaseId = await env.seedPurchase(total: '23');
    await expectLater(
      env.ledger.recordPurchasePayment(
        purchaseId: purchaseId,
        payment: env.purchasePayment(amount: '24'),
      ),
      throwsA(isA<StateError>()),
    );
    expect(await env.cashBillCount(), 0);
  });

  test('unpaid waiver reduces payable without cash income', () async {
    final env = await SqliteLedgerTestHarness.open();
    addTearDown(env.close);
    final purchaseId = await env.seedPurchase(total: '23');
    await env.ledger.adjustPurchase(
      PurchaseAdjustmentDraft(
        purchaseId: purchaseId,
        kind: PurchaseAdjustmentKind.unpaidWaiver,
        amount: Money.parsePositive('5'),
        reason: '少发货',
        categoryId: env.unusedExpenseCategoryId,
      ),
    );
    expect(await env.cashBillCount(), 0);
    expect(
      (await env.ledger.getPurchaseDetail(
        purchaseId,
      )).purchase.position.payable.cents,
      1800,
    );
  });

  test(
    'voiding and restoring a paid refund updates linked cash status with same ids',
    () async {
      final env = await SqliteLedgerTestHarness.open();
      addTearDown(env.close);
      final purchaseId = await env.seedPurchase(total: '23', paid: '20');
      final adjustmentId = await env.seedPaidRefund(
        purchaseId: purchaseId,
        amount: '7',
      );
      final before = await env.linkedCashBillForAdjustment(adjustmentId);
      await env.ledger.voidPurchaseAdjustment(
        adjustmentId: adjustmentId,
        reason: '录错',
      );
      await env.ledger.restorePurchaseAdjustment(
        adjustmentId: adjustmentId,
        reason: '恢复',
      );
      final after = await env.linkedCashBillForAdjustment(adjustmentId);
      expect(after.id, before.id);
      expect(after.isVoid, isFalse);
    },
  );

  test(
    'opening debt payment rollback, stable restore, and reopen persistence',
    () async {
      final env = await SqliteLedgerTestHarness.open();
      addTearDown(env.close);
      final supplier = await env.createParty(
        name: '期初厂家',
        kind: PartyKind.supplier,
      );
      final debtId = await env.ledger.createSupplierOpeningDebt(
        SupplierOpeningDebtDraft(
          supplierId: supplier.id,
          scope: const BusinessScope.public(),
          businessDate: LocalDate.parse('2026-10-01'),
          amount: Money.parsePositive('15'),
        ),
      );
      expect(await env.cashBillCount(), 0);
      await expectLater(
        env.ledger.paySupplierOpeningDebt(
          openingDebtId: debtId,
          payment: env.purchasePayment(amount: '16'),
        ),
        throwsA(isA<StateError>()),
      );
      await env.ledger.paySupplierOpeningDebt(
        openingDebtId: debtId,
        payment: env.purchasePayment(amount: '10'),
      );
      final before = await env.ledger.getSupplierOpeningDebtDetail(debtId);
      await env.ledger.voidSupplierOpeningDebtPayment(
        paymentId: before.payments.single.id,
        reason: '录错',
      );
      await env.ledger.restoreSupplierOpeningDebtPayment(
        paymentId: before.payments.single.id,
        reason: '恢复',
      );
      await env.closeAndReopen();
      final after = await env.ledger.getSupplierOpeningDebtDetail(debtId);
      expect(after.debt.paid.cents, 1000);
      expect(
        after.payments.single.cashBillId,
        before.payments.single.cashBillId,
      );
    },
  );

  test(
    'voiding old courier topup is rejected when later balance would go negative',
    () async {
      final env = await SqliteLedgerTestHarness.open();
      addTearDown(env.close);
      final topUpEventId = await env.seedCourierTopUpThenConsumeAll();
      await expectLater(
        env.ledger.voidCourierEvent(eventId: topUpEventId, reason: '冲正'),
        throwsA(isA<StateError>()),
      );
    },
  );
}
