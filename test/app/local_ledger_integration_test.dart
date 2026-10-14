import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finances_pro/core/domain/local_date.dart';
import 'package:personal_finances_pro/core/domain/money.dart';
import 'package:personal_finances_pro/features/catalog/domain/catalog_models.dart';
import 'package:personal_finances_pro/features/ledger/domain/ledger_models.dart';

import '../features/ledger/presentation/manual_flow_widget_test.dart'
    show start;
import '../support/sqlite_ledger_test_harness.dart';
import '../support/widget_test_app.dart';

void main() {
  testWidgets(
    'offline SQL cross-business flow reopens with stable links, scoped cents and an owning app route',
    (tester) async {
      final env = (await tester.runAsync(SqliteLedgerTestHarness.open))!;
      addTearDown(() => tester.runAsync(env.close));
      late int purchaseId;
      late int shopId;

      await tester.runAsync(() async {
        final date = LocalDate.parse('2026-10-14');
        final startDate = LocalDate.parse('2026-10-01');
        final endDate = LocalDate.parse('2026-10-31');
        final shop = await env.createShop('集成一店');
        shopId = shop.id;
        final scope = BusinessScope.shop(shopId);
        const public = BusinessScope.public();
        final supplier = await env.createParty(
          name: '集成厂家',
          kind: PartyKind.supplier,
        );
        final buyer = await env.createParty(
          name: '集成买家',
          kind: PartyKind.buyer,
        );
        final account = await env.createAccount('集成收付款');
        final feeAccount = await env.createAccount('集成运费');
        final secondFeeAccount = await env.createAccount('集成手续费');
        final channel = (await env.catalog.listResaleChannels()).first;
        final expense = env.unusedExpenseCategoryId;
        PurchasePaymentDraft payment(String amount) => PurchasePaymentDraft(
          businessDate: date,
          amount: Money.parsePositive(amount),
          accountId: account.id,
          categoryId: expense,
        );

        // A resale-role category on ordinary cash must not identify a resale.
        await env.seedOrdinaryIncomeUsingResaleCategory(amount: '7');
        final ordinary = await env.cashBills.createCashBill(
          CashBillDraft(
            businessDate: date,
            direction: CashDirection.expense,
            amount: Money.parsePositive('1.25'),
            scope: scope,
            categoryId: expense,
            accountId: account.id,
            note: '集成普通支出',
          ),
        );
        final debtId = await env.ledger.createSupplierOpeningDebt(
          SupplierOpeningDebtDraft(
            supplierId: supplier.id,
            scope: public,
            businessDate: startDate,
            amount: Money.parsePositive('5'),
          ),
        );
        expect(await env.cashBillCount(), 2); // Opening debt is not cash.
        purchaseId = await env.ledger.createPurchase(
          PurchaseDraft(
            supplierId: supplier.id,
            scope: scope,
            businessDate: date,
            items: [
              PurchaseItemDraft(
                description: '集成发夹',
                quantity: 2,
                unitPrice: Money.parsePositive('10'),
              ),
            ],
            supplierFreight: Money.parsePositive('3'),
          ),
          initialPayment: payment('8'),
        );
        final initial = await env.dashboard.loadDashboardSnapshot(
          monthStart: startDate,
          monthEnd: endDate,
          scope: scope,
        );
        expect(
          initial.monthCashExpense.cents,
          925,
        ); // 125 + paid 800, not 2300.
        expect(initial.supplierPayable.cents, 1500);
        await env.ledger.recordPurchasePayment(
          purchaseId: purchaseId,
          payment: payment('2'),
        );
        final resaleId = await env.ledger.createProblemResale(
          ProblemResaleDraft(
            scope: scope,
            businessDate: date,
            description: '集成问题件',
            quantity: 1,
            incomeAmount: Money.parsePositive('30'),
            incomeAccountId: account.id,
            incomeCategoryId: env.resaleIncomeCategoryId,
            buyerId: buyer.id,
            channelId: channel.id,
            issueNote: '破损',
            fees: [
              ProblemResaleFeeDraft(
                categoryId: expense,
                accountId: feeAccount.id,
                amount: Money.parsePositive('4'),
              ),
              ProblemResaleFeeDraft(
                categoryId: expense,
                accountId: secondFeeAccount.id,
                amount: Money.parsePositive('1'),
              ),
            ],
          ),
        );
        final courierId = await env.ledger.createCourierAccount(
          CourierAccountDraft(
            name: '集成全局快递',
            openingBalance: Money.parsePositive('20'),
            businessDate: startDate,
          ),
        );
        expect(await env.cashBillCount(), 7); // Wallet opening is also noncash.
        await env.ledger.recordCourierTopUp(
          CourierCashEventDraft(
            courierAccountId: courierId,
            scope: scope,
            businessDate: date,
            amount: Money.parsePositive('10'),
            accountId: account.id,
            categoryId: expense,
          ),
        );
        await env.ledger.recordCourierConsume(
          CourierConsumeDraft(
            courierAccountId: courierId,
            scope: public,
            businessDate: LocalDate.parse('2026-10-15'),
            amount: Money.parsePositive('6'),
          ),
        );
        expect(
          await env.cashBillCount(),
          8,
        ); // Consume is not a second expense.
        final purchaseBefore = await env.ledger.getPurchaseDetail(purchaseId);
        final resaleBefore = await env.ledger.getProblemResaleDetail(resaleId);
        final courierBefore = await env.ledger.getCourierAccountDetail(
          courierId,
        );
        final cashBefore = await env.cashBills.listCashBills(
          const CashBillFilter(includeVoid: true),
        );
        final oldDatabase = env.database;
        final oldRepositories = (
          env.catalog,
          env.cashBills,
          env.ledger,
          env.dashboard,
        );

        await env.closeAndReopen();

        expect(oldDatabase.isOpen, isFalse);
        expect(identical(oldDatabase, env.database), isFalse);
        expect(identical(oldRepositories.$1, env.catalog), isFalse);
        expect(identical(oldRepositories.$2, env.cashBills), isFalse);
        expect(identical(oldRepositories.$3, env.ledger), isFalse);
        expect(identical(oldRepositories.$4, env.dashboard), isFalse);
        expect((await env.catalog.listShops()).single.id, shopId);
        final purchase = await env.ledger.getPurchaseDetail(purchaseId);
        final resale = await env.ledger.getProblemResaleDetail(resaleId);
        final courier = await env.ledger.getCourierAccountDetail(courierId);
        final debt = await env.ledger.getSupplierOpeningDebtDetail(debtId);
        final cash = await env.cashBills.listCashBills(
          const CashBillFilter(includeVoid: true),
        );
        expect(cash.map(_cashIdentity), cashBefore.map(_cashIdentity));
        expect(purchase.purchase.id, purchaseId);
        expect(purchase.purchase.supplierId, supplier.id);
        expect(purchase.purchase.scope.shopId, shopId);
        expect(purchase.purchase.isVoid, isFalse);
        expect(purchase.items.single.id, purchaseBefore.items.single.id);
        expect(purchase.purchase.position.payable.cents, 1300);
        expect(
          purchase.payments.map((p) => p.id),
          purchaseBefore.payments.map((p) => p.id),
        );
        for (final p in purchase.payments) {
          final bill = cash.singleWhere((b) => b.id == p.cashBillId);
          expect(p.purchaseId, purchaseId);
          expect(p.isVoid, isFalse);
          expect(bill.linkedId, purchaseId);
          expect(bill.linkedType, LinkedBillType.purchasePayment);
          expect(bill.businessOrigin, BusinessOrigin.purchasePayment);
          expect(bill.amount.cents, p.amount.cents);
        }
        expect(debt.debt.id, debtId);
        expect(debt.debt.amount.cents, 500);
        expect(debt.debt.paid.cents, 0);
        expect(debt.payments, isEmpty);
        expect(resale.resale.id, resaleId);
        expect(resale.resale.buyerId, buyer.id);
        expect(resale.resale.channelId, channel.id);
        expect(
          resale.resale.incomeCashBillId,
          resaleBefore.resale.incomeCashBillId,
        );
        expect(resale.resale.isVoid, isFalse);
        final income = cash.singleWhere(
          (b) => b.id == resale.resale.incomeCashBillId,
        );
        expect(income.linkedType, LinkedBillType.problemResaleIncome);
        expect(income.linkedId, resaleId);
        expect(income.accountId, account.id);
        expect(
          resale.fees.map((f) => f.id),
          resaleBefore.fees.map((f) => f.id),
        );
        expect(resale.fees.map((f) => f.accountId), [
          feeAccount.id,
          secondFeeAccount.id,
        ]);
        for (final f in resale.fees) {
          final bill = cash.singleWhere((b) => b.id == f.cashBillId);
          expect(bill.linkedId, resaleId);
          expect(bill.linkedType, LinkedBillType.problemResaleFee);
          expect(bill.accountId, f.accountId);
          expect(bill.amount.cents, f.amount.cents);
        }
        expect(resale.netRecovery.cents, 2500);
        expect(courier.account.id, courierId);
        expect(courier.account.recordedBalance.cents, 2400);
        expect(
          courier.events.map((e) => e.id),
          courierBefore.events.map((e) => e.id),
        );
        final topUp = courier.events.singleWhere(
          (e) => e.eventType == CourierEventType.topUp,
        );
        final consume = courier.events.singleWhere(
          (e) => e.eventType == CourierEventType.consume,
        );
        expect(topUp.scope!.shopId, shopId);
        final topUpBill = cash.singleWhere((b) => b.id == topUp.cashBillId);
        expect(topUpBill.linkedId, courierId);
        expect(topUpBill.linkedType, LinkedBillType.courierTopUp);
        expect(consume.scope!.type, BusinessScopeType.public);
        expect(consume.cashBillId, isNull);
        expect(consume.isVoid, isFalse);
        expect(
          cash.singleWhere((b) => b.id == ordinary.id).businessOrigin,
          BusinessOrigin.ordinary,
        );
        final decoy = cash.singleWhere(
          (b) =>
              b.businessOrigin == BusinessOrigin.ordinary &&
              b.direction == CashDirection.income,
        );
        expect(decoy.categoryId, env.resaleIncomeCategoryId);
        expect(decoy.linkedType, isNull);

        // Fixed fixture range: no dependency on the app's wall-clock home month.
        for (final expected in [
          (
            scope: null,
            income: 3700,
            expense: 2625,
            payable: 1800,
            resale: 3000,
            fees: 500,
            topUp: 1000,
            consume: 600,
          ),
          (
            scope: public,
            income: 700,
            expense: 0,
            payable: 500,
            resale: 0,
            fees: 0,
            topUp: 0,
            consume: 600,
          ),
          (
            scope: scope,
            income: 3000,
            expense: 2625,
            payable: 1300,
            resale: 3000,
            fees: 500,
            topUp: 1000,
            consume: 0,
          ),
        ]) {
          final home = await env.dashboard.loadDashboardSnapshot(
            monthStart: startDate,
            monthEnd: endDate,
            scope: expected.scope,
          );
          final detail = await env.dashboard.loadLedgerDetailSnapshot(
            startDate: startDate,
            endDate: endDate,
            scope: expected.scope,
          );
          expect(home.monthCashExpense.cents, expected.expense);
          expect(home.supplierPayable.cents, expected.payable);
          expect(home.monthResaleIncome.cents, expected.resale);
          expect(detail.cashIncome.cents, expected.income);
          expect(detail.cashExpense.cents, expected.expense);
          expect(detail.cashNet.cents, expected.income - expected.expense);
          expect(detail.resaleIncome.cents, expected.resale);
          expect(detail.resaleFees.cents, expected.fees);
          expect(
            detail.resaleNetRecovery.cents,
            expected.resale - expected.fees,
          );
          expect(
            detail.purchaseEffective.cents,
            expected.scope == public ? 0 : 2300,
          );
          expect(
            detail.purchasePaidNet.cents,
            expected.scope == public ? 0 : 1000,
          );
          expect(
            detail.purchasePayable.cents,
            expected.scope == public ? 0 : 1300,
          );
          expect(detail.courierTopUp.cents, expected.topUp);
          expect(detail.courierConsume.cents, expected.consume);
          expect(
            detail.globalCourierRecordedBalance?.cents,
            expected.scope == null ? 2400 : null,
          );
        }
      });

      // Only newly bound real SQL repositories enter the app after reopening.
      await start(
        tester,
        FakeAppRepositories(
          catalog: env.catalog,
          cashBills: env.cashBills,
          ledger: env.ledger,
          dashboard: env.dashboard,
        ),
        '采购 #$purchaseId · 集成厂家 · 2026-10-14 · 集成一店 · 有效 23.00 · 已付 10.00 · 待付 13.00',
      );
      expect(find.text('采购详情'), findsOneWidget);
      expect(find.text('采购 #$purchaseId'), findsOneWidget);
      expect(find.textContaining('待付 13.00'), findsOneWidget);
      expect(find.textContaining('2026-10-14 · 集成一店 · 集成厂家'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}

Object _cashIdentity(CashBill bill) => (
  bill.id,
  bill.linkedType,
  bill.linkedId,
  bill.businessOrigin,
  bill.amount.cents,
  bill.accountId,
  bill.scope.shopId,
  bill.isVoid,
);
