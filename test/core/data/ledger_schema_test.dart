import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finances_pro/core/domain/local_date.dart';
import 'package:personal_finances_pro/core/domain/money.dart';
import 'package:personal_finances_pro/features/catalog/domain/catalog_models.dart';
import 'package:personal_finances_pro/features/ledger/domain/ledger_models.dart';

import '../../support/sqlite_ledger_test_harness.dart';

void main() {
  test(
    'catalog and ordinary cash bill persist after close and reopen',
    () async {
      final env = await SqliteLedgerTestHarness.open();
      addTearDown(env.close);
      final account = await env.createAccount('测试账户A');
      final category = await env.createCategory(
        name: '包装采购A',
        direction: CashDirection.expense,
      );

      await env.cashBills.createCashBill(
        CashBillDraft(
          businessDate: LocalDate.parse('2026-10-14'),
          direction: CashDirection.expense,
          amount: Money.parsePositive('18.50'),
          scope: const BusinessScope.public(),
          categoryId: category.id,
          accountId: account.id,
          note: '纸箱',
        ),
      );

      await env.closeAndReopen();
      final bills = await env.cashBills.listCashBills(const CashBillFilter());
      expect(bills.single.amount.cents, 1850);
      expect(bills.single.entrySource, EntrySource.manual);
      expect(bills.single.businessOrigin, BusinessOrigin.ordinary);
      expect(bills.single.linkedId, isNull);
    },
  );
}
