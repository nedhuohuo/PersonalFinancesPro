import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_finances_pro/app/app_dependencies.dart';
import 'package:personal_finances_pro/app/app_theme.dart';
import 'package:personal_finances_pro/app/presentation/ai_page.dart';
import 'package:personal_finances_pro/app/presentation/dashboard_page.dart';
import 'package:personal_finances_pro/app/presentation/ledger_page.dart';
import 'package:personal_finances_pro/app/presentation/page_widgets.dart';
import 'package:personal_finances_pro/app/presentation/settings_page.dart';
import 'package:personal_finances_pro/features/catalog/domain/catalog_repository.dart';
import 'package:personal_finances_pro/features/catalog/presentation/catalog_pages.dart';
import 'package:personal_finances_pro/features/dashboard/domain/dashboard_repository.dart';
import 'package:personal_finances_pro/features/ledger/domain/cash_bill_repository.dart';
import 'package:personal_finances_pro/features/ledger/domain/ledger_repository.dart';
import 'package:personal_finances_pro/features/ledger/presentation/cash_bill_pages.dart';
import 'package:provider/provider.dart';

class ShopLedgerApp extends StatefulWidget {
  const ShopLedgerApp({
    super.key,
    AppDependenciesBootstrap? dependenciesBootstrap,
  }) : dependenciesBootstrap =
           dependenciesBootstrap ?? const DefaultAppDependenciesBootstrap();

  final AppDependenciesBootstrap dependenciesBootstrap;

  @override
  State<ShopLedgerApp> createState() => _ShopLedgerAppState();
}

class _ShopLedgerAppState extends State<ShopLedgerApp> {
  late Future<AppDependencies> _dependenciesFuture;
  AppDependencies? _dependencies;
  GoRouter? _router;

  @override
  void initState() {
    super.initState();
    _dependenciesFuture = widget.dependenciesBootstrap.open();
  }

  @override
  void dispose() {
    _router?.dispose();
    final dependencies = _dependencies;
    if (dependencies == null) {
      _dependenciesFuture.then((value) => value.close(), onError: (_) {});
    } else {
      dependencies.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppDependencies>(
      future: _dependenciesFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _BootstrapErrorApp(
            error: snapshot.error.toString(),
            onRetry: () {
              setState(() {
                _dependenciesFuture = widget.dependenciesBootstrap.open();
              });
            },
          );
        }
        final dependencies = snapshot.data;
        if (dependencies == null) {
          return const CupertinoApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.data,
            home: CupertinoPageScaffold(
              child: Center(child: CupertinoActivityIndicator()),
            ),
          );
        }
        _dependencies ??= dependencies;
        _router ??= createRouter();
        return MultiProvider(
          providers: [
            Provider<CatalogRepository>.value(
              value: dependencies.catalogRepository,
            ),
            Provider<CashBillRepository>.value(
              value: dependencies.cashBillRepository,
            ),
            Provider<LedgerRepository>.value(
              value: dependencies.ledgerRepository,
            ),
            Provider<DashboardRepository>.value(
              value: dependencies.dashboardRepository,
            ),
          ],
          child: CupertinoApp.router(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.data,
            routerConfig: _router!,
          ),
        );
      },
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
              GoRoute(
                path: '/ledger',
                builder: (_, __) => const LedgerPage(),
                routes: [
                  GoRoute(
                    path: 'cash/new',
                    builder: (_, __) => const CashBillFormPage(),
                  ),
                  GoRoute(
                    path: 'cash/:id',
                    builder:
                        (_, state) => CashBillDetailPage(
                          id: int.parse(state.pathParameters['id']!),
                        ),
                  ),
                  GoRoute(
                    path: 'cash/:id/edit',
                    builder:
                        (_, state) => CashBillFormPage(
                          id: int.parse(state.pathParameters['id']!),
                        ),
                  ),
                ],
              ),
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
                routes: [
                  GoRoute(
                    path: 'catalog/:kind',
                    builder:
                        (_, state) => CatalogPage(
                          kind: catalogKindFromPath(
                            state.pathParameters['kind']!,
                          ),
                        ),
                  ),
                ],
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
          Expanded(
            child: Provider<AppTab>.value(
              value: AppTab.values[navigationShell.currentIndex],
              child: branch,
            ),
          ),
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

class _BootstrapErrorApp extends StatelessWidget {
  const _BootstrapErrorApp({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.data,
      home: CupertinoPageScaffold(
        navigationBar: const CupertinoNavigationBar(middle: Text('账本启动失败')),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(appPadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(error, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  CupertinoButton.filled(
                    onPressed: onRetry,
                    child: const Text('重试'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
