import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_finances_pro/app/presentation/page_widgets.dart';
import 'package:personal_finances_pro/core/domain/local_date.dart';
import 'package:personal_finances_pro/core/domain/money.dart';
import 'package:personal_finances_pro/features/catalog/domain/catalog_models.dart';
import 'package:personal_finances_pro/features/ledger/domain/ledger_models.dart';
import 'package:personal_finances_pro/features/ledger/presentation/ledger_view_models.dart';
import 'package:personal_finances_pro/features/ledger/presentation/ledger_detail_pages.dart';

import '../../../support/sqlite_ledger_test_harness.dart';
import '../../../support/widget_test_app.dart';

Finder field(String label) => find.byWidgetPredicate(
  (w) => w is CupertinoTextField && w.placeholder == label,
);
Finder verticalScroll() => find.byWidgetPredicate(
  (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
);

// FFI runs on the real event loop; pumping fake time alone cannot complete I/O.
Future<void> settle(WidgetTester tester) async {
  var quiet = 0;
  for (var i = 0; i < 150; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    if (i >= 8 &&
        find.byType(CupertinoActivityIndicator).evaluate().isEmpty &&
        tester
            .widgetList<LedgerBusinessPage>(find.byType(LedgerBusinessPage))
            .every((p) => !p.mutation.pending && !p.mutation.loading)) {
      quiet++;
      if (quiet == 6) return;
    } else {
      quiet = 0;
    }
  }
  throw StateError(
    'UI did not settle: ${find.byType(Text).evaluate().map((e) => (e.widget as Text).data).join('|')}',
  );
}

Future<void> reveal(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    await tester.drag(verticalScroll(), const Offset(0, 5000));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      target,
      160,
      scrollable: verticalScroll(),
      maxScrolls: 80,
    );
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

Future<void> tap(WidgetTester tester, String text) async {
  final target = find.text(text);
  await reveal(tester, target);
  await tester.runAsync(() => tester.tap(target));
  await settle(tester);
}

Future<void> type(WidgetTester tester, String label, String text) async {
  await reveal(tester, field(label));
  await tester.enterText(field(label), text);
  await tester.pump();
}

Future<void> select(WidgetTester tester, String label, String option) async {
  final target = find.textContaining('$label：');
  await reveal(tester, target);
  await tester.tap(target);
  await tester.pumpAndSettle();
  final choice = find.descendant(
    of: find.byType(CupertinoActionSheet),
    matching: find.widgetWithText(CupertinoActionSheetAction, option),
  );
  await tester.ensureVisible(choice);
  await tester.tap(choice);
  await tester.pumpAndSettle();
}

Future<void> status(WidgetTester tester, String label) async {
  await tap(tester, label);
  await tester.enterText(field('原因'), ' 核对修正 ');
  await tester.runAsync(() => tester.tap(find.text('确认')));
  await settle(tester);
  expect(find.byType(CupertinoAlertDialog), findsNothing);
}

Future<void> start(
  WidgetTester tester,
  FakeAppRepositories repos,
  String entry,
) async {
  await pumpLedgerAppWithRepositories(tester, repos);
  await settle(tester);
  await tester.tap(
    find.descendant(
      of: find.byType(CupertinoTabBar),
      matching: find.text('账本'),
    ),
  );
  await settle(tester);
  await tap(tester, entry);
}

Future<SqliteLedgerTestHarness> realApp(
  WidgetTester tester,
  String entry,
) async {
  final h = (await tester.runAsync(SqliteLedgerTestHarness.open))!;
  addTearDown(() async {
    await tester.runAsync(h.close);
  });
  await tester.runAsync(() async {
    await h.createParty(name: '厂家', kind: PartyKind.supplier);
    await h.createParty(name: '买家', kind: PartyKind.buyer);
    await h.createShop('甲店');
  });
  await start(
    tester,
    FakeAppRepositories(
      catalog: h.catalog,
      cashBills: h.cashBills,
      ledger: h.ledger,
      dashboard: h.dashboard,
    ),
    entry,
  );
  return h;
}

Future<void> cashSelectors(
  WidgetTester tester,
  String prefix, {
  required String account,
  required String category,
}) async {
  await select(tester, '$prefix账户', account);
  await select(tester, '$prefix分类', category);
}

Future<void> fillPurchase(WidgetTester tester) async {
  await select(tester, '厂家', '厂家');
  await type(tester, '商品描述 1', '发夹');
  await type(tester, '数量 1', '2');
  await type(tester, '单价 1', '10');
}

PurchaseDetail fixturePurchase() => PurchaseDetail(
  purchase: Purchase(
    id: 7,
    supplierId: 1,
    scope: const BusinessScope.public(),
    businessDate: LocalDate.parse('2026-10-14'),
    originalTotal: Money.parsePositive('20'),
    supplierFreight: Money.zero,
    note: '',
    isVoid: false,
    position: PurchasePosition(
      effectiveTotal: Money.parsePositive('20'),
      paidNet: Money.zero,
      payable: Money.parsePositive('20'),
    ),
  ),
  items: [],
  payments: [],
  adjustments: [],
);
FakeAppRepositories failureApp(RecordingLedgerRepository ledger) =>
    FakeAppRepositories(
      catalog: RecordingCatalogRepository(
        parties: [
          const Party(
            id: 1,
            name: '厂家',
            kind: PartyKind.supplier,
            isActive: true,
          ),
        ],
      ),
      cashBills: RecordingCashBillRepository(),
      ledger: ledger,
      dashboard: RecordingDashboardRepository(),
    );

void main() {
  testWidgets('purchase form keeps overpayment input and guards pending save', (
    tester,
  ) async {
    final gate = Completer<void>();
    final ledger = RecordingLedgerRepository(error: StateError('不得超过待付金额'))
      ..purchaseGate = gate.future;
    await start(tester, failureApp(ledger), '采购单');
    await fillPurchase(tester);
    await type(tester, '首付款金额（可空）', '25');
    await cashSelectors(tester, '付款', account: '测试账户', category: '测试支出');
    await reveal(tester, find.byKey(const ValueKey('purchase-save-button')));
    await tester.tap(find.byKey(const ValueKey('purchase-save-button')));
    await tester.pump();
    expect(ledger.createPurchaseCalls, 1);
    expect(
      tester
          .widget<LedgerBusinessPage>(find.byType(LedgerBusinessPage))
          .children
          .whereType<CupertinoButton>()
          .last
          .onPressed,
      isNull,
    );
    gate.complete();
    await settle(tester);
    await reveal(tester, find.textContaining('不得超过待付金额'));
    expect(find.textContaining('不得超过待付金额'), findsOneWidget);
    await reveal(tester, field('首付款金额（可空）'));
    expect(
      tester.widget<CupertinoTextField>(field('首付款金额（可空）')).controller!.text,
      '25',
    );
    expect(ledger.lastInitialPayment!.amount.cents, 2500);
  });

  testWidgets(
    'strict quantity money date errors are caught and retain the draft',
    (tester) async {
      final ledger = RecordingLedgerRepository(
        error: StateError('repo reached'),
      );
      await start(tester, failureApp(ledger), '采购单');
      await fillPurchase(tester);
      for (final invalid in [
        ('数量 1', '1.5', '数量必须为正整数'),
        ('单价 1', '1.234', '金额最多两位小数'),
        ('业务日期 YYYY-MM-DD', '2026-02-30', 'Invalid calendar date'),
      ]) {
        await type(tester, invalid.$1, invalid.$2);
        await tap(tester, '保存');
        expect(ledger.createPurchaseCalls, 0);
        await reveal(
          tester,
          find.textContaining('FormatException: ${invalid.$3}'),
        );
        await type(
          tester,
          invalid.$1,
          invalid.$1 == '数量 1'
              ? '2'
              : invalid.$1 == '单价 1'
              ? '10'
              : '2026-10-14',
        );
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'committed draft stays locked after reload failure and field changes; new route allows a genuine draft',
    (tester) async {
      final ledger =
          RecordingLedgerRepository()
            ..purchaseDetail = fixturePurchase()
            ..purchaseDetailError = StateError('详情读取失败');
      await start(tester, failureApp(ledger), '采购单');
      await fillPurchase(tester);
      await tap(tester, '保存');
      expect(ledger.createPurchaseCalls, 1);
      await type(tester, '单价 1', '12');
      await reveal(tester, find.byKey(const ValueKey('purchase-save-button')));
      expect(
        tester
            .widget<CupertinoButton>(
              find.byKey(const ValueKey('purchase-save-button')),
            )
            .onPressed,
        isNull,
      );
      ledger.purchaseDetailError = null;
      await tap(tester, '刷新');
      await reveal(tester, find.byKey(const ValueKey('purchase-save-button')));
      expect(
        tester
            .widget<CupertinoButton>(
              find.byKey(const ValueKey('purchase-save-button')),
            )
            .onPressed,
        isNull,
      );
      await tester.pageBack();
      await settle(tester);
      await tap(tester, '采购单');
      await fillPurchase(tester);
      await tap(tester, '保存');
      expect(ledger.createPurchaseCalls, 2);
      expect(
        find.text('采购详情'),
        findsOneWidget,
        reason: find
            .byType(Text)
            .evaluate()
            .map((e) => (e.widget as Text).data)
            .join('|'),
      );
    },
  );

  testWidgets(
    'FFI purchase initial payment, more payment, adjustments and owning status lifecycle',
    (tester) async {
      final h = await realApp(tester, '采购单');
      final accounts =
          (await tester.runAsync(() => h.catalog.listAccountLabels()))!;
      final expense =
          (await tester.runAsync(
            () => h.catalog.listCategories(direction: CashDirection.expense),
          ))!.first;
      final income =
          (await tester.runAsync(
            () => h.catalog.listCategories(direction: CashDirection.income),
          ))!.first;
      await fillPurchase(tester);
      await type(tester, '首付款金额（可空）', '5');
      await cashSelectors(
        tester,
        '付款',
        account: accounts.first.name,
        category: expense.name,
      );
      await tap(tester, '保存');
      expect(
        find.text('采购详情'),
        findsOneWidget,
        reason: find
            .byType(Text)
            .evaluate()
            .map((e) => (e.widget as Text).data)
            .join('|'),
      );
      var d = (await tester.runAsync(() => h.ledger.getPurchaseDetail(1)))!;
      expect(d.purchase.position.payable.cents, 1500);
      await tap(tester, '新增付款');
      await type(tester, '付款金额', '5');
      await cashSelectors(
        tester,
        '付款',
        account: accounts.first.name,
        category: expense.name,
      );
      await tap(tester, '保存付款');
      d = (await tester.runAsync(() => h.ledger.getPurchaseDetail(1)))!;
      expect(d.payments.length, 2);
      await status(tester, '作废付款 #2');
      await status(tester, '恢复付款 #2');
      await tap(tester, '减免 / 退款');
      await type(tester, '调整金额', '2');
      await select(tester, '减免分类（非现金）', expense.name);
      await type(tester, '调整原因', '未付减免');
      await tap(tester, '保存调整');
      await status(tester, '作废调整 #1');
      await status(tester, '恢复调整 #1');
      await tap(tester, '减免 / 退款');
      await select(tester, '调整类型', '已付退款（收入）');
      await type(tester, '调整金额', '1');
      await cashSelectors(
        tester,
        '退款',
        account: accounts.first.name,
        category: income.name,
      );
      await type(tester, '调整原因', '已付退款');
      await tap(tester, '保存调整');
      d = (await tester.runAsync(() => h.ledger.getPurchaseDetail(1)))!;
      expect(d.purchase.position.paidNet.cents, 900);
      expect(d.purchase.position.effectiveTotal.cents, 1700);
      await status(tester, '作废调整 #2');
      await status(tester, '恢复调整 #2');
      await tap(tester, '作废采购');
      await tester.enterText(field('原因'), '不能丢弃活动付款');
      await tester.runAsync(() => tester.tap(find.text('确认')));
      await settle(tester);
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      expect(find.text('不能丢弃活动付款'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await settle(tester);
      await status(tester, '作废调整 #2');
      await status(tester, '作废付款 #2');
      await status(tester, '作废付款 #1');
      await status(tester, '作废采购');
      expect(
        (await tester.runAsync(
          () => h.ledger.getPurchaseDetail(1),
        ))!.purchase.isVoid,
        isTrue,
      );
      await tester.pageBack();
      await settle(tester);
      await tap(tester, '包含作废业务');
      final history = find.textContaining('采购 #1 ·');
      await reveal(tester, history);
      await tester.tap(history);
      await settle(tester);
      await status(tester, '恢复采购');
      expect(
        (await tester.runAsync(
          () => h.ledger.getPurchaseDetail(1),
        ))!.purchase.isVoid,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('FFI opening debt creation payment and payment void restore', (
    tester,
  ) async {
    final h = await realApp(tester, '期初欠款');
    final account =
        (await tester.runAsync(() => h.catalog.listAccountLabels()))!.first;
    final category =
        (await tester.runAsync(
          () => h.catalog.listCategories(direction: CashDirection.expense),
        ))!.first;
    await select(tester, '厂家', '厂家');
    await type(tester, '期初欠款金额', '30');
    await tap(tester, '保存');
    expect(find.text('期初欠款详情'), findsOneWidget);
    expect(await tester.runAsync(h.cashBillCount), 0);
    await tap(tester, '新增付款');
    await type(tester, '付款金额', '10');
    await cashSelectors(
      tester,
      '付款',
      account: account.name,
      category: category.name,
    );
    await tap(tester, '保存付款');
    expect(
      (await tester.runAsync(
        () => h.ledger.getSupplierOpeningDebtDetail(1),
      ))!.debt.paid.cents,
      1000,
    );
    await status(tester, '作废欠款付款 #1');
    await status(tester, '恢复欠款付款 #1');
    expect(
      (await tester.runAsync(
        () => h.ledger.getSupplierOpeningDebtDetail(1),
      ))!.debt.paid.cents,
      1000,
    );
  });

  testWidgets('FFI resale independent fee account and atomic group status', (
    tester,
  ) async {
    final h = await realApp(tester, '问题件转卖');
    final feeAccount = (await tester.runAsync(() => h.createAccount('费用专用')))!;
    final account =
        (await tester.runAsync(() => h.catalog.listAccountLabels()))!.first;
    final expense =
        (await tester.runAsync(
          () => h.catalog.listCategories(direction: CashDirection.expense),
        ))!.first;
    final income =
        (await tester.runAsync(
          () => h.catalog.listCategories(direction: CashDirection.income),
        ))!.first;
    final channel =
        (await tester.runAsync(() => h.catalog.listResaleChannels()))!.first;
    await tap(tester, '刷新');
    await type(tester, '问题件描述', '瑕疵发夹');
    await type(tester, '转卖收入', '15');
    await select(tester, '买家', '买家');
    await select(tester, '转卖渠道', channel.name);
    await cashSelectors(
      tester,
      '收入',
      account: account.name,
      category: income.name,
    );
    await tap(tester, '添加独立费用');
    await type(tester, '费用金额 1', '2');
    await cashSelectors(
      tester,
      '费用 1 ',
      account: feeAccount.name,
      category: expense.name,
    );
    await type(tester, '问题说明（可空）', '破损');
    await tap(tester, '保存转卖');
    expect(
      find.text('转卖详情'),
      findsOneWidget,
      reason: find
          .byType(Text)
          .evaluate()
          .map((e) => (e.widget as Text).data)
          .join('|'),
    );
    final detail =
        (await tester.runAsync(() => h.ledger.getProblemResaleDetail(1)))!;
    expect(detail.fees.single.accountId, feeAccount.id);
    expect(detail.netRecovery.cents, 1300);
    await status(tester, '作废转卖整组');
    var bills =
        (await tester.runAsync(
          () => h.cashBills.listCashBills(
            const CashBillFilter(includeVoid: true),
          ),
        ))!;
    expect(bills.length, 2);
    expect(bills.every((b) => b.isVoid), isTrue);
    await status(tester, '恢复转卖整组');
    bills =
        (await tester.runAsync(
          () => h.cashBills.listCashBills(
            const CashBillFilter(includeVoid: true),
          ),
        ))!;
    expect(bills.every((b) => !b.isVoid), isTrue);
  });

  testWidgets(
    'FFI courier opening topup scoped consume refund and event status',
    (tester) async {
      final h = await realApp(tester, '新增快递钱包');
      final account =
          (await tester.runAsync(() => h.catalog.listAccountLabels()))!.first;
      final expense =
          (await tester.runAsync(
            () => h.catalog.listCategories(direction: CashDirection.expense),
          ))!.first;
      final income =
          (await tester.runAsync(
            () => h.catalog.listCategories(direction: CashDirection.income),
          ))!.first;
      await type(tester, '钱包名称', '快递A');
      await type(tester, '期初余额（空为零）', '10');
      await tap(tester, '保存快递记录');
      expect(find.text('快递钱包详情'), findsOneWidget);
      expect(await tester.runAsync(h.cashBillCount), 0);
      await tap(tester, '新增充值');
      await type(tester, '事件金额', '20');
      await cashSelectors(
        tester,
        '现金',
        account: account.name,
        category: expense.name,
      );
      await tap(tester, '保存快递记录');
      await tap(tester, '新增消耗');
      await select(tester, '业务范围', '甲店');
      await type(tester, '事件金额', '30');
      await type(tester, '事件备注', '店铺寄件');
      await tap(tester, '保存快递记录');
      expect(await tester.runAsync(h.cashBillCount), 1);
      var d =
          (await tester.runAsync(() => h.ledger.getCourierAccountDetail(1)))!;
      expect(d.account.recordedBalance.cents, 0);
      expect(d.events.last.scope!.shopId, isNotNull);
      await tap(tester, '作废事件 #2');
      await tester.enterText(field('原因'), '余额校验');
      await tester.runAsync(() => tester.tap(find.text('确认')));
      await settle(tester);
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      expect(find.text('余额校验'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await settle(tester);
      await status(tester, '作废事件 #3');
      await status(tester, '恢复事件 #3');
      await status(tester, '作废事件 #3');
      await tap(tester, '新增退款');
      await type(tester, '事件金额', '5');
      await cashSelectors(
        tester,
        '现金',
        account: account.name,
        category: income.name,
      );
      await tap(tester, '保存快递记录');
      await status(tester, '作废事件 #4');
      await status(tester, '恢复事件 #4');
      d = (await tester.runAsync(() => h.ledger.getCourierAccountDetail(1)))!;
      expect(d.account.recordedBalance.cents, 2500);
      await reveal(tester, find.text('期初余额不可作废'));
      expect(find.text('期初余额不可作废'), findsOneWidget);
      expect(find.text('作废事件 #1'), findsNothing);
      await status(tester, '作废事件 #2');
      await status(tester, '恢复事件 #2');
      expect(await tester.runAsync(h.cashBillCount), 2);
    },
  );

  test(
    'shared commit boundary keeps stale status locked until a successful read',
    () async {
      final m = LedgerMutation();
      addTearDown(m.dispose);
      await m.read(() async {});
      final gate = Completer<void>();
      var writes = 0;
      final pending = m.submit(() async {
        writes++;
        await gate.future;
      }, reload: () async => throw StateError('read failed'));
      expect(m.pending, isTrue);
      expect(
        await m.submit(() async {
          writes++;
        }, reload: () async {}),
        isFalse,
      );
      gate.complete();
      expect(await pending, isTrue);
      expect(m.canAct, isFalse);
      expect(
        await m.submit(() async {
          writes++;
        }, reload: () async {}),
        isFalse,
      );
      await m.read(() async {});
      expect(m.canAct, isTrue);
      expect(writes, 1);
    },
  );

  testWidgets('missing detail cannot become a new payment or adjustment', (
    tester,
  ) async {
    await start(tester, failureApp(RecordingLedgerRepository()), '采购单');
    final router = GoRouter.of(tester.element(find.byType(LedgerBusinessPage)));
    for (final path in [
      '/ledger/purchases/99/payment',
      '/ledger/purchases/99/adjust',
      '/ledger/opening-debts/99/payment',
      '/ledger/courier/99/consume',
    ]) {
      router.go(path);
      await settle(tester);
      final button = find.byWidgetPredicate(
        (w) =>
            w is CupertinoButton &&
            w.key is ValueKey &&
            (w.key as ValueKey).value.toString().endsWith('save-button'),
      );
      expect(tester.widget<CupertinoButton>(button).onPressed, isNull);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'required buyer can be created in catalog then selected without losing resale fields',
    (tester) async {
      final repos = FakeAppRepositories.empty();
      await start(tester, repos, '问题件转卖');
      await type(tester, '问题件描述', '保留描述');
      await type(tester, '转卖收入', '10');
      await cashSelectors(tester, '收入', account: '测试账户', category: '测试收入');
      await tap(tester, '保存转卖');
      await reveal(tester, find.textContaining('请选择买家'));
      expect(find.textContaining('请选择买家'), findsOneWidget);
      await tap(tester, '到基础资料新增买家，返回后刷新');
      await tap(tester, '新增');
      await tester.tap(find.text('买家'));
      await settle(tester);
      expect(
        find.byType(CupertinoTextField),
        findsOneWidget,
        reason: find
            .byType(Text)
            .evaluate()
            .map((e) => (e.widget as Text).data)
            .join('|'),
      );
      await tester.enterText(find.byType(CupertinoTextField), '新买家');
      await tester.tap(find.text('保存'));
      await settle(tester);
      await tester.pageBack();
      await settle(tester);
      await tap(tester, '刷新');
      await select(tester, '买家', '新买家');
      await reveal(tester, field('问题件描述'));
      expect(
        tester.widget<CupertinoTextField>(field('问题件描述')).controller!.text,
        '保留描述',
      );
      await tap(tester, '保存转卖');
      await reveal(tester, find.textContaining('请选择渠道'));
      expect(find.textContaining('请选择渠道'), findsOneWidget);
    },
  );

  testWidgets(
    'reason pending failure and committed refresh failure never retry a stale status',
    (tester) async {
      final m = LedgerMutation();
      addTearDown(m.dispose);
      await m.read(() async {});
      var writes = 0, fail = true, reloadFail = false;
      final gate = Completer<void>();
      Future<void> load() async {
        if (reloadFail) throw StateError('reload failed');
      }

      await tester.pumpWidget(
        CupertinoApp(
          home: AnimatedBuilder(
            animation: m,
            builder:
                (context, _) => LedgerBusinessPage(
                  title: '状态',
                  mutation: m,
                  reload: load,
                  children: [
                    LedgerStatusButton(
                      label: '作废业务',
                      mutation: m,
                      reload: load,
                      write: (reason) async {
                        writes++;
                        expect(reason, ' 原因原样 ');
                        await gate.future;
                        if (fail) throw StateError('commit failed');
                      },
                    ),
                  ],
                ),
          ),
        ),
      );
      await tap(tester, '作废业务');
      await tester.enterText(field('原因'), ' 原因原样 ');
      await tester.tap(find.text('确认'));
      await tester.pump();
      for (final action in tester.widgetList<CupertinoDialogAction>(
        find.byType(CupertinoDialogAction),
      )) {
        expect(action.onPressed, isNull);
      }
      expect(writes, 1);
      gate.complete();
      await settle(tester);
      expect(
        tester.widget<CupertinoTextField>(field('原因')).controller!.text,
        ' 原因原样 ',
      );
      expect(find.textContaining('commit failed'), findsWidgets);
      fail = false;
      reloadFail = true;
      await tester.tap(find.text('确认'));
      await settle(tester);
      expect(writes, 2);
      expect(find.byType(CupertinoAlertDialog), findsNothing);
      expect(
        tester
            .widget<CupertinoButton>(
              find.widgetWithText(CupertinoButton, '作废业务'),
            )
            .onPressed,
        isNull,
      );
      expect(m.error, contains('已提交，但刷新失败'));
      reloadFail = false;
      await tap(tester, '刷新');
      expect(m.canAct, isTrue);
      expect(writes, 2);
    },
  );

  testWidgets(
    'FFI linked cash opens its typed root owner for all seven link types',
    (tester) async {
      final h = await realApp(tester, '账本明细');
      await tester.runAsync(() async {
        final p = await h.seedPurchase(total: '50', paid: '20');
        await h.seedPaidRefund(purchaseId: p, amount: '2');
        await h.seedProblemResale(amount: '10', fee: '1');
        final supplier =
            (await h.catalog.listParties(kind: PartyKind.supplier)).first;
        final debt = await h.ledger.createSupplierOpeningDebt(
          SupplierOpeningDebtDraft(
            supplierId: supplier.id,
            scope: const BusinessScope.public(),
            businessDate: LocalDate.parse('2026-10-14'),
            amount: Money.parsePositive('10'),
          ),
        );
        await h.ledger.paySupplierOpeningDebt(
          openingDebtId: debt,
          payment: h.purchasePayment(amount: '2'),
        );
        final courier = await h.ledger.createCourierAccount(
          CourierAccountDraft(
            name: '链接钱包',
            openingBalance: Money.zero,
            businessDate: LocalDate.parse('2026-10-14'),
          ),
        );
        await h.ledger.recordCourierTopUp(
          h.courierTopUp(
            courierAccountId: courier,
            scope: const BusinessScope.public(),
            amount: '10',
          ),
        );
        final income =
            (await h.catalog.listCategories(
              direction: CashDirection.income,
            )).first;
        final account = (await h.catalog.listAccountLabels()).first;
        await h.ledger.recordCourierRefund(
          CourierCashEventDraft(
            courierAccountId: courier,
            scope: const BusinessScope.public(),
            businessDate: LocalDate.parse('2026-10-14'),
            amount: Money.parsePositive('1'),
            accountId: account.id,
            categoryId: income.id,
          ),
        );
      });
      final bills =
          (await tester.runAsync(
            () => h.cashBills.listCashBills(const CashBillFilter()),
          ))!;
      expect(bills.map((b) => b.linkedType).toSet().length, 7);
      final router = GoRouter.of(
        tester.element(find.byType(LedgerBusinessPage)),
      );
      for (final bill in bills) {
        router.go('/ledger/cash/${bill.id}');
        await settle(tester);
        await tap(tester, '打开所属业务');
        final owner = switch (bill.linkedType!) {
          LinkedBillType.purchasePayment ||
          LinkedBillType.supplierRefund => 'purchases',
          LinkedBillType.openingDebtPayment => 'opening-debts',
          LinkedBillType.problemResaleIncome ||
          LinkedBillType.problemResaleFee => 'resales',
          LinkedBillType.courierTopUp ||
          LinkedBillType.courierRefund => 'courier',
        };
        expect(
          GoRouterState.of(
            tester.element(find.byType(LedgerBusinessPage)),
          ).uri.path,
          '/ledger/$owner/${bill.linkedId}',
        );
        expect(find.textContaining('详情不可用'), findsNothing);
      }
    },
  );

  testWidgets(
    'manual forms keep last input and save above one keyboard inset across widths and top insets',
    (tester) async {
      addTearDown(() {
        tester.view.reset();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
        tester.platformDispatcher.clearPlatformBrightnessTestValue();
      });
      final h = await realApp(tester, '账本明细');
      final id =
          (await tester.runAsync(
            () => h.ledger.createCourierAccount(
              CourierAccountDraft(
                name: '布局钱包',
                openingBalance: Money.parsePositive('100'),
                businessDate: LocalDate.parse('2026-10-01'),
              ),
            ),
          ))!;
      final account =
          (await tester.runAsync(() => h.catalog.listAccountLabels()))!.first;
      final income =
          (await tester.runAsync(
            () => h.catalog.listCategories(direction: CashDirection.income),
          ))!.first;
      final channel =
          (await tester.runAsync(() => h.catalog.listResaleChannels()))!.first;
      final router = GoRouter.of(
        tester.element(find.byType(LedgerBusinessPage)),
      );
      for (final width in [320.0, 390.0, 430.0]) {
        for (final top in [0.0, 54.0, 64.0]) {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, 844);
          tester.platformDispatcher.textScaleFactorTestValue = 1.5;
          tester.platformDispatcher.platformBrightnessTestValue =
              top == 64 ? Brightness.dark : Brightness.light;
          for (final entry in [
            ('/ledger/purchases/new', '备注', 'purchase-save-button'),
            ('/ledger/resales/new', '问题说明（可空）', 'resale-save-button'),
            ('/ledger/courier/$id/consume', '事件备注', 'courier-save-button'),
          ]) {
            tester.view.padding = FakeViewPadding(top: top, bottom: 34);
            tester.view.viewPadding = FakeViewPadding(top: top, bottom: 34);
            tester.view.viewInsets = FakeViewPadding.zero;
            if (entry.$3 == 'courier-save-button') {
              router.go('/ledger/courier/$id');
              await settle(tester);
              await tap(tester, '新增消耗');
            } else {
              router.go(entry.$1);
              await settle(tester);
            }
            final bar = tester.getRect(find.byType(CupertinoNavigationBar));
            final scroll = tester.getRect(find.byType(ListView));
            expect(scroll.top, greaterThanOrEqualTo(bar.bottom));
            expect(scroll.top, lessThanOrEqualTo(bar.bottom + 1));
            if (entry.$3 == 'purchase-save-button') {
              await fillPurchase(tester);
            } else if (entry.$3 == 'resale-save-button') {
              await type(tester, '问题件描述', '布局转卖');
              await type(tester, '转卖收入', '1');
              await select(tester, '买家', '买家');
              await select(tester, '转卖渠道', channel.name);
              await cashSelectors(
                tester,
                '收入',
                account: account.name,
                category: income.name,
              );
            } else {
              await type(tester, '事件金额', '1');
            }
            await type(tester, entry.$2, '最后输入');
            tester.view.padding = FakeViewPadding(top: top);
            tester.view.viewInsets = const FakeViewPadding(bottom: 300);
            await settle(tester);
            final save = find.byKey(ValueKey(entry.$3));
            await reveal(tester, save);
            expect(tester.getRect(save).bottom, lessThanOrEqualTo(544));
            expect(tester.getRect(save).top, greaterThanOrEqualTo(bar.bottom));
            expect(find.byType(CupertinoTabBar), findsNothing);
            await tester.runAsync(() => tester.tap(save));
            await settle(tester);
            expect(
              find.text(
                entry.$3 == 'purchase-save-button'
                    ? '采购详情'
                    : entry.$3 == 'resale-save-button'
                    ? '转卖详情'
                    : '快递钱包详情',
              ),
              findsOneWidget,
            );
            if (entry.$3 == 'purchase-save-button') {
              for (final action in ['作废采购', '恢复采购']) {
                await tap(tester, action);
                await tester.enterText(field('原因'), '布局修正');
                final confirm = find.text('确认');
                expect(tester.getRect(confirm).bottom, lessThanOrEqualTo(544));
                expect(tester.getRect(confirm).top, greaterThanOrEqualTo(top));
                await tester.runAsync(() => tester.tap(confirm));
                await settle(tester);
                expect(find.byType(CupertinoAlertDialog), findsNothing);
              }
            }
            expect(tester.takeException(), isNull);
          }
        }
      }
      expect(
        (await tester.runAsync(
          () => h.ledger.listPurchases(const PurchaseFilter(includeVoid: true)),
        ))!.length,
        9,
      );
      expect(
        (await tester.runAsync(
          () => h.ledger.listProblemResales(
            const ProblemResaleFilter(includeVoid: true),
          ),
        ))!.length,
        9,
      );
      expect(
        (await tester.runAsync(
          () => h.ledger.getCourierAccountDetail(id),
        ))!.account.recordedBalance.cents,
        9100,
      );
    },
  );

  testWidgets(
    'FFI snapshot period all public shop semantics never label global wallet as shop balance',
    (tester) async {
      final h = await realApp(tester, '账本明细');
      await tester.runAsync(() async {
        final id = await h.ledger.createCourierAccount(
          CourierAccountDraft(
            name: '快递',
            openingBalance: Money.parsePositive('10'),
            businessDate: LocalDate.parse('2026-10-01'),
          ),
        );
        await h.ledger.recordCourierTopUp(
          h.courierTopUp(
            courierAccountId: id,
            scope: const BusinessScope.public(),
            amount: '20',
          ),
        );
        final shop = (await h.catalog.listShops()).single;
        await h.ledger.recordCourierConsume(
          CourierConsumeDraft(
            courierAccountId: id,
            scope: BusinessScope.shop(shop.id),
            businessDate: LocalDate.parse('2026-10-15'),
            amount: Money.parsePositive('5'),
          ),
        );
      });
      await type(tester, '开始日期 YYYY-MM-DD', '2026-10-01');
      await type(tester, '结束日期 YYYY-MM-DD', '2026-10-31');
      await tap(tester, '查看期间');
      await reveal(tester, find.textContaining('当前全局快递预付余额'));
      expect(find.text('25.00'), findsOneWidget);
      await select(tester, '范围筛选', '公共');
      await tap(tester, '查看期间');
      await tester.drag(verticalScroll(), const Offset(0, -3000));
      await settle(tester);
      expect(find.textContaining('当前全局快递预付余额'), findsNothing);
      expect(find.textContaining('充值 20.00'), findsOneWidget);
      await select(tester, '范围筛选', '甲店');
      await tap(tester, '查看期间');
      await tester.drag(verticalScroll(), const Offset(0, -3000));
      await settle(tester);
      expect(find.textContaining('当前全局快递预付余额'), findsNothing);
      expect(find.textContaining('消耗 5.00'), findsOneWidget);
      expect(find.textContaining('充值 0.00'), findsOneWidget);
    },
  );

  testWidgets(
    'owning detail refreshes on tab return and preserves inactive historical names without offering new assignment',
    (tester) async {
      final h = await realApp(tester, '账本明细');
      final id =
          (await tester.runAsync(
            () => h.seedPurchase(total: '20', paid: '5'),
          ))!;
      final initial =
          (await tester.runAsync(() => h.ledger.getPurchaseDetail(id)))!;
      final bill =
          (await tester.runAsync(
            () => h.cashBills.listCashBills(const CashBillFilter()),
          ))!.single;
      final account = (await tester.runAsync(
        () => h.catalog.listAccountLabels(),
      ))!.singleWhere((a) => a.id == bill.accountId);
      final category = (await tester.runAsync(
        () => h.catalog.listCategories(),
      ))!.singleWhere((a) => a.id == bill.categoryId);
      final supplier = (await tester.runAsync(
        () => h.catalog.listParties(),
      ))!.singleWhere((a) => a.id == initial.purchase.supplierId);
      final router = GoRouter.of(
        tester.element(find.byType(LedgerBusinessPage)),
      );
      router.go('/ledger/purchases/$id');
      await settle(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(CupertinoTabBar),
          matching: find.text('设置'),
        ),
      );
      await settle(tester);
      await tester.runAsync(() async {
        await h.ledger.recordPurchasePayment(
          purchaseId: id,
          payment: h.purchasePayment(amount: '5'),
        );
        await h.catalog.deactivateAccountLabel(account.id);
        await h.catalog.deactivateCategory(category.id);
        await h.catalog.deactivateParty(supplier.id);
      });
      await tester.tap(
        find.descendant(
          of: find.byType(CupertinoTabBar),
          matching: find.text('账本'),
        ),
      );
      await settle(tester);
      await reveal(tester, find.textContaining('实付净额 10.00'));
      final purchaseSummary = find.ancestor(
        of: find.text('采购 #$id'),
        matching: find.byType(InfoCard),
      );
      expect(
        find.descendant(
          of: purchaseSummary,
          matching: find.textContaining(supplier.name),
        ),
        findsOneWidget,
      );
      await tap(tester, '新增付款');
      for (final entry in [('付款账户', account.name), ('付款分类', category.name)]) {
        final row = find.textContaining('${entry.$1}：');
        await reveal(tester, row);
        await tester.tap(row);
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(CupertinoActionSheet),
            matching: find.text(entry.$2),
          ),
          findsNothing,
        );
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'catalog initialization failure blocks a new purchase and only offers read retry',
    (tester) async {
      final repos = FakeAppRepositories.withLedgerError(StateError('资料读取失败'));
      await start(tester, repos, '采购单');
      await type(tester, '商品描述 1', '保留输入');
      final page = tester.widget<LedgerBusinessPage>(
        find.byType(LedgerBusinessPage),
      );
      expect(page.mutation.ready, isFalse);
      expect(page.children.whereType<CupertinoButton>().last.onPressed, isNull);
      await tap(tester, '刷新');
      await reveal(tester, field('商品描述 1'));
      expect(
        tester.widget<CupertinoTextField>(field('商品描述 1')).controller!.text,
        '保留输入',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'FFI completed resale retains distinct inactive fee counterparty in business and linked cash details',
    (tester) async {
      final h = await realApp(tester, '问题件转卖');
      final feeParty =
          (await tester.runAsync(
            () => h.createParty(name: '历史费用往来方', kind: PartyKind.other),
          ))!;
      final feeAccount =
          (await tester.runAsync(() => h.createAccount('费用独立账户')))!;
      final account =
          (await tester.runAsync(() => h.catalog.listAccountLabels()))!.first;
      final expense =
          (await tester.runAsync(
            () => h.catalog.listCategories(direction: CashDirection.expense),
          ))!.first;
      final income =
          (await tester.runAsync(
            () => h.catalog.listCategories(direction: CashDirection.income),
          ))!.first;
      final channel =
          (await tester.runAsync(() => h.catalog.listResaleChannels()))!.first;
      await type(tester, '问题件描述', '归属回归');
      await type(tester, '转卖收入', '15');
      await tap(tester, '到基础资料新增买家，返回后刷新');
      await tap(tester, '新增');
      await tester.tap(find.widgetWithText(CupertinoActionSheetAction, '买家'));
      await settle(tester);
      await tester.enterText(find.byType(CupertinoTextField), '真实新增买家');
      await tester.runAsync(
        () => tester.tap(find.widgetWithText(CupertinoDialogAction, '保存')),
      );
      await settle(tester);
      final buyer = (await tester.runAsync(
        () => h.catalog.listParties(kind: PartyKind.buyer),
      ))!.singleWhere((p) => p.name == '真实新增买家');
      await tester.pageBack();
      await settle(tester);
      await tap(tester, '刷新');
      await select(tester, '买家', buyer.name);
      await reveal(tester, field('问题件描述'));
      expect(
        tester.widget<CupertinoTextField>(field('问题件描述')).controller!.text,
        '归属回归',
      );
      await select(tester, '转卖渠道', channel.name);
      await cashSelectors(
        tester,
        '收入',
        account: account.name,
        category: income.name,
      );
      for (var i = 1; i <= 2; i++) {
        await tap(tester, '添加独立费用');
        await type(tester, '费用金额 $i', i == 1 ? '2' : '1');
        await cashSelectors(
          tester,
          '费用 $i ',
          account: feeAccount.name,
          category: expense.name,
        );
        if (i == 1) await select(tester, '费用往来方 $i', feeParty.name);
      }
      await tap(tester, '保存转卖');
      expect(find.text('转卖详情'), findsOneWidget);
      final resale =
          (await tester.runAsync(
            () => h.ledger.listProblemResales(const ProblemResaleFilter()),
          ))!.single;
      expect(resale.buyerId, buyer.id);
      final detail =
          (await tester.runAsync(
            () => h.ledger.getProblemResaleDetail(resale.id),
          ))!;
      final bills =
          (await tester.runAsync(
            () => h.cashBills.listCashBills(const CashBillFilter()),
          ))!;
      final attributed = bills.singleWhere(
        (b) =>
            b.id ==
            detail.fees.singleWhere((f) => f.amount.cents == 200).cashBillId,
      );
      final unattributed = bills.singleWhere(
        (b) =>
            b.id ==
            detail.fees.singleWhere((f) => f.amount.cents == 100).cashBillId,
      );
      expect(attributed.partyId, feeParty.id);
      expect(attributed.partyId, isNot(buyer.id));
      expect(attributed.accountId, feeAccount.id);
      expect(
        bills.singleWhere((b) => b.id == resale.incomeCashBillId).accountId,
        account.id,
      );
      expect(unattributed.partyId, isNull);
      await tester.runAsync(() => h.catalog.deactivateParty(feeParty.id));
      final historical = (await tester.runAsync(
        () => h.catalog.listParties(includeInactive: true),
      ))!.singleWhere((p) => p.id == feeParty.id);
      expect(historical.isActive, isFalse);
      await tap(tester, '刷新');

      Finder feeCard(String amount) => find.ancestor(
        of: find.text('费用 $amount'),
        matching: find.byType(InfoCard),
      );
      await reveal(tester, feeCard('1.00'));
      final noPartyLink = find.descendant(
        of: feeCard('1.00'),
        matching: find.byType(CupertinoButton),
      );
      final noPartyText =
          tester
              .widget<Text>(
                find.descendant(of: noPartyLink, matching: find.byType(Text)),
              )
              .data!;
      expect(noPartyText, isNot(contains('null')));
      expect(noPartyText, isNot(contains('往来方')));
      await tester.runAsync(() => tester.tap(noPartyLink));
      await settle(tester);
      final noPartyCash = tester.widget<InfoCard>(
        find.widgetWithText(InfoCard, '支出 1.00'),
      );
      expect(noPartyCash.body, isNot(contains('null')));
      expect(noPartyCash.body, isNot(contains('往来方')));
      await tester.pageBack();
      await settle(tester);

      await reveal(tester, feeCard('2.00'));
      final feeLink = find.descendant(
        of: feeCard('2.00'),
        matching: find.byType(CupertinoButton),
      );
      final feeText =
          tester
              .widget<Text>(
                find.descendant(of: feeLink, matching: find.byType(Text)),
              )
              .data!;
      final businessShowsHistoricalParty = feeText.contains(
        '往来方 ${historical.name}',
      );
      expect(feeText, isNot(contains(buyer.name)));
      await tester.runAsync(() => tester.tap(feeLink));
      await settle(tester);
      final feeCash = tester.widget<InfoCard>(
        find.widgetWithText(InfoCard, '支出 2.00'),
      );
      expect(feeCash.body, isNot(contains(buyer.name)));
      expect(
        [
          businessShowsHistoricalParty,
          feeCash.body.contains('往来方 ${historical.name}'),
        ],
        [true, true],
        reason:
            'Both saved business fee and linked cash must show their actual inactive counterparty, not the buyer.',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
