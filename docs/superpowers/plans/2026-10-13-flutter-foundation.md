# Flutter Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans for inline execution, or superpowers:subagent-driven-development only after the operator explicitly authorizes delegation. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 建立真正可运行的 Flutter Android/iOS 工程、Apple 风格 Cupertino 四入口和纯 Dart 金额规则，验证 Clean 依赖边界；这个阶段不声称完成本地账本或真实 AI 服务。

**Architecture:** 按功能组织 presentation/domain/data，只为实际职责建立文件。app 负责路由、主题和构造器依赖装配；复杂记账业务在后续账本阶段实现，数据库及 HTTP 不能进入领域层。UI 按已产出的 OpenDesign 规则实现，但不嵌入网页原型。

**Tech Stack:** Flutter stable 3.29.2 / 自带 Dart 3.7.2、Cupertino、cupertino_icons、provider、go_router、flutter_lints、flutter_test、GitHub Actions。

**Spec:** `docs/superpowers/specs/2026-10-13-shop-ledger-design.md`；UI 依据 `docs/ui/UI_DESIGN.md`。

## Global Constraints

- Flutter 开发，支持 Android 与 iOS。
- 应用标识使用 `dev.nedhuohuo.personalfinancespro`。
- 首版以人民币为唯一货币。
- 金额以整数分存储和计算，不用 `double` 处理金额；单笔及汇总金额不得超过 `9,000,000,000,000,000` 分，越界拒绝操作。
- 金额输入从十进制字符串精确解析，最多两位小数；超出精度要求用户改正，不静默舍入。
- 平台外现金净额不能称为店铺利润；首页以实付支出、当前待付款和问题件回收为重点。
- 用户授权 Apple 风格，遵循 `docs/ui/UI_DESIGN.md`，不沿用旧 Material 原型。
- 系统安全区使用运行时数据而非写死高度；顶部、底部和键盘各有单一负责者，正常布局不得遮挡最后一行或输入栏。
- domain 是纯 Dart，不导入 Flutter、SQLite、HTTP 或插件。
- 不提交 API Key、真实账本、数据库、备份、签名文件或本机绝对 SDK 路径。
- 在用户选定的当前目录开发分支 `feat/flutter-ledger` 工作，不直接修改 main，不创建额外 worktree。
- 不自动接受 Android 许可，不修改全局 Flutter/Dart/Java 配置；签名及上架不在本阶段范围。

---

## Scope split and coverage

已批准的完整产品包含工程、账本、备份统计和 AI 等子系统，因此按独立可验证阶段实施。本计划只负责工程基础。

| 阶段 | 独立交付与业务要求 |
|---|---|
| 工程基础（本计划） | 稳定 SDK、Android/iOS 工程、主题和四入口、精确金额规则、分析/测试/CI、真实空状态 |
| 本地账本 | 基础资料及停用、现金收支及作废恢复、关联审计、采购明细与部分付款、厂家退款及期初欠款、问题件二次销售、快递预付事件、外键/事务/迁移 |
| 数据管理 | 各统计口径、CSV 转义及公式注入防护、20 MiB 完整备份校验、事务恢复、系统备份排除与敏感数据提示 |
| AI | HTTPS 配置和安全存储、接收主机确认、发送同意、最少必要上下文、消息式对话及核心意图、Markdown 表格与本地校验、补问/修订、按钮/文字幂等确认和原消息状态回写、超时取消及错误回退 |
| 双端验收 | 真实设备/模拟器离线流程、数据库迁移及恢复、安全存储和文件操作、Android 构建及 iOS 无签名构建 |

后续每个阶段使用单独计划和对应的红绿测试；工程基础完成不代表这些业务已完成。所有完整产品要求继续以已批准设计文档为准。

## File map

- Generated: `android/`、`ios/`、`.metadata`、`pubspec.yaml`、`pubspec.lock`、`analysis_options.yaml`。
- Create: `.flutter-version`（内容 `3.29.2`）、`lib/main.dart`、`lib/app/app.dart`、`lib/app/router.dart`、`lib/app/theme.dart`。
- Create: `lib/app/shell.dart`（单一 CupertinoTabBar + 路由子页面）、`lib/features/dashboard/presentation/dashboard_page.dart`、`lib/features/ledger/presentation/ledger_page.dart`、`lib/features/ai_bookkeeping/presentation/ai_page.dart`、`lib/features/catalog/presentation/settings_page.dart`。
- Create: `lib/core/domain/money.dart`、`test/core/domain/money_test.dart`、`test/app/navigation_test.dart`、`tool/check_domain_boundaries.dart`。
- Create: `.github/workflows/flutter.yml`；update `.gitignore` 与 `README.md`。

## Task 1: Reproducible SDK and native project

**Interfaces:** Produces the generated `personal_finances_pro` Dart package and native targets with the approved application ID. Local commands use `$FLUTTER_SDK/bin/flutter` and `$FLUTTER_SDK/bin/dart`, never the unrelated standalone Dart on PATH.

- [ ] Inspect the existing stable 3.29.2 SDK folder and run its complete version probe. This version is already present locally; it is not claimed to be the latest upstream stable release. Verify version `3.29.2`, channel `stable`, Dart `3.7.2` and cache completeness. If unusable, stop and configure a project-local stable SDK with the user rather than silently falling back to the master checkout.
- [ ] Set `FLUTTER_SDK` only for this session. Run `"$FLUTTER_SDK/bin/flutter" doctor -v`; capture each platform blocker separately. Current Android Studio uses JBR 25; verify compatibility with the generated Gradle wrapper before building. If incompatible, stop and arrange a per-project compatible JDK with the user rather than changing global Java or claiming an Android build succeeded.
- [ ] Create the native project without overwriting the existing README, LICENSE, docs or ignore rules:

```sh
SCAFFOLD="$(mktemp -d /tmp/personal-finances-pro.XXXXXX)"
"$FLUTTER_SDK/bin/flutter" create --empty --platforms=android,ios \
  --org=dev.nedhuohuo --project-name=personal_finances_pro \
  --no-pub "$SCAFFOLD"
for item in android ios lib .metadata pubspec.yaml analysis_options.yaml; do
  test ! -e "$item" || exit 1
  cp -R "$SCAFFOLD/$item" "$item"
done
```

Do not copy the generated README/LICENSE/gitignore over existing files. Do not copy generated tests before deciding their replacement. Keep the temporary scaffold out of Git.

- [ ] Set the Android namespace/applicationId and iOS Runner product bundle identifier to `dev.nedhuohuo.personalfinancespro`; use a separate `.RunnerTests` suffix for the iOS test target. Set the display name to `网店账本` on both platforms.
- [ ] Write `.flutter-version` containing `3.29.2`. Add provider/go_router and the standard Cupertino icon font through the pinned SDK so pub selects SDK-compatible versions and commit `pubspec.lock`:

```sh
"$FLUTTER_SDK/bin/flutter" pub add provider go_router cupertino_icons
"$FLUTTER_SDK/bin/flutter" pub get
```

- [ ] Preserve required lint configuration, analyze generated platform settings and verify native application identifiers. Do not report iOS success if CocoaPods or Simulator runtimes are missing.

## Task 2: Exact money domain rule

**Files:** `lib/core/domain/money.dart`, `test/core/domain/money_test.dart`.

**Interfaces:** Produces immutable `Money.fromCents(int cents)`, `Money.parsePositive(String input)`, `Money.zero`, `int get cents`, `String format()` and `Money add(Money other)`.

- [ ] Write failing tests before adding Money:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finances_pro/core/domain/money.dart';

void main() {
  test('parses decimal input without losing cents', () {
    expect(Money.parsePositive('18.00').cents, 1800);
    expect(Money.parsePositive('0.01').cents, 1);
    expect(Money.parsePositive('90000000000000.00').cents,
        9000000000000000);
  });
  test('rejects excessive precision and out-of-range input', () {
    for (final input in ['18.005', '-1', '0', '', '1e3',
      '90000000000000.01']) {
      expect(() => Money.parsePositive(input), throwsFormatException);
    }
  });
  test('formats signed integer cents and guards aggregate overflow', () {
    expect(Money.fromCents(-296000).format(), '-2,960.00');
    expect(Money.fromCents(1).format(), '0.01');
    expect(() => Money.fromCents(9000000000000000).add(
      Money.fromCents(1)), throwsRangeError);
  });
}
```

- [ ] Run `"$FLUTTER_SDK/bin/flutter" test test/core/domain/money_test.dart`; confirm expected missing implementation failure.
- [ ] Implement `Money` without Flutter or plugin imports:

```dart
final class Money {
  const Money._(this.cents);
  static const maxCents = 9000000000000000;
  static const zero = Money._(0);
  final int cents;

  factory Money.fromCents(int cents) {
    if (cents < -maxCents || cents > maxCents) {
      throw RangeError.range(cents, -maxCents, maxCents, 'cents');
    }
    return Money._(cents);
  }

  factory Money.parsePositive(String input) {
    final match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$')
        .firstMatch(input.trim());
    if (match == null) throw const FormatException('金额最多两位小数');
    final value = BigInt.parse(match[1]!) * BigInt.from(100) +
        BigInt.parse((match[2] ?? '').padRight(2, '0'));
    if (value <= BigInt.zero || value > BigInt.from(maxCents)) {
      throw const FormatException('金额超出允许范围');
    }
    return Money._(value.toInt());
  }

  Money add(Money other) => Money.fromCents(cents + other.cents);

  String format() {
    final digits = cents.abs().toString().padLeft(3, '0');
    final whole = digits.substring(0, digits.length - 2)
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
    return '${cents < 0 ? '-' : ''}$whole.${digits.substring(digits.length - 2)}';
  }
}
```

- [ ] Run the test and confirm it passes; add unit checks for zero formatting and invalid signed limits if implementation changes their behavior.
- [ ] Commit the domain rule and its tests independently.

## Task 3: Cupertino shell and honest empty pages

**Files:** all `lib/app/` files, four presentation pages and `test/app/navigation_test.dart`.

**Interfaces:** Produces `ShopLedgerApp()` and `createRouter()` with routes `/home`, `/ledger`, `/ai`, `/settings`; `AppTheme.data` with system-resolving Cupertino colors; no global repository or fake transaction data in production.

- [ ] Write navigation behavior tests first:

```dart
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finances_pro/app/app.dart';

void main() {
  testWidgets('four-entry navigation preserves honest feature states',
      (tester) async {
    await tester.pumpWidget(const ShopLedgerApp());
    await tester.pumpAndSettle();
    expect(find.text('平台外经营账本'), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(CupertinoTabBar),
        matching: find.text('账本')));
    await tester.pumpAndSettle();
    expect(find.text('还没有账目'), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(CupertinoTabBar),
        matching: find.text('AI记账')));
    await tester.pumpAndSettle();
    expect(find.text('AI功能尚未接入'), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(CupertinoTabBar),
        matching: find.text('设置')));
    await tester.pumpAndSettle();
    expect(find.text('数据保存在本机'), findsOneWidget);
  });
}
```

- [ ] Run the test; confirm expected missing ShopLedgerApp failure.
- [ ] Implement `CupertinoApp.router` with system-resolving Cupertino theme. Use `StatefulShellRoute.indexedStack` and one Column-based shell hosting the branch navigator and `CupertinoTabBar` in normal layout:

```dart
StatefulShellRoute.indexedStack(
  builder: (context, state, shell) => AppShell(navigationShell: shell),
  branches: [
    StatefulShellBranch(routes: [GoRoute(path: '/home',
      builder: (_, __) => const DashboardPage())]),
    StatefulShellBranch(routes: [GoRoute(path: '/ledger',
      builder: (_, __) => const LedgerPage())]),
    StatefulShellBranch(routes: [GoRoute(path: '/ai',
      builder: (_, __) => const AiPage())]),
    StatefulShellBranch(routes: [GoRoute(path: '/settings',
      builder: (_, __) => const SettingsPage())]),
  ],
)
```

Set `initialLocation: '/home'`. `ShopLedgerApp` owns its router in State, creates it once and disposes it; do not rebuild a router on theme changes or use a global singleton. `AppShell` calls `navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex)` on selection. Use `CupertinoIcons` home/book/chat/settings and labelled `BottomNavigationBarItem` tabs. Do not repeat the same `navigationShell` in four `CupertinoTabScaffold.tabBuilder` children.

- [ ] Implement `AppTheme.data` with `CupertinoThemeData`, primaryColor `CupertinoColors.systemBlue`, scaffoldBackgroundColor `CupertinoColors.systemGroupedBackground`, dynamic label/separator colors and native typography; leave brightness system-resolving. Use large titles, grouped rounded surfaces, padding 16 and minimum button targets 48. Ordinary expenditure is neutral, not alarm red.
- [ ] Define safe-area ownership: each branch's Cupertino page/navigation bar handles top inset. The shell's CupertinoTabBar handles bottom inset once, without an outer bottom SafeArea; while tabs are visible, `MediaQuery.removePadding(removeBottom: true)` removes the already-consumed bottom padding from the branch subtree. Include horizontal insets where content needs them, not a second top SafeArea under a bar.
- [ ] When `MediaQuery.viewInsetsOf(context).bottom > 0`, hide the tab bar, give the branch the remaining full viewport and let its `CupertinoPageScaffold(resizeToAvoidBottomInset: true)` avoid the keyboard exactly once. Do not additionally subtract viewInsets with manual padding or a second resizing shell. Focused fields/message composer stay above the keyboard; body scrolls to reveal focus.
- [ ] Implement honest pages: dashboard says `平台外经营账本`, prioritizes `本月实付支出` and explains the missing ledger rather than pretending to compute profits; ledger says `还没有账目` and identifies its not-yet-connected state. AI shows the conversation layout with `AI功能尚未接入` and disabled send/confirmation; do not expose an enabled Key field or ship the prototype's scripted intents/records. Settings says `数据保存在本机` with no fake backup button. Real conversation behavior belongs to the AI stage after local persistence exists.
- [ ] Add Widget checks at widths 320/390/430 and text scale 1.5, no layout exceptions or clipped actionable content; reset physicalSize, devicePixelRatio and platformDispatcher text scale via addTearDown.
- [ ] Add `tester.view.padding`/`viewPadding` scenarios top/bottom 0/0, 24/24 and 54/34. Check top content and tab hit rectangles stay out of system regions and the last row can scroll clear; retain actual tab height rather than assuming 50 plus inset by hand.
- [ ] Simulate keyboard with `tester.view.viewInsets = const FakeViewPadding(bottom: 300)` and padding reflecting the covered bottom safe area. Verify tab bar hidden, AI input above `logicalHeight - 300`, focused controls scroll into view and no double 300 inset. Restore all values via addTearDown and reopen tabs after keyboard close. Widget simulations are not true device validation.
- [ ] Run all Widget/domain tests, analyze and format. Commit the native shell as an independently runnable stage.

## Task 4: Boundaries, CI and documentation

**Files:** `tool/check_domain_boundaries.dart`, `.github/workflows/flutter.yml`, `.gitignore`, `README.md`.

**Interfaces:** Produces a nonzero exit code for forbidden domain imports; CI reads `.flutter-version`, checks format/analyze/tests on push/PR and builds Android on main.

- [ ] Implement a Dart stdlib check scanning files in `lib/**/domain/` and `lib/core/domain/`. For each import/export reject any `package:` dependency except `package:personal_finances_pro/` paths that themselves stay in domain; relative paths must resolve inside a domain folder. Permit `dart:` libraries. It must reject a deliberately injected Flutter import during a temporary fixture check, then pass the actual sources.
- [ ] Add GitHub Actions trigger `push` and `pull_request`, read `.flutter-version` into step output, install that exact Flutter stable version, then run:

```sh
flutter pub get
dart format --output=none --set-exit-if-changed lib test tool
dart run tool/check_domain_boundaries.dart
flutter analyze
flutter test
```

Add `flutter build apk --debug` as a separate step only when `github.ref == 'refs/heads/main'`, matching the product CI scope.

Use `actions/checkout@v4` and `subosito/flutter-action@v2`, with `permissions: contents: read`. Do not inject private keys or real AI configuration. Native dependency lockfiles remain tracked.

- [ ] Update README with SDK version, explicit SDK command usage, feature completion matrix, local UI prototype serving command and verification commands. Keep future ledger/backup/AI states marked as not implemented.
- [ ] Verify `.gitignore` still excludes credentials, databases, backups and generated native caches after scaffolding; do not erase existing privacy rules.
- [ ] Run local format, boundary check, analyze and tests. Attempt Android debug build only with required licenses accepted by the user; iOS build only after required tools are installed. Report unavailable builds as blocked, never passed.
- [ ] Push the development branch to the existing public origin. Native commits never overwrite main history.

## Handoff

UI direction is Apple-style under the user's visual-design authorization; OpenDesign now demonstrates spending-first pages and a message-based AI draft workflow. Dynamic system bars and keyboards still require native Widget and device verification. After this plan, the next plan is the local-ledger stage, whose acceptance requires actual persisted records, transactional procurement/payment and prepaid-wallet rules; a screen shell does not satisfy it.

Execution options: current-session inline execution (no additional delegation), or per-task subagents only if the user explicitly requests them.
