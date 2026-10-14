import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_finances_pro/app/app_theme.dart';
import 'package:personal_finances_pro/app/presentation/ai_page.dart';
import 'package:personal_finances_pro/app/presentation/dashboard_page.dart';
import 'package:personal_finances_pro/app/presentation/ledger_page.dart';
import 'package:personal_finances_pro/app/presentation/settings_page.dart';

class ShopLedgerApp extends StatefulWidget {
  const ShopLedgerApp({super.key});

  @override
  State<ShopLedgerApp> createState() => _ShopLedgerAppState();
}

class _ShopLedgerAppState extends State<ShopLedgerApp> {
  late final GoRouter _router = createRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoApp.router(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.data,
      routerConfig: _router,
    );
  }
}

GoRouter createRouter() {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/home', builder: (_, __) => const DashboardPage()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/ledger', builder: (_, __) => const LedgerPage()),
            ],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/ai', builder: (_, __) => const AiPage())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (_, __) => const SettingsPage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    final background = CupertinoDynamicColor.resolve(
      CupertinoColors.systemGroupedBackground,
      context,
    );
    final branch =
        keyboardVisible
            ? navigationShell
            : MediaQuery.removePadding(
              context: context,
              removeBottom: true,
              child: navigationShell,
            );

    return ColoredBox(
      color: background,
      child: Column(
        children: [
          Expanded(child: branch),
          if (!keyboardVisible)
            CupertinoTabBar(
              currentIndex: navigationShell.currentIndex,
              onTap:
                  (index) => navigationShell.goBranch(
                    index,
                    initialLocation: index == navigationShell.currentIndex,
                  ),
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(CupertinoIcons.house),
                  activeIcon: Icon(CupertinoIcons.house_fill),
                  label: '首页',
                ),
                BottomNavigationBarItem(
                  icon: Icon(CupertinoIcons.book),
                  activeIcon: Icon(CupertinoIcons.book_fill),
                  label: '账本',
                ),
                BottomNavigationBarItem(
                  icon: Icon(CupertinoIcons.chat_bubble),
                  activeIcon: Icon(CupertinoIcons.chat_bubble_fill),
                  label: 'AI记账',
                ),
                BottomNavigationBarItem(
                  icon: Icon(CupertinoIcons.settings),
                  activeIcon: Icon(CupertinoIcons.settings_solid),
                  label: '设置',
                ),
              ],
            ),
        ],
      ),
    );
  }
}
