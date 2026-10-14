import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finances_pro/core/domain/local_date.dart';
import 'package:personal_finances_pro/core/domain/money.dart';
import 'package:personal_finances_pro/features/catalog/domain/catalog_models.dart';
import 'package:personal_finances_pro/features/ledger/domain/ledger_models.dart';

import '../../../support/sqlite_ledger_test_harness.dart';

void main() {
  test(
    'ordinary cash with resale-named system category is excluded from resale totals',
    () async {
      final env = await SqliteLedgerTestHarness.open();
      addTearDown(env.close);
      final account = await env.createAccount('测试账户B');
      final resaleCategory =
          (await env.catalog.listCategories(
            direction: CashDirection.income,
            role: CategoryRole.resaleIncome,
          )).single;

      await env.cashBills.createCashBill(
        CashBillDraft(
          businessDate: LocalDate.parse('2026-10-14'),
          direction: CashDirection.income,
          amount: Money.parsePositive('30'),
          scope: const BusinessScope.public(),
          categoryId: resaleCategory.id,
          accountId: account.id,
        ),
      );

      final bills = await env.cashBills.listCashBills(const CashBillFilter());
      expect(bills.single.businessOrigin, BusinessOrigin.ordinary);
    },
  );

  test(
    'create rollback keeps cash row and audit out when aggregate cap is exceeded',
    () async {
      final env = await SqliteLedgerTestHarness.open();
      addTearDown(env.close);
      await env.seedManualExpenseCents(Money.maxCents);
      final account = await env.createAccount('测试账户D');
      final category = await env.createCategory(
        name: '测试支出D',
        direction: CashDirection.expense,
      );

      await expectLater(
        env.cashBills.createCashBill(
          CashBillDraft(
            businessDate: LocalDate.parse('2026-10-14'),
            direction: CashDirection.expense,
            amount: Money.fromCents(1),
            scope: const BusinessScope.public(),
            categoryId: category.id,
            accountId: account.id,
          ),
        ),
        throwsA(isA<FormatException>()),
      );

      expect(await env.cashBillCount(), 1);
      expect(await env.auditLogCount(), 1);
    },
  );

  test(
    'update may keep inactive historical refs but rejects changed inactive refs',
    () async {
      final env = await SqliteLedgerTestHarness.open();
      addTearDown(env.close);
      final account = await env.createAccount('测试账户E');
      final category = await env.createCategory(
        name: '测试支出E',
        direction: CashDirection.expense,
      );
      final inactiveCategory = await env.createCategory(
        name: '测试支出E停用',
        direction: CashDirection.expense,
      );
      final bill = await env.cashBills.createCashBill(
        CashBillDraft(
          businessDate: LocalDate.parse('2026-10-14'),
          direction: CashDirection.expense,
          amount: Money.parsePositive('10'),
          scope: const BusinessScope.public(),
          categoryId: category.id,
          accountId: account.id,
        ),
      );
      await env.catalog.deactivateCategory(category.id);
      await env.catalog.deactivateCategory(inactiveCategory.id);

      final updated = await env.cashBills.updateCashBill(
        id: bill.id,
        draft: CashBillDraft(
          businessDate: LocalDate.parse('2026-10-15'),
          direction: CashDirection.expense,
          amount: Money.parsePositive('11'),
          scope: const BusinessScope.public(),
          categoryId: category.id,
          accountId: account.id,
        ),
      );
      expect(updated.categoryId, category.id);

      await expectLater(
        env.cashBills.updateCashBill(
          id: bill.id,
          draft: CashBillDraft(
            businessDate: LocalDate.parse('2026-10-15'),
            direction: CashDirection.expense,
            amount: Money.parsePositive('11'),
            scope: const BusinessScope.public(),
            categoryId: inactiveCategory.id,
            accountId: account.id,
          ),
        ),
        throwsStateError,
      );
    },
  );

  test(
    'void and restore reject linked rows through generic cash flows',
    () async {
      final env = await SqliteLedgerTestHarness.open();
      addTearDown(env.close);
      final account = await env.createAccount('测试账户F');
      final category = await env.createCategory(
        name: '测试支出F',
        direction: CashDirection.expense,
      );
      final id = await env.database.insert('cash_bills', {
        'business_date': '2026-10-14',
        'direction': 'expense',
        'amount_cents': 100,
        'scope_type': 'public',
        'shop_id': null,
        'category_id': category.id,
        'account_id': account.id,
        'party_id': null,
        'note': '',
        'entry_source': 'manual',
        'business_origin': 'purchasePayment',
        'linked_type': 'purchasePayment',
        'linked_id': 1,
        'is_void': 0,
        'created_at_utc': '2026-10-14T00:00:00.000Z',
        'updated_at_utc': '2026-10-14T00:00:00.000Z',
      });

      await expectLater(
        env.cashBills.voidCashBill(id, reason: 'x'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            '关联账单只能在所属业务中修改',
          ),
        ),
      );
      await env.database.update(
        'cash_bills',
        {'is_void': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
      await expectLater(
        env.cashBills.restoreCashBill(id, reason: 'x'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            '关联账单只能在所属业务中修改',
          ),
        ),
      );
    },
  );

  test(
    'restore rolls back when aggregate cap would be exceeded',
    () async {
      final env = await SqliteLedgerTestHarness.open();
      addTearDown(env.close);
      final account = await env.createAccount('测试账户G');
      final category = await env.createCategory(
        name: '测试支出G',
        direction: CashDirection.expense,
      );
      final bill = await env.cashBills.createCashBill(
        CashBillDraft(
          businessDate: LocalDate.parse('2026-10-14'),
          direction: CashDirection.expense,
          amount: Money.fromCents(Money.maxCents),
          scope: const BusinessScope.public(),
          categoryId: category.id,
          accountId: account.id,
        ),
      );
      await env.cashBills.voidCashBill(bill.id, reason: 'temporary');
      await env.seedManualExpenseCents(1);

      await expectLater(
        env.cashBills.restoreCashBill(bill.id, reason: 'restore'),
        throwsA(isA<FormatException>()),
      );
      final rows = await env.database.query(
        'cash_bills',
        where: 'id = ?',
        whereArgs: [bill.id],
      );
      expect(rows.single['is_void'], 1);
    },
    skip:
        Platform.isWindows
            ? 'sqlite ffi path handling differs on Windows CI'
            : false,
  );
}
