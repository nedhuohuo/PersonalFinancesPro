import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_finances_pro/features/ledger/domain/ledger_models.dart';

import '../support/widget_test_app.dart';

void main() {
  void resetWindowAfter(WidgetTester tester) {
    addTearDown(() {
      tester.view.reset();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      tester.platformDispatcher.clearPlatformBrightnessTestValue();
    });
  }

  Future<void> setSurface(
    WidgetTester tester, {
    double width = 390,
    double height = 844,
    double textScale = 1,
    Brightness brightness = Brightness.light,
    FakeViewPadding padding = FakeViewPadding.zero,
    FakeViewPadding? viewPadding,
    FakeViewPadding viewInsets = FakeViewPadding.zero,
  }) async {
    resetWindowAfter(tester);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, height);
    tester.view.padding = padding;
    tester.view.viewPadding = viewPadding ?? padding;
    tester.view.viewInsets = viewInsets;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    tester.platformDispatcher.platformBrightnessTestValue = brightness;
  }

  Future<void> tapTab(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(
        of: find.byType(CupertinoTabBar),
        matching: find.text(label),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('four-entry navigation renders persisted ledger states', (
    tester,
  ) async {
    await pumpLedgerAppWithRepositories(tester, FakeAppRepositories.empty());
    expect(find.text('平台外经营账本'), findsOneWidget);
    expect(find.text('本月实付支出'), findsOneWidget);
    expect(find.text('0.00'), findsWidgets);
    await tapTab(tester, '账本');
    expect(find.text('新增现金账'), findsOneWidget);
    await tapTab(tester, 'AI记账');
    expect(find.text('AI功能尚未接入'), findsOneWidget);
    expect(find.textContaining('本地账本已连接'), findsOneWidget);
    expect(find.textContaining('本地持久化存在后启用'), findsNothing);
    await tapTab(tester, '设置');
    expect(find.text('数据保存在本机'), findsOneWidget);
  });

  testWidgets('tabs and routes render in light and dark modes', (tester) async {
    for (final brightness in Brightness.values) {
      await setSurface(tester, brightness: brightness);
      await pumpLedgerAppWithRepositories(tester, FakeAppRepositories.empty());
      expect(find.byType(CupertinoTabBar), findsOneWidget);
      expect(find.text('本月实付支出'), findsOneWidget);
      await tapTab(tester, '账本');
      expect(find.text('新增现金账'), findsOneWidget);
      await tapTab(tester, 'AI记账');
      expect(find.text('AI功能尚未接入'), findsOneWidget);
      await tapTab(tester, '设置');
      expect(find.text('数据保存在本机'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('widths and large text keep actionable content available', (
    tester,
  ) async {
    for (final width in [320.0, 390.0, 430.0]) {
      await setSurface(tester, width: width, textScale: 1.5);
      await pumpLedgerAppWithRepositories(tester, FakeAppRepositories.empty());
      expect(find.byType(CupertinoTabBar), findsOneWidget);
      await tapTab(tester, '账本');
      await tester.tap(find.text('新增现金账'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).last, const Offset(0, -520));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('cash-save-button')), findsWidgets);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tapTab(tester, 'AI记账');
      final sendRect = tester.getRect(
        find.byKey(const ValueKey('ai-send-button')),
      );
      expect(sendRect.width, greaterThanOrEqualTo(48));
      expect(sendRect.height, greaterThanOrEqualTo(48));
      await tapTab(tester, '设置');
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('settings-version-row')),
        240,
      );
      await tester.pumpAndSettle();
      expect(find.text('版本 0.1.0'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('cash tap entry save writes through injected repository', (
    tester,
  ) async {
    final cashBills = RecordingCashBillRepository();
    final repositories = FakeAppRepositories(
      catalog: RecordingCatalogRepository(),
      cashBills: cashBills,
      ledger: RecordingLedgerRepository(),
      dashboard: RecordingDashboardRepository(cashBills: cashBills),
    );
    await pumpLedgerAppWithRepositories(tester, repositories);
    await tapTab(tester, '账本');
    await tester.tap(find.text('新增现金账'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(CupertinoTextField, '金额'),
      '12.34',
    );
    await tester.drag(find.byType(ListView).last, const Offset(0, -520));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存').last);
    await tester.pumpAndSettle();

    expect(cashBills.createCashBillCalls, 1);
    await tester.scrollUntilVisible(
      find.textContaining('12.34'),
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
    await tester.pumpAndSettle();
    expect(find.textContaining('12.34'), findsWidgets);
  });

  testWidgets('safe areas keep content and tab hits outside system regions', (
    tester,
  ) async {
    for (final insets in [
      FakeViewPadding.zero,
      const FakeViewPadding(top: 24, bottom: 24),
      const FakeViewPadding(top: 54, bottom: 34),
    ]) {
      await setSurface(tester, padding: insets);
      await pumpLedgerAppWithRepositories(tester, FakeAppRepositories.empty());

      expect(
        tester.getTopLeft(find.text('平台外经营账本')).dy,
        greaterThanOrEqualTo(insets.top),
      );
      final homeLabel = tester.getRect(
        find.descendant(
          of: find.byType(CupertinoTabBar),
          matching: find.text('首页'),
        ),
      );
      expect(homeLabel.bottom, lessThanOrEqualTo(844 - insets.bottom));

      await tapTab(tester, '设置');
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('settings-version-row')),
        240,
      );
      await tester.pumpAndSettle();
      final tabBarTop = tester.getTopLeft(find.byType(CupertinoTabBar)).dy;
      final lastRowBottom =
          tester
              .getRect(find.byKey(const ValueKey('settings-version-row')))
              .bottom;
      expect(lastRowBottom, lessThanOrEqualTo(tabBarTop));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets(
    'keyboard hides tabs and composer avoids a single keyboard inset',
    (tester) async {
      const height = 844.0;
      const keyboard = 300.0;
      await setSurface(
        tester,
        padding: const FakeViewPadding(bottom: 34),
        viewPadding: const FakeViewPadding(bottom: 34),
      );
      await pumpLedgerAppWithRepositories(tester, FakeAppRepositories.empty());
      await tapTab(tester, 'AI记账');

      tester.view.padding = FakeViewPadding.zero;
      tester.view.viewPadding = const FakeViewPadding(bottom: 34);
      tester.view.viewInsets = const FakeViewPadding(bottom: keyboard);
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoTabBar), findsNothing);
      final composer = tester.getRect(
        find.byKey(const ValueKey('ai-composer')),
      );
      expect(composer.bottom, lessThanOrEqualTo(height - keyboard));
      expect(composer.bottom, greaterThan(height - keyboard - 140));
      expect(
        tester
            .widget<CupertinoButton>(
              find.byKey(const ValueKey('ai-send-button')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<CupertinoButton>(
              find.byKey(const ValueKey('ai-confirm-button')),
            )
            .onPressed,
        isNull,
      );

      tester.view.padding = const FakeViewPadding(bottom: 34);
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoTabBar), findsOneWidget);
      await tapTab(tester, '首页');
      expect(find.text('平台外经营账本'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'cash save and reason confirm remain reachable across width scale safe-area keyboard matrix',
    (tester) async {
      for (final width in [320.0, 390.0, 430.0]) {
        await setSurface(
          tester,
          width: width,
          textScale: 1.5,
          padding: const FakeViewPadding(top: 54, bottom: 34),
        );
        final cash = RecordingCashBillRepository();
        await pumpLedgerAppWithRepositories(
          tester,
          FakeAppRepositories(
            catalog: RecordingCatalogRepository(),
            cashBills: cash,
            ledger: RecordingLedgerRepository(),
            dashboard: RecordingDashboardRepository(cashBills: cash),
          ),
        );
        await tapTab(tester, '账本');
        await tester.tap(find.text('新增现金账'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(CupertinoTextField, '金额'),
          '12.34',
        );
        tester.view.padding = const FakeViewPadding(top: 54);
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();
        final save = find.byKey(const ValueKey('cash-save-button'));
        await tester.scrollUntilVisible(
          save,
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
        await tester.pumpAndSettle();
        final saveRect = tester.getRect(save);
        expect(saveRect.bottom, lessThanOrEqualTo(844 - 300));
        expect(saveRect.top, greaterThanOrEqualTo(54));
        expect(find.byType(CupertinoTabBar), findsNothing);
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(cash.createCashBillCalls, 1);
        tester.view.padding = const FakeViewPadding(top: 54, bottom: 34);
        tester.view.viewInsets = FakeViewPadding.zero;
        await tester.pumpAndSettle();
        final bill = find.text('普通现金账');
        await tester.scrollUntilVisible(
          bill,
          160,
          scrollable:
              find
                  .byWidgetPredicate(
                    (widget) =>
                        widget is Scrollable &&
                        widget.axisDirection == AxisDirection.down,
                  )
                  .last,
        );
        await tester.ensureVisible(bill);
        await tester.pumpAndSettle();
        expect(
          tester.getRect(bill).bottom,
          lessThanOrEqualTo(tester.getTopLeft(find.byType(CupertinoTabBar)).dy),
        );
        await tester.tap(bill);
        await tester.pumpAndSettle();
        await tester.tap(find.text('作废'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(CupertinoTextField), '矩阵作废');
        tester.view.padding = const FakeViewPadding(top: 54);
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('确认'));
        final confirmRect = tester.getRect(find.text('确认'));
        expect(confirmRect.bottom, lessThanOrEqualTo(844 - 300));
        expect(confirmRect.top, greaterThanOrEqualTo(54));
        await tester.tap(find.text('确认'));
        await tester.pumpAndSettle();
        expect(cash.voidCashBillCalls, 1);
        expect(tester.takeException(), isNull);
        tester.view.viewInsets = FakeViewPadding.zero;
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    },
  );
  testWidgets(
    'cash first field sits below actual navigation bar at zero and large top insets',
    (tester) async {
      for (final top in [0.0, 64.0]) {
        await setSurface(
          tester,
          textScale: 1.5,
          padding: FakeViewPadding(top: top, bottom: 34),
        );
        await pumpLedgerAppWithRepositories(
          tester,
          FakeAppRepositories.empty(),
        );
        await tapTab(tester, '账本');
        await tester.tap(find.text('新增现金账'));
        await tester.pumpAndSettle();
        final dateField = find.byWidgetPredicate(
          (widget) =>
              widget is CupertinoTextField &&
              widget.placeholder == '日期 YYYY-MM-DD',
        );
        final navRect = tester.getRect(find.byType(CupertinoNavigationBar));
        expect(
          tester.getTopLeft(dateField).dy,
          greaterThanOrEqualTo(navRect.bottom),
        );
        expect(
          tester.getTopLeft(dateField).dy,
          lessThanOrEqualTo(navRect.bottom + 16),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    },
  );
  testWidgets(
    'linked cash direct edit is blocked and inconsistent owner link has no navigation',
    (tester) async {
      final bill = CashBill(
        id: 1,
        businessDate: validDraft.businessDate,
        direction: validDraft.direction,
        amount: validDraft.amount,
        scope: validDraft.scope,
        categoryId: 1,
        accountId: 1,
        partyId: null,
        note: 'linked',
        entrySource: EntrySource.manual,
        businessOrigin: BusinessOrigin.purchasePayment,
        linkedType: LinkedBillType.courierRefund,
        linkedId: 42,
        isVoid: false,
        createdAtUtc: DateTime.utc(2026),
        updatedAtUtc: DateTime.utc(2026),
      );
      await pumpLedgerAppWithRepositories(
        tester,
        FakeAppRepositories(
          catalog: RecordingCatalogRepository(),
          cashBills: RecordingCashBillRepository(bills: [bill]),
          ledger: RecordingLedgerRepository(),
          dashboard: RecordingDashboardRepository(),
        ),
      );
      final router = GoRouter.of(
        tester.element(find.byType(CupertinoPageScaffold)),
      );
      router.go('/ledger/cash/1/edit');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('cash-save-button')),
        200,
        scrollable: find.byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        ),
      );
      expect(
        tester
            .widget<CupertinoButton>(
              find.byKey(const ValueKey('cash-save-button')),
            )
            .onPressed,
        isNull,
      );
      router.go('/ledger/cash/1');
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -800));
      await tester.pumpAndSettle();
      expect(find.text('打开所属业务'), findsNothing);
      expect(find.textContaining('关联信息不完整或不一致'), findsOneWidget);
    },
  );
}
