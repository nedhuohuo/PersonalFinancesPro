import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finances_pro/features/catalog/domain/catalog_models.dart';

import '../../../support/sqlite_ledger_test_harness.dart';

void main() {
  test(
    'defaults contain only generic catalogs with corrected directions',
    () async {
      final env = await SqliteLedgerTestHarness.open();
      addTearDown(env.close);

      expect(await env.catalog.listShops(), isEmpty);
      expect(await env.catalog.listParties(), isEmpty);
      expect(await env.cashBillCount(), 0);

      final accounts = await env.catalog.listAccountLabels();
      expect(accounts.map((e) => e.name), ['现金', '银行卡', '微信', '支付宝']);

      final expense = await env.catalog.listCategories(
        direction: CashDirection.expense,
      );
      expect(expense.map((e) => e.name), [
        '厂家付款',
        '包装配件',
        '快递充值',
        '问题件费用',
        '其他经营支出',
      ]);
      expect(expense.first.role, CategoryRole.purchasePayment);

      final income = await env.catalog.listCategories(
        direction: CashDirection.income,
      );
      expect(income.map((e) => e.name), [
        '厂家退款回收',
        '快递退款',
        '问题件二次销售',
        '其他经营收入',
      ]);
      expect(income.first.role, CategoryRole.supplierRefund);

      final channels = await env.catalog.listResaleChannels();
      expect(channels.map((e) => e.name), ['线下转卖', '闲置平台', '其他渠道']);
    },
  );

  test(
    'rename and deactivate keep stable ids and hide inactive rows by default',
    () async {
      final env = await SqliteLedgerTestHarness.open();
      addTearDown(env.close);
      final account = await env.createAccount('测试账户C');

      final renamed = await env.catalog.renameAccountLabel(
        id: account.id,
        name: '测试账户C-改',
      );
      await env.catalog.deactivateAccountLabel(account.id);

      expect(renamed.id, account.id);
      expect(await env.catalog.listAccountLabels(), isNot(contains(renamed)));
      final inactive = await env.catalog.listAccountLabels(
        includeInactive: true,
      );
      expect(
        inactive.where((e) => e.id == account.id).single.isActive,
        isFalse,
      );
    },
  );
}
