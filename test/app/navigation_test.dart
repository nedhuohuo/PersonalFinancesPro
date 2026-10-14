import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
