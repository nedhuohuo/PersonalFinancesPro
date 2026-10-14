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
    'voiding purchase payment rolls back when liability cap would be exceeded',
    () async {
      final env = await SqliteLedgerTestHarness.open();
      addTearDown(env.close);
      final supplier = await env.createParty(
        name: '满额厂家',
        kind: PartyKind.supplier,
      );
      final purchaseId = await env.ledger.createPurchase(
        PurchaseDraft(
          supplierId: supplier.id,
          scope: const BusinessScope.public(),
          businessDate: LocalDate.parse('2026-10-14'),
          items: [
            PurchaseItemDraft(
              description: '满额采购',
              quantity: 1,
              unitPrice: Money.fromCents(Money.maxCents),
            ),
          ],
          supplierFreight: Money.zero,
        ),
        initialPayment: env.purchasePayment(amount: '0.01'),
      );
      await env.ledger.createSupplierOpeningDebt(
        SupplierOpeningDebtDraft(
          supplierId: supplier.id,
          scope: const BusinessScope.public(),
          businessDate: LocalDate.parse('2026-10-14'),
          amount: Money.fromCents(1),
        ),
      );
      final before = await env.ledger.getPurchaseDetail(purchaseId);
      final paymentId = before.payments.single.id;
      final cashBillId = before.payments.single.cashBillId;
      final auditCount = await env.auditLogCount();

      await expectLater(
        env.ledger.voidPurchasePayment(paymentId: paymentId, reason: '冲正'),
        throwsFormatException,
      );

      final after = await env.ledger.getPurchaseDetail(purchaseId);
      expect(after.purchase.position.payable.cents, Money.maxCents - 1);
      expect(after.payments.single.isVoid, isFalse);
      expect(after.payments.single.cashBillId, cashBillId);
      expect(
        (await env.cashBills.listCashBills(
          const CashBillFilter(includeVoid: true),
        )).singleWhere((bill) => bill.id == cashBillId).isVoid,
        isFalse,
      );
      expect(await env.auditLogCount(), auditCount);
    },
  );

  test(
    'voiding courier consume rolls back when wallet aggregate cap would be exceeded',
    () async {
      final env = await SqliteLedgerTestHarness.open();
      addTearDown(env.close);
      final walletA = await env.ledger.createCourierAccount(
        CourierAccountDraft(
          name: '满额钱包A',
          openingBalance: Money.fromCents(Money.maxCents),
          businessDate: LocalDate.parse('2026-10-01'),
        ),
      );
      await env.ledger.recordCourierConsume(
        CourierConsumeDraft(
          courierAccountId: walletA,
          scope: const BusinessScope.public(),
          businessDate: LocalDate.parse('2026-10-02'),
          amount: Money.fromCents(1),
        ),
      );
      await env.ledger.createCourierAccount(
        CourierAccountDraft(
          name: '满额钱包B',
          openingBalance: Money.fromCents(1),
          businessDate: LocalDate.parse('2026-10-01'),
        ),
      );
      final before = await env.ledger.getCourierAccountDetail(walletA);
      final consume = before.events.singleWhere(
        (event) => event.eventType == CourierEventType.consume,
      );
      final auditCount = await env.auditLogCount();

      await expectLater(
        env.ledger.voidCourierEvent(eventId: consume.id, reason: '冲正'),
        throwsFormatException,
      );

      final after = await env.ledger.getCourierAccountDetail(walletA);
      final afterConsume = after.events.singleWhere(
        (event) => event.id == consume.id,
      );
      expect(after.account.recordedBalance.cents, Money.maxCents - 1);
      expect(afterConsume.isVoid, isFalse);
      expect(afterConsume.balanceAfter.cents, Money.maxCents - 1);
      expect(await env.auditLogCount(), auditCount);
    },
  );

  test(
    'purchase resale and courier typed details survive close and reopen',
    () async {
      final env = await SqliteLedgerTestHarness.open();
      addTearDown(env.close);
      final supplier = await env.createParty(
        name: '重开厂家',
        kind: PartyKind.supplier,
      );
      final purchaseId = await env.ledger.createPurchase(
        PurchaseDraft(
          supplierId: supplier.id,
          scope: const BusinessScope.public(),
          businessDate: LocalDate.parse('2026-10-10'),
          items: [
            PurchaseItemDraft(
              description: '重开发夹',
              quantity: 2,
              unitPrice: Money.parsePositive('10'),
            ),
          ],
          supplierFreight: Money.parsePositive('3'),
        ),
        initialPayment: env.purchasePayment(amount: '20'),
      );
      await env.ledger.adjustPurchase(
        PurchaseAdjustmentDraft(
          purchaseId: purchaseId,
          kind: PurchaseAdjustmentKind.paidRefund,
          amount: Money.parsePositive('5'),
          reason: '重开退款',
          categoryId: env.resaleIncomeCategoryId,
          accountId: (await env.createAccount('重开退款账户')).id,
          businessDate: LocalDate.parse('2026-10-11'),
        ),
      );

      final buyer = await env.createParty(name: '重开买家', kind: PartyKind.buyer);
      final feeAccount = await env.createAccount('重开费用账户');
      final incomeAccount = await env.createAccount('重开收入账户');
      final resaleId = await env.ledger.createProblemResale(
        ProblemResaleDraft(
          scope: const BusinessScope.public(),
          businessDate: LocalDate.parse('2026-10-12'),
          description: '重开问题件',
          quantity: 1,
          incomeAmount: Money.parsePositive('30'),
          incomeAccountId: incomeAccount.id,
          incomeCategoryId: env.resaleIncomeCategoryId,
          buyerId: buyer.id,
          channelId: (await env.catalog.listResaleChannels()).first.id,
          issueNote: '重开',
          fees: [
            ProblemResaleFeeDraft(
              categoryId: env.unusedExpenseCategoryId,
              accountId: feeAccount.id,
              amount: Money.parsePositive('4'),
            ),
          ],
        ),
      );
      final courierId = await env.ledger.createCourierAccount(
        CourierAccountDraft(
          name: '重开快递',
          openingBalance: Money.parsePositive('20'),
          businessDate: LocalDate.parse('2026-10-01'),
        ),
      );
      await env.ledger.recordCourierTopUp(
        env.courierTopUp(
          courierAccountId: courierId,
          scope: const BusinessScope.public(),
          amount: '5',
        ),
      );
      await env.ledger.recordCourierConsume(
        CourierConsumeDraft(
          courierAccountId: courierId,
          scope: const BusinessScope.public(),
          businessDate: LocalDate.parse('2026-10-13'),
          amount: Money.parsePositive('3'),
        ),
      );
      final purchaseBefore = await env.ledger.getPurchaseDetail(purchaseId);
      final resaleBefore = await env.ledger.getProblemResaleDetail(resaleId);
      final courierBefore = await env.ledger.getCourierAccountDetail(courierId);

      await env.closeAndReopen();

      final purchaseAfter = await env.ledger.getPurchaseDetail(purchaseId);
      final resaleAfter = await env.ledger.getProblemResaleDetail(resaleId);
      final courierAfter = await env.ledger.getCourierAccountDetail(courierId);
      expect(purchaseAfter.items.single.id, purchaseBefore.items.single.id);
      expect(
        purchaseAfter.payments.single.cashBillId,
        purchaseBefore.payments.single.cashBillId,
      );
      expect(
        purchaseAfter.adjustments.single.cashBillId,
        purchaseBefore.adjustments.single.cashBillId,
      );
      expect(purchaseAfter.purchase.position.payable.cents, 300);
      expect(
        resaleAfter.resale.incomeCashBillId,
        resaleBefore.resale.incomeCashBillId,
      );
      expect(
        resaleAfter.fees.single.cashBillId,
        resaleBefore.fees.single.cashBillId,
      );
      expect(resaleAfter.fees.single.accountId, feeAccount.id);
      expect(resaleAfter.netRecovery.cents, 2600);
      expect(courierAfter.account.recordedBalance.cents, 2200);
      expect(
        courierAfter.events.map((event) => event.id),
        courierBefore.events.map((event) => event.id),
      );
      expect(
        courierAfter.events.any(
          (event) => event.eventType == CourierEventType.consume,
        ),
        isTrue,
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
