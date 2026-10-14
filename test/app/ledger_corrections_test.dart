import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finances_pro/core/domain/local_date.dart';
import 'package:personal_finances_pro/core/domain/money.dart';
import 'package:personal_finances_pro/features/catalog/domain/catalog_models.dart';
import 'package:personal_finances_pro/features/ledger/domain/ledger_models.dart';
import 'package:personal_finances_pro/features/ledger/presentation/cash_bill_pages.dart';
import 'package:personal_finances_pro/features/ledger/presentation/ledger_view_models.dart';

import '../support/widget_test_app.dart';

Future<void> tab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byType(CupertinoTabBar),
      matching: find.text(label),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.drag(
      find
          .byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          )
          .last,
      const Offset(0, 2000),
    );
    await tester.pumpAndSettle();
  }
  await tester.scrollUntilVisible(
    finder,
    150,
    scrollable:
        find
            .byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            )
            .last,
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> choose(WidgetTester tester, String row, String choice) async {
  await tapVisible(tester, find.text(row));
  await tester.tap(find.widgetWithText(CupertinoActionSheetAction, choice));
  await tester.pumpAndSettle();
}

Finder field(String placeholder) => find.byWidgetPredicate(
  (widget) => widget is CupertinoTextField && widget.placeholder == placeholder,
);

FakeAppRepositories repositories(
  RecordingCashBillRepository cash, {
  RecordingCatalogRepository? catalog,
}) => FakeAppRepositories(
  catalog: catalog ?? RecordingCatalogRepository(),
  cashBills: cash,
  ledger: RecordingLedgerRepository(),
  dashboard: RecordingDashboardRepository(cashBills: cash),
);

CashBillDraft draft({
  int? shop,
  int? party,
  int category = 1,
  String note = '目标现金账',
}) => CashBillDraft(
  businessDate: LocalDate.parse('2026-10-14'),
  direction: CashDirection.expense,
  amount: Money.parsePositive('12.34'),
  scope: shop == null ? const BusinessScope.public() : BusinessScope.shop(shop),
  categoryId: category,
  accountId: 1,
  partyId: party,
  note: note,
);

void main() {
  testWidgets(
    'typed invalid date and overprecision remain editable and visible with validation errors',
    (tester) async {
      final cash = RecordingCashBillRepository();
      await pumpLedgerAppWithRepositories(tester, repositories(cash));
      await tab(tester, '账本');
      await tester.tap(find.text('新增现金账'));
      await tester.pumpAndSettle();
      await tester.enterText(field('日期 YYYY-MM-DD'), '2026-02-30');
      await tester.enterText(field('金额'), '18.001');
      await tapVisible(tester, find.text('保存'));
      expect(tester.takeException(), isNull);
      expect(cash.createCashBillCalls, 0);
      await tester.drag(find.byType(ListView).last, const Offset(0, 650));
      await tester.pumpAndSettle();
      expect(find.text('提示'), findsOneWidget);
      expect(
        tester
            .widget<CupertinoTextField>(field('日期 YYYY-MM-DD'))
            .controller!
            .text,
        '2026-02-30',
      );
      await tester.enterText(field('日期 YYYY-MM-DD'), '2026-10-14');
      await tapVisible(tester, find.text('保存'));
      expect(tester.takeException(), isNull);
      expect(cash.createCashBillCalls, 0);
      await tester.drag(find.byType(ListView).last, const Offset(0, 650));
      await tester.pumpAndSettle();
      expect(
        tester.widget<CupertinoTextField>(field('金额')).controller!.text,
        '18.001',
      );
      await tester.enterText(field('金额'), '18.00');
      await tapVisible(tester, find.text('保存'));
      expect(cash.createCashBillCalls, 1);
    },
  );

  testWidgets(
    'committed form direction change leaves save disabled and controller selection owned',
    (tester) async {
      final cash = RecordingCashBillRepository();
      await pumpLedgerAppWithRepositories(tester, repositories(cash));
      await tab(tester, '账本');
      await tester.tap(find.text('新增现金账'));
      await tester.pumpAndSettle();
      await tester.enterText(field('金额'), '10.00');
      final controller =
          tester.widget<CupertinoTextField>(field('金额')).controller!;
      controller.selection = const TextSelection.collapsed(offset: 2);
      await tester.tap(find.text('收入'));
      await tester.pumpAndSettle();
      expect(
        identical(
          controller,
          tester.widget<CupertinoTextField>(field('金额')).controller,
        ),
        isTrue,
      );
      expect(controller.selection.baseOffset, 2);
      await choose(tester, '分类：未选择', '测试收入');
      cash.refreshThrows = true;
      await tapVisible(tester, find.text('保存'));
      expect(cash.createCashBillCalls, 1);
      await tester.drag(find.byType(ListView).last, const Offset(0, 700));
      await tester.pumpAndSettle();
      expect(find.textContaining('已保存，但刷新失败'), findsOneWidget);
      await tester.tap(find.text('支出'));
      await tester.pumpAndSettle();
      await tester.enterText(field('金额'), '20.00');
      await tapVisible(tester, find.text('保存'));
      expect(
        tester
            .widget<CupertinoButton>(
              find.byKey(const ValueKey('cash-save-button')),
            )
            .onPressed,
        isNull,
      );
      expect(cash.createCashBillCalls, 1);
      cash.refreshThrows = false;
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('新增现金账'));
      await tester.enterText(field('金额'), '20.00');
      await tapVisible(tester, find.text('保存'));
      expect(cash.createCashBillCalls, 2);
    },
  );

  testWidgets(
    'reachable filters select all public explicit shop category party and retained date note',
    (tester) async {
      final cash = RecordingCashBillRepository();
      await cash.createCashBill(draft(shop: 1, party: 1));
      await cash.createCashBill(draft(note: '公共现金账'));
      final catalog = RecordingCatalogRepository(
        parties: [
          const Party(
            id: 1,
            name: '历史客户',
            kind: PartyKind.buyer,
            isActive: false,
          ),
        ],
      );
      await pumpLedgerAppWithRepositories(
        tester,
        repositories(cash, catalog: catalog),
      );
      await tab(tester, '账本');
      await choose(tester, '店铺筛选：全部', '公共');
      await tapVisible(tester, find.text('应用筛选'));
      expect(cash.lastFilter!.scope!.shopId, isNull);
      expect(find.text('公共现金账'), findsOneWidget);
      expect(find.text('目标现金账'), findsNothing);
      await choose(tester, '店铺筛选：公共', '测试店铺');
      await choose(tester, '分类筛选：全部', '测试支出');
      await choose(tester, '往来方筛选：全部', '历史客户');
      await tester.enterText(field('开始日期'), '2026-10-14');
      await tester.enterText(field('结束日期'), '2026-10-14');
      await tester.enterText(field('备注包含'), '目标');
      await tapVisible(tester, find.text('应用筛选'));
      expect(cash.lastFilter!.scope!.shopId, 1);
      expect(cash.lastFilter!.categoryId, 1);
      expect(cash.lastFilter!.partyId, 1);
      expect(cash.lastFilter!.noteQuery, '目标');
      expect(cash.lastFilter!.startDate!.value, '2026-10-14');
      expect(cash.lastFilter!.endDate!.value, '2026-10-14');
      expect(find.text('目标现金账'), findsOneWidget);
      expect(find.text('公共现金账'), findsNothing);
      await choose(tester, '店铺筛选：测试店铺', '全部');
      await choose(tester, '分类筛选：测试支出', '全部');
      await choose(tester, '往来方筛选：历史客户', '全部');
      await tester.enterText(field('开始日期'), '');
      await tester.enterText(field('结束日期'), '');
      await tester.enterText(field('备注包含'), '');
      await tapVisible(tester, find.text('应用筛选'));
      expect(cash.lastFilter!.scope, isNull);
      expect(cash.lastFilter!.categoryId, isNull);
      expect(cash.lastFilter!.partyId, isNull);
      expect(find.text('公共现金账'), findsOneWidget);
    },
  );

  testWidgets(
    'actual detail edit void includeVoid same ID restore and tab-return dashboard coherence',
    (tester) async {
      final cash = RecordingCashBillRepository();
      final bill = await cash.createCashBill(draft());
      await pumpLedgerAppWithRepositories(tester, repositories(cash));
      expect(find.text('12.34'), findsOneWidget);
      await tab(tester, '账本');
      await tapVisible(tester, find.text('目标现金账'));
      await tapVisible(tester, find.text('编辑'));
      await tester.enterText(field('金额'), '20.00');
      await tapVisible(tester, field('备注'));
      await tester.enterText(field('备注'), '编辑后现金账');
      await tapVisible(tester, find.text('保存'));
      expect(cash.updateCashBillCalls, 1);
      expect(find.textContaining('支出 20.00'), findsOneWidget);
      await tapVisible(tester, find.text('作废'));
      await tester.enterText(
        find.descendant(
          of: find.byType(CupertinoAlertDialog),
          matching: find.byType(CupertinoTextField),
        ),
        '作废测试',
      );
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();
      expect(cash.voidCashBillCalls, 1);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tab(tester, '首页');
      expect(find.text('0.00'), findsNWidgets(3));
      await tab(tester, '账本');
      await tapVisible(tester, find.text('包含作废'));
      await tapVisible(tester, find.text('编辑后现金账'));
      expect(find.text('未找到现金账'), findsNothing);
      await tapVisible(tester, find.text('恢复'));
      await tester.enterText(
        find.descendant(
          of: find.byType(CupertinoAlertDialog),
          matching: find.byType(CupertinoTextField),
        ),
        '恢复测试',
      );
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();
      expect(cash.restoreCashBillCalls, 1);
      expect(
        (await cash.listCashBills(const CashBillFilter())).single.id,
        bill.id,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tab(tester, '首页');
      expect(find.text('20.00'), findsOneWidget);
      expect(find.textContaining('支出 20.00'), findsOneWidget);
    },
  );

  testWidgets(
    'inactive historical edit labels displayed but new assignments active only',
    (tester) async {
      final cash = RecordingCashBillRepository();
      await cash.createCashBill(draft(shop: 1, party: 1));
      final catalog = RecordingCatalogRepository(
        shops: [
          const Shop(id: 1, name: '旧店铺', isActive: false),
          const Shop(id: 2, name: '新店铺', isActive: true),
        ],
        accounts: [
          const AccountLabel(id: 1, name: '旧账户', isActive: false),
          const AccountLabel(id: 2, name: '新账户', isActive: true),
        ],
        categories: [
          const Category(
            id: 1,
            name: '旧分类',
            direction: CashDirection.expense,
            role: CategoryRole.ordinary,
            isSystem: false,
            isActive: false,
          ),
          const Category(
            id: 2,
            name: '新分类',
            direction: CashDirection.expense,
            role: CategoryRole.ordinary,
            isSystem: false,
            isActive: true,
          ),
        ],
        parties: [
          const Party(
            id: 1,
            name: '旧客户',
            kind: PartyKind.buyer,
            isActive: false,
          ),
          const Party(
            id: 2,
            name: '新客户',
            kind: PartyKind.buyer,
            isActive: true,
          ),
        ],
      );
      await pumpLedgerAppWithRepositories(
        tester,
        repositories(cash, catalog: catalog),
      );
      await tab(tester, '账本');
      await tapVisible(tester, find.text('目标现金账'));
      await tapVisible(tester, find.text('编辑'));
      for (final label in ['店铺范围：旧店铺', '分类：旧分类', '账户：旧账户', '往来方：旧客户']) {
        await tapVisible(tester, find.text(label));
        expect(
          find.widgetWithText(
            CupertinoActionSheetAction,
            label.split('：').last,
          ),
          findsNothing,
        );
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
      }
      await tapVisible(tester, find.text('保存'));
      final saved = (await cash.listCashBills(const CashBillFilter())).single;
      expect(
        (saved.scope.shopId, saved.categoryId, saved.accountId, saved.partyId),
        (1, 1, 1, 1),
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('新增现金账'));
      await choose(tester, '店铺范围：公共', '新店铺');
      expect(find.text('分类：新分类'), findsOneWidget);
      expect(find.text('账户：新账户'), findsOneWidget);
      await choose(tester, '往来方：无', '新客户');
      await tester.enterText(field('金额'), '1.00');
      await tapVisible(tester, find.text('保存'));
      expect(
        (await cash.listCashBills(const CashBillFilter())).last.scope.shopId,
        2,
      );
    },
  );

  testWidgets(
    'status dialog keeps blank or failed reason and disables multiple submissions',
    (tester) async {
      final cash = RecordingCashBillRepository();
      final bill = await cash.createCashBill(draft());
      await cash.voidCashBill(bill.id, reason: 'seed');
      await pumpLedgerAppWithRepositories(tester, repositories(cash));
      await tab(tester, '账本');
      await tapVisible(tester, find.text('包含作废'));
      await tapVisible(tester, find.text('目标现金账'));
      await tapVisible(tester, find.text('恢复'));
      final reason = find.descendant(
        of: find.byType(CupertinoAlertDialog),
        matching: find.byType(CupertinoTextField),
      );
      await tester.enterText(reason, '   ');
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      expect(find.text('请填写恢复原因'), findsWidgets);
      expect(cash.restoreCashBillCalls, 0);
      await tester.enterText(reason, '保留恢复原因');
      final gate = Completer<void>();
      cash.statusGate = gate.future;
      cash.statusError = Exception('恢复超限');
      await tester.tap(find.text('确认'));
      await tester.pump();
      await tester.tap(find.text('确认'));
      await tester.pump();
      expect(cash.restoreCashBillCalls, 1);
      gate.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      expect(find.textContaining('恢复超限'), findsWidgets);
      expect(find.text('保留恢复原因'), findsOneWidget);
      cash.statusError = null;
      cash.statusGate = null;
      cash.refreshThrows = true;
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsNothing);
      expect(find.textContaining('已恢复，但刷新失败'), findsOneWidget);
      expect(
        tester
            .widget<CupertinoButton>(find.widgetWithText(CupertinoButton, '恢复'))
            .onPressed,
        isNull,
      );
      cash.refreshThrows = false;
      await tapVisible(tester, find.text('刷新'));
      expect(find.text('作废'), findsOneWidget);
    },
  );

  testWidgets(
    'settings rename deactivate returns ledger with current historical label',
    (tester) async {
      final cash = RecordingCashBillRepository();
      await cash.createCashBill(draft(shop: 1));
      await pumpLedgerAppWithRepositories(tester, repositories(cash));
      await tab(tester, '账本');
      await tab(tester, '设置');
      await tapVisible(tester, find.text('基础资料：店铺'));
      await tapVisible(tester, find.text('重命名'));
      await tester.enterText(find.byType(CupertinoTextField), '改名店铺');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('停用'));
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tab(tester, '账本');
      await tester.scrollUntilVisible(
        find.textContaining('改名店铺'),
        150,
        scrollable:
            find
                .byWidgetPredicate(
                  (widget) =>
                      widget is Scrollable &&
                      widget.axisDirection == AxisDirection.down,
                )
                .last,
      );
      expect(find.textContaining('改名店铺'), findsOneWidget);
      await tapVisible(tester, find.text('目标现金账'));
      expect(find.textContaining('改名店铺'), findsOneWidget);
      await tapVisible(tester, find.text('编辑'));
      expect(find.text('店铺范围：改名店铺'), findsOneWidget);
    },
  );
  testWidgets('home returns with newly created total and recent row', (
    tester,
  ) async {
    final cash = RecordingCashBillRepository();
    await pumpLedgerAppWithRepositories(tester, repositories(cash));
    await tab(tester, '账本');
    await tester.tap(find.text('新增现金账'));
    await tester.pumpAndSettle();
    await tester.enterText(field('金额'), '12.34');
    await tapVisible(tester, find.text('保存'));
    await tab(tester, '首页');
    expect(find.text('12.34'), findsOneWidget);
    expect(find.textContaining('支出 12.34'), findsOneWidget);
  });

  testWidgets('isolated historical form displays saved inactive references', (
    tester,
  ) async {
    final cash = RecordingCashBillRepository();
    final bill = await cash.createCashBill(draft(shop: 1, party: 1));
    final catalog = RecordingCatalogRepository(
      shops: [const Shop(id: 1, name: '旧店铺', isActive: false)],
      accounts: [const AccountLabel(id: 1, name: '旧账户', isActive: false)],
      categories: [
        const Category(
          id: 1,
          name: '旧分类',
          direction: CashDirection.expense,
          role: CategoryRole.ordinary,
          isSystem: false,
          isActive: false,
        ),
      ],
      parties: [
        const Party(id: 1, name: '旧客户', kind: PartyKind.buyer, isActive: false),
      ],
    );
    await tester.pumpWidget(
      CupertinoApp(
        home: CashBillFormPage(
          id: bill.id,
          viewModelBuilder:
              (_) => CashLedgerViewModel(
                cashBillRepository: cash,
                catalogRepository: catalog,
              ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('店铺范围：旧店铺'), findsOneWidget);
    expect(find.text('分类：旧分类'), findsOneWidget);
    expect(find.text('账户：旧账户'), findsOneWidget);
    expect(find.text('往来方：旧客户'), findsOneWidget);
  });

  testWidgets(
    'isolated status dialog retains typed blank reason on validation',
    (tester) async {
      final cash = RecordingCashBillRepository();
      final bill = await cash.createCashBill(draft());
      await tester.pumpWidget(
        CupertinoApp(
          home: CashBillDetailPage(
            id: bill.id,
            viewModelBuilder:
                (_) => CashLedgerViewModel(
                  cashBillRepository: cash,
                  catalogRepository: RecordingCatalogRepository(),
                )..includeVoid = true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('作废'));
      await tester.enterText(find.byType(CupertinoTextField), '   ');
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      expect(find.text('   '), findsOneWidget);
      expect(cash.voidCashBillCalls, 0);
    },
  );
  testWidgets('voided edit loads same ID rather than opening a new draft', (
    tester,
  ) async {
    final cash = RecordingCashBillRepository();
    final bill = await cash.createCashBill(draft());
    await cash.voidCashBill(bill.id, reason: 'seed');
    await tester.pumpWidget(
      CupertinoApp(
        home: CashBillFormPage(
          id: bill.id,
          viewModelBuilder:
              (_) => CashLedgerViewModel(
                cashBillRepository: cash,
                catalogRepository: RecordingCatalogRepository(),
              ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<CupertinoTextField>(field('金额')).controller!.text,
      '12.34',
    );
  });

  testWidgets('failed edit load never enables a create disguised as edit', (
    tester,
  ) async {
    final cash = RecordingCashBillRepository(refreshThrows: true);
    await tester.pumpWidget(
      CupertinoApp(
        home: CashBillFormPage(
          id: 99,
          viewModelBuilder:
              (_) => CashLedgerViewModel(
                cashBillRepository: cash,
                catalogRepository: RecordingCatalogRepository(),
              ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(field('金额'), '12.34');
    await tapVisible(tester, find.text('保存'));
    expect(cash.createCashBillCalls, 0);
    expect(
      tester
          .widget<CupertinoButton>(
            find.byKey(const ValueKey('cash-save-button')),
          )
          .onPressed,
      isNull,
    );
  });
}
