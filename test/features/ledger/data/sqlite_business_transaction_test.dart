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
      final shop = await env.createShop('重开店铺');
      final scopedShop = BusinessScope.shop(shop.id);
      final supplier = await env.createParty(
        name: '重开厂家',
        kind: PartyKind.supplier,
      );
      final paymentAccount = await env.createAccount('重开付款账户');
      final paymentCategory = await env.createCategory(
        name: '重开厂家付款',
        direction: CashDirection.expense,
      );
      final refundAccount = await env.createAccount('重开退款账户');
      final purchaseId = await env.ledger.createPurchase(
        PurchaseDraft(
          supplierId: supplier.id,
          scope: scopedShop,
          businessDate: LocalDate.parse('2026-10-10'),
          items: [
            PurchaseItemDraft(
              description: '重开发夹',
              quantity: 2,
              unitPrice: Money.parsePositive('10'),
            ),
          ],
          supplierFreight: Money.parsePositive('3'),
          note: '重开采购备注',
        ),
        initialPayment: PurchasePaymentDraft(
          businessDate: LocalDate.parse('2026-10-14'),
          amount: Money.parsePositive('20'),
          accountId: paymentAccount.id,
          categoryId: paymentCategory.id,
          note: '重开付款',
        ),
      );
      await env.ledger.adjustPurchase(
        PurchaseAdjustmentDraft(
          purchaseId: purchaseId,
          kind: PurchaseAdjustmentKind.paidRefund,
          amount: Money.parsePositive('5'),
          reason: '重开退款',
          categoryId: env.resaleIncomeCategoryId,
          accountId: refundAccount.id,
          businessDate: LocalDate.parse('2026-10-11'),
        ),
      );
      final adjustmentId =
          (await env.ledger.getPurchaseDetail(
            purchaseId,
          )).adjustments.single.id;
      await env.ledger.voidPurchaseAdjustment(
        adjustmentId: adjustmentId,
        reason: '重开退款作废',
      );

      final buyer = await env.createParty(name: '重开买家', kind: PartyKind.buyer);
      final feeAccount = await env.createAccount('重开费用账户');
      final incomeAccount = await env.createAccount('重开收入账户');
      final channelId = (await env.catalog.listResaleChannels()).first.id;
      final resaleId = await env.ledger.createProblemResale(
        ProblemResaleDraft(
          scope: scopedShop,
          businessDate: LocalDate.parse('2026-10-12'),
          description: '重开问题件',
          quantity: 1,
          incomeAmount: Money.parsePositive('30'),
          incomeAccountId: incomeAccount.id,
          incomeCategoryId: env.resaleIncomeCategoryId,
          buyerId: buyer.id,
          channelId: channelId,
          issueNote: '重开问题说明',
          fees: [
            ProblemResaleFeeDraft(
              categoryId: env.unusedExpenseCategoryId,
              accountId: feeAccount.id,
              amount: Money.parsePositive('4'),
              note: '重开费用',
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
        CourierCashEventDraft(
          courierAccountId: courierId,
          scope: scopedShop,
          businessDate: LocalDate.parse('2026-10-02'),
          amount: Money.parsePositive('5'),
          accountId: paymentAccount.id,
          categoryId: paymentCategory.id,
          note: '重开充值',
        ),
      );
      final topUpId =
          (await env.ledger.getCourierAccountDetail(courierId)).events
              .singleWhere((event) => event.eventType == CourierEventType.topUp)
              .id;
      await env.ledger.voidCourierEvent(eventId: topUpId, reason: '重开充值作废');
      await env.ledger.recordCourierConsume(
        CourierConsumeDraft(
          courierAccountId: courierId,
          scope: scopedShop,
          businessDate: LocalDate.parse('2026-10-13'),
          amount: Money.parsePositive('3'),
          note: '重开消耗',
        ),
      );
      final purchaseBefore = await env.ledger.getPurchaseDetail(purchaseId);
      final resaleBefore = await env.ledger.getProblemResaleDetail(resaleId);
      final courierBefore = await env.ledger.getCourierAccountDetail(courierId);
      final cashBefore = await env.cashBills.listCashBills(
        const CashBillFilter(includeVoid: true),
      );

      await env.closeAndReopen();

      final purchaseAfter = await env.ledger.getPurchaseDetail(purchaseId);
      final resaleAfter = await env.ledger.getProblemResaleDetail(resaleId);
      final courierAfter = await env.ledger.getCourierAccountDetail(courierId);
      final cashAfter = await env.cashBills.listCashBills(
        const CashBillFilter(includeVoid: true),
      );
      final purchasePaymentCash = cashAfter.singleWhere(
        (bill) => bill.id == purchaseAfter.payments.single.cashBillId,
      );
      final purchaseRefundCash = cashAfter.singleWhere(
        (bill) => bill.id == purchaseAfter.adjustments.single.cashBillId,
      );
      final resaleIncomeCash = cashAfter.singleWhere(
        (bill) => bill.id == resaleAfter.resale.incomeCashBillId,
      );
      final resaleFeeCash = cashAfter.singleWhere(
        (bill) => bill.id == resaleAfter.fees.single.cashBillId,
      );
      final courierTopUpAfter = courierAfter.events.singleWhere(
        (event) => event.eventType == CourierEventType.topUp,
      );
      final courierConsumeAfter = courierAfter.events.singleWhere(
        (event) => event.eventType == CourierEventType.consume,
      );
      final courierTopUpCash = cashAfter.singleWhere(
        (bill) => bill.id == courierTopUpAfter.cashBillId,
      );

      expect(
        _purchaseProjection(purchaseAfter),
        _purchaseProjection(purchaseBefore),
      );
      expect(_resaleProjection(resaleAfter), _resaleProjection(resaleBefore));
      expect(
        _courierProjection(courierAfter),
        _courierProjection(courierBefore),
      );
      expect(cashAfter.map(_cashProjection), cashBefore.map(_cashProjection));

      expect(purchaseAfter.purchase.id, purchaseId);
      expect(purchaseAfter.purchase.supplierId, supplier.id);
      expect(purchaseAfter.purchase.scope.type, BusinessScopeType.shop);
      expect(purchaseAfter.purchase.scope.shopId, shop.id);
      expect(purchaseAfter.purchase.businessDate.value, '2026-10-10');
      expect(purchaseAfter.purchase.originalTotal.cents, 2300);
      expect(purchaseAfter.purchase.supplierFreight.cents, 300);
      expect(purchaseAfter.purchase.note, '重开采购备注');
      expect(purchaseAfter.purchase.isVoid, isFalse);
      expect(purchaseAfter.purchase.position.effectiveTotal.cents, 2300);
      expect(purchaseAfter.purchase.position.paidNet.cents, 2000);
      expect(purchaseAfter.purchase.position.payable.cents, 300);
      expect(purchaseAfter.items.single.description, '重开发夹');
      expect(purchaseAfter.items.single.quantity, 2);
      expect(purchaseAfter.items.single.unitPrice.cents, 1000);
      expect(purchaseAfter.items.single.lineTotal.cents, 2000);
      expect(purchaseAfter.payments.single.purchaseId, purchaseId);
      expect(purchaseAfter.payments.single.amount.cents, 2000);
      expect(purchaseAfter.payments.single.isVoid, isFalse);
      expect(purchaseAfter.adjustments.single.purchaseId, purchaseId);
      expect(
        purchaseAfter.adjustments.single.kind,
        PurchaseAdjustmentKind.paidRefund,
      );
      expect(purchaseAfter.adjustments.single.amount.cents, 500);
      expect(purchaseAfter.adjustments.single.reason, '重开退款');
      expect(purchaseAfter.adjustments.single.isVoid, isTrue);
      expect(purchasePaymentCash.businessDate.value, '2026-10-14');
      expect(purchasePaymentCash.direction, CashDirection.expense);
      expect(purchasePaymentCash.amount.cents, 2000);
      expect(purchasePaymentCash.scope.shopId, shop.id);
      expect(purchasePaymentCash.accountId, paymentAccount.id);
      expect(purchasePaymentCash.partyId, supplier.id);
      expect(
        purchasePaymentCash.businessOrigin,
        BusinessOrigin.purchasePayment,
      );
      expect(purchasePaymentCash.linkedType, LinkedBillType.purchasePayment);
      expect(purchasePaymentCash.linkedId, purchaseId);
      expect(purchasePaymentCash.isVoid, isFalse);
      expect(purchaseRefundCash.direction, CashDirection.income);
      expect(purchaseRefundCash.amount.cents, 500);
      expect(purchaseRefundCash.accountId, refundAccount.id);
      expect(purchaseRefundCash.businessOrigin, BusinessOrigin.supplierRefund);
      expect(purchaseRefundCash.linkedType, LinkedBillType.supplierRefund);
      expect(purchaseRefundCash.linkedId, purchaseId);
      expect(purchaseRefundCash.isVoid, isTrue);

      expect(resaleAfter.resale.id, resaleId);
      expect(resaleAfter.resale.scope.shopId, shop.id);
      expect(resaleAfter.resale.businessDate.value, '2026-10-12');
      expect(resaleAfter.resale.description, '重开问题件');
      expect(resaleAfter.resale.quantity, 1);
      expect(resaleAfter.resale.incomeAmount.cents, 3000);
      expect(resaleAfter.resale.buyerId, buyer.id);
      expect(resaleAfter.resale.channelId, channelId);
      expect(resaleAfter.resale.issueNote, '重开问题说明');
      expect(resaleAfter.resale.isVoid, isFalse);
      expect(resaleAfter.fees.single.categoryId, env.unusedExpenseCategoryId);
      expect(resaleAfter.fees.single.accountId, feeAccount.id);
      expect(resaleAfter.fees.single.amount.cents, 400);
      expect(resaleAfter.netRecovery.cents, 2600);
      expect(resaleIncomeCash.direction, CashDirection.income);
      expect(resaleIncomeCash.businessOrigin, BusinessOrigin.resaleIncome);
      expect(resaleIncomeCash.linkedType, LinkedBillType.problemResaleIncome);
      expect(resaleIncomeCash.linkedId, resaleId);
      expect(resaleIncomeCash.accountId, incomeAccount.id);
      expect(resaleIncomeCash.amount.cents, 3000);
      expect(resaleIncomeCash.isVoid, isFalse);
      expect(resaleFeeCash.direction, CashDirection.expense);
      expect(resaleFeeCash.businessOrigin, BusinessOrigin.resaleFee);
      expect(resaleFeeCash.linkedType, LinkedBillType.problemResaleFee);
      expect(resaleFeeCash.linkedId, resaleId);
      expect(resaleFeeCash.accountId, feeAccount.id);
      expect(resaleFeeCash.amount.cents, 400);
      expect(resaleFeeCash.isVoid, isFalse);

      expect(courierAfter.account.id, courierId);
      expect(courierAfter.account.name, '重开快递');
      expect(courierAfter.account.isActive, isTrue);
      expect(courierAfter.account.recordedBalance.cents, 1700);
      expect(courierAfter.events, hasLength(3));
      expect(courierAfter.events[0].eventType, CourierEventType.opening);
      expect(courierAfter.events[0].scope, isNull);
      expect(courierAfter.events[0].businessDate.value, '2026-10-01');
      expect(courierAfter.events[0].amount.cents, 2000);
      expect(courierAfter.events[0].cashBillId, isNull);
      expect(courierAfter.events[0].balanceAfter.cents, 2000);
      expect(courierAfter.events[0].isVoid, isFalse);
      expect(courierTopUpAfter.courierAccountId, courierId);
      expect(courierTopUpAfter.scope!.shopId, shop.id);
      expect(courierTopUpAfter.businessDate.value, '2026-10-02');
      expect(courierTopUpAfter.amount.cents, 500);
      expect(courierTopUpAfter.balanceAfter.cents, 2000);
      expect(courierTopUpAfter.note, '重开充值');
      expect(courierTopUpAfter.isVoid, isTrue);
      expect(courierTopUpCash.businessOrigin, BusinessOrigin.courierTopUp);
      expect(courierTopUpCash.linkedType, LinkedBillType.courierTopUp);
      expect(courierTopUpCash.linkedId, courierId);
      expect(courierTopUpCash.amount.cents, 500);
      expect(courierTopUpCash.scope.shopId, shop.id);
      expect(courierTopUpCash.isVoid, isTrue);
      expect(courierConsumeAfter.courierAccountId, courierId);
      expect(courierConsumeAfter.scope!.shopId, shop.id);
      expect(courierConsumeAfter.businessDate.value, '2026-10-13');
      expect(courierConsumeAfter.amount.cents, 300);
      expect(courierConsumeAfter.cashBillId, isNull);
      expect(courierConsumeAfter.balanceAfter.cents, 1700);
      expect(courierConsumeAfter.note, '重开消耗');
      expect(courierConsumeAfter.isVoid, isFalse);
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

Map<String, Object?> _purchaseProjection(PurchaseDetail detail) => {
  'purchase': {
    'id': detail.purchase.id,
    'supplierId': detail.purchase.supplierId,
    'scopeType': detail.purchase.scope.type.name,
    'shopId': detail.purchase.scope.shopId,
    'businessDate': detail.purchase.businessDate.value,
    'originalTotal': detail.purchase.originalTotal.cents,
    'supplierFreight': detail.purchase.supplierFreight.cents,
    'note': detail.purchase.note,
    'isVoid': detail.purchase.isVoid,
    'effectiveTotal': detail.purchase.position.effectiveTotal.cents,
    'paidNet': detail.purchase.position.paidNet.cents,
    'payable': detail.purchase.position.payable.cents,
  },
  'items': [
    for (final item in detail.items)
      {
        'id': item.id,
        'description': item.description,
        'quantity': item.quantity,
        'unitPrice': item.unitPrice.cents,
        'lineTotal': item.lineTotal.cents,
      },
  ],
  'payments': [
    for (final payment in detail.payments)
      {
        'id': payment.id,
        'purchaseId': payment.purchaseId,
        'cashBillId': payment.cashBillId,
        'amount': payment.amount.cents,
        'isVoid': payment.isVoid,
      },
  ],
  'adjustments': [
    for (final adjustment in detail.adjustments)
      {
        'id': adjustment.id,
        'purchaseId': adjustment.purchaseId,
        'kind': adjustment.kind.name,
        'amount': adjustment.amount.cents,
        'cashBillId': adjustment.cashBillId,
        'reason': adjustment.reason,
        'isVoid': adjustment.isVoid,
      },
  ],
};

Map<String, Object?> _resaleProjection(ProblemResaleDetail detail) => {
  'resale': {
    'id': detail.resale.id,
    'scopeType': detail.resale.scope.type.name,
    'shopId': detail.resale.scope.shopId,
    'businessDate': detail.resale.businessDate.value,
    'description': detail.resale.description,
    'quantity': detail.resale.quantity,
    'incomeAmount': detail.resale.incomeAmount.cents,
    'incomeCashBillId': detail.resale.incomeCashBillId,
    'buyerId': detail.resale.buyerId,
    'channelId': detail.resale.channelId,
    'issueNote': detail.resale.issueNote,
    'isVoid': detail.resale.isVoid,
  },
  'fees': [
    for (final fee in detail.fees)
      {
        'id': fee.id,
        'cashBillId': fee.cashBillId,
        'categoryId': fee.categoryId,
        'accountId': fee.accountId,
        'amount': fee.amount.cents,
      },
  ],
  'netRecovery': detail.netRecovery.cents,
};

Map<String, Object?> _courierProjection(CourierAccountDetail detail) => {
  'account': {
    'id': detail.account.id,
    'name': detail.account.name,
    'isActive': detail.account.isActive,
    'recordedBalance': detail.account.recordedBalance.cents,
  },
  'events': [
    for (final event in detail.events)
      {
        'id': event.id,
        'courierAccountId': event.courierAccountId,
        'scopeType': event.scope?.type.name,
        'shopId': event.scope?.shopId,
        'businessDate': event.businessDate.value,
        'eventType': event.eventType.name,
        'amount': event.amount.cents,
        'cashBillId': event.cashBillId,
        'balanceAfter': event.balanceAfter.cents,
        'note': event.note,
        'isVoid': event.isVoid,
      },
  ],
};

Map<String, Object?> _cashProjection(CashBill bill) => {
  'id': bill.id,
  'businessDate': bill.businessDate.value,
  'direction': bill.direction.name,
  'amount': bill.amount.cents,
  'scopeType': bill.scope.type.name,
  'shopId': bill.scope.shopId,
  'categoryId': bill.categoryId,
  'accountId': bill.accountId,
  'partyId': bill.partyId,
  'note': bill.note,
  'entrySource': bill.entrySource.name,
  'businessOrigin': bill.businessOrigin.name,
  'linkedType': bill.linkedType?.name,
  'linkedId': bill.linkedId,
  'isVoid': bill.isVoid,
};
