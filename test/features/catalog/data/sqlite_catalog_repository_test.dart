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

  test(
    'catalog names trim valid input and reject blanks before writes',
    () async {
      final env = await SqliteLedgerTestHarness.open();
      addTearDown(env.close);

      final shop = await env.catalog.createShop(name: '  测试店铺H  ');
      final account = await env.catalog.createAccountLabel(name: '  测试账户H  ');
      final party = await env.catalog.createParty(
        name: '  测试往来H  ',
        kind: PartyKind.other,
      );
      final category = await env.catalog.createCategory(
        name: '  测试分类H  ',
        direction: CashDirection.expense,
      );
      final channel = await env.catalog.createResaleChannel(name: '  测试渠道H  ');

      expect(shop.name, '测试店铺H');
      expect(account.name, '测试账户H');
      expect(party.name, '测试往来H');
      expect(category.name, '测试分类H');
      expect(channel.name, '测试渠道H');

      final countsBeforeBlankCreates = await _catalogCounts(env);
      await expectLater(
        env.catalog.createShop(name: '   '),
        throwsA(isA<FormatException>()),
      );
      await expectLater(
        env.catalog.createAccountLabel(name: ''),
        throwsA(isA<FormatException>()),
      );
      await expectLater(
        env.catalog.createParty(name: '  ', kind: PartyKind.other),
        throwsA(isA<FormatException>()),
      );
      await expectLater(
        env.catalog.createCategory(name: '  ', direction: CashDirection.income),
        throwsA(isA<FormatException>()),
      );
      await expectLater(
        env.catalog.createResaleChannel(name: '  '),
        throwsA(isA<FormatException>()),
      );
      expect(await _catalogCounts(env), countsBeforeBlankCreates);

      final renamedShop = await env.catalog.renameShop(
        id: shop.id,
        name: '  测试店铺H改  ',
      );
      final renamedAccount = await env.catalog.renameAccountLabel(
        id: account.id,
        name: '  测试账户H改  ',
      );
      final renamedParty = await env.catalog.renameParty(
        id: party.id,
        name: '  测试往来H改  ',
      );
      final renamedCategory = await env.catalog.renameCategory(
        id: category.id,
        name: '  测试分类H改  ',
      );
      final renamedChannel = await env.catalog.renameResaleChannel(
        id: channel.id,
        name: '  测试渠道H改  ',
      );
      expect(renamedShop.name, '测试店铺H改');
      expect(renamedAccount.name, '测试账户H改');
      expect(renamedParty.name, '测试往来H改');
      expect(renamedCategory.name, '测试分类H改');
      expect(renamedChannel.name, '测试渠道H改');

      final countsBeforeBlankRenames = await _catalogCounts(env);
      await expectLater(
        env.catalog.renameShop(id: shop.id, name: '  '),
        throwsA(isA<FormatException>()),
      );
      await expectLater(
        env.catalog.renameAccountLabel(id: account.id, name: '  '),
        throwsA(isA<FormatException>()),
      );
      await expectLater(
        env.catalog.renameParty(id: party.id, name: '  '),
        throwsA(isA<FormatException>()),
      );
      await expectLater(
        env.catalog.renameCategory(id: category.id, name: '  '),
        throwsA(isA<FormatException>()),
      );
      await expectLater(
        env.catalog.renameResaleChannel(id: channel.id, name: '  '),
        throwsA(isA<FormatException>()),
      );
      expect(await _catalogCounts(env), countsBeforeBlankRenames);

      expect((await env.catalog.listShops()).single.name, '测试店铺H改');
      expect(
        (await env.catalog.listAccountLabels())
            .where((e) => e.id == account.id)
            .single
            .name,
        '测试账户H改',
      );
      expect((await env.catalog.listParties()).single.name, '测试往来H改');
      expect(
        (await env.catalog.listCategories(
          includeInactive: true,
        )).where((e) => e.id == category.id).single.name,
        '测试分类H改',
      );
      expect(
        (await env.catalog.listResaleChannels())
            .where((e) => e.id == channel.id)
            .single
            .name,
        '测试渠道H改',
      );
    },
  );
}

Future<List<int>> _catalogCounts(SqliteLedgerTestHarness env) async => [
  (await env.catalog.listShops(includeInactive: true)).length,
  (await env.catalog.listAccountLabels(includeInactive: true)).length,
  (await env.catalog.listParties(includeInactive: true)).length,
  (await env.catalog.listCategories(includeInactive: true)).length,
  (await env.catalog.listResaleChannels(includeInactive: true)).length,
];
