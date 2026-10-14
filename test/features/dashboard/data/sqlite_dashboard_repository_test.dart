import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finances_pro/core/domain/local_date.dart';
import 'package:personal_finances_pro/core/domain/money.dart';
import 'package:personal_finances_pro/features/catalog/domain/catalog_models.dart';
import 'package:personal_finances_pro/features/ledger/domain/ledger_models.dart';

import '../../../support/sqlite_ledger_test_harness.dart';

void main() {
  test(
    'real linked resale is included after category rename and ordinary resale-named income is excluded',
    () async {
      final env = await SqliteLedgerTestHarness.open();
      addTearDown(env.close);
      await env.seedOrdinaryIncomeUsingResaleCategory(amount: '99');
      final resaleId = await env.seedProblemResale(amount: '30');
      await env.catalog.renameCategory(
        id: env.resaleIncomeCategoryId,
        name: '普通收入改名',
      );
      final snapshot = await env.dashboard.loadDashboardSnapshot(
        monthStart: LocalDate.parse('2026-10-01'),
        monthEnd: LocalDate.parse('2026-10-31'),
      );
      expect(snapshot.monthResaleIncome.cents, 3000);
      expect(
        (await env.ledger.getProblemResaleDetail(resaleId)).netRecovery.cents,
        3000,
      );
    },
  );

  test(
    'voiding and restoring resale group keeps income and fee ids and statuses together',
    () async {
      final env = await SqliteLedgerTestHarness.open();
      addTearDown(env.close);
      final resaleId = await env.seedProblemResale(amount: '30', fee: '4');
      final before = await env.ledger.getProblemResaleDetail(resaleId);
      await env.ledger.voidProblemResale(resaleId: resaleId, reason: '撤销');
      await env.ledger.restoreProblemResale(resaleId: resaleId, reason: '恢复');
      final after = await env.ledger.getProblemResaleDetail(resaleId);
      expect(after.resale.incomeCashBillId, before.resale.incomeCashBillId);
      expect(after.fees.single.cashBillId, before.fees.single.cashBillId);
    },
  );

  test(
    'shared courier wallet accepts two shops but shop detail does not claim global balance',
    () async {
      final env = await SqliteLedgerTestHarness.open();
      addTearDown(env.close);
      final shopA = await env.createShop('店A');
      final shopB = await env.createShop('店B');
      final courierId = await env.ledger.createCourierAccount(
        CourierAccountDraft(
          name: '顺丰A',
          openingBalance: Money.parsePositive('20'),
          businessDate: LocalDate.parse('2026-10-01'),
        ),
      );
      await env.ledger.recordCourierTopUp(
        env.courierTopUp(
          courierAccountId: courierId,
          scope: BusinessScope.shop(shopA.id),
          amount: '50',
        ),
      );
      await env.ledger.recordCourierConsume(
        CourierConsumeDraft(
          courierAccountId: courierId,
          scope: BusinessScope.shop(shopB.id),
          businessDate: LocalDate.parse('2026-10-03'),
          amount: Money.parsePositive('12'),
        ),
      );
      final wallet = await env.ledger.getCourierAccountDetail(courierId);
      expect(wallet.account.recordedBalance.cents, 5800);
      final shopDetail = await env.dashboard.loadLedgerDetailSnapshot(
        startDate: LocalDate.parse('2026-10-01'),
        endDate: LocalDate.parse('2026-10-31'),
        scope: BusinessScope.shop(shopA.id),
      );
      expect(shopDetail.courierTopUp.cents, 5000);
      expect(shopDetail.globalCourierRecordedBalance, isNull);
    },
  );

  test(
    'second active cash insert exceeding aggregate cap rolls back before commit',
    () async {
      final env = await SqliteLedgerTestHarness.open();
      addTearDown(env.close);
      await env.seedManualExpenseCents(9000000000000000);
      await expectLater(env.seedManualExpenseCents(1), throwsFormatException);
      final snapshot = await env.dashboard.loadDashboardSnapshot(
        monthStart: LocalDate.parse('2026-10-01'),
        monthEnd: LocalDate.parse('2026-10-31'),
      );
      expect(snapshot.monthCashExpense.cents, 9000000000000000);
      expect(await env.auditLogCount(), 1);
    },
  );
}
