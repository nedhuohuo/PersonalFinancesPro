import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:personal_finances_pro/app/presentation/page_widgets.dart';
import 'package:personal_finances_pro/core/domain/local_date.dart';
import 'package:personal_finances_pro/core/domain/money.dart';
import 'package:personal_finances_pro/features/catalog/domain/catalog_models.dart';
import 'package:personal_finances_pro/features/catalog/domain/catalog_repository.dart';
import 'package:personal_finances_pro/features/dashboard/domain/dashboard_repository.dart';
import 'package:personal_finances_pro/features/dashboard/domain/dashboard_snapshots.dart';
import 'package:personal_finances_pro/features/ledger/domain/ledger_models.dart';
import 'ledger_view_models.dart';
import 'package:personal_finances_pro/features/ledger/domain/ledger_repository.dart';

// Shared only by the manual business screens; the scaffold consumes insets once.
class LedgerBusinessPage extends StatefulWidget {
  const LedgerBusinessPage({
    super.key,
    required this.title,
    required this.mutation,
    required this.reload,
    required this.children,
  });
  final String title;
  final LedgerMutation mutation;
  final Future<void> Function() reload;
  final List<Widget> children;

  @override
  State<LedgerBusinessPage> createState() => _LedgerBusinessPageState();
}

class _LedgerBusinessPageState extends State<LedgerBusinessPage> {
  bool? wasActive;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = context.watch<AppTab?>() == AppTab.ledger;
    if (active && wasActive == false) {
      Future.microtask(() {
        if (mounted) widget.mutation.read(widget.reload);
      });
    }
    wasActive = active;
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    resizeToAvoidBottomInset: true,
    navigationBar: CupertinoNavigationBar(
      middle: Text(widget.title),
      transitionBetweenRoutes: false,
    ),
    child: SafeArea(
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(appPadding),
        children: [
          if (widget.mutation.loading || widget.mutation.pending)
            const CupertinoActivityIndicator(),
          if (widget.mutation.error != null)
            InfoCard(title: '提示', body: widget.mutation.error!),
          CupertinoButton(
            onPressed:
                widget.mutation.pending || widget.mutation.loading
                    ? null
                    : () => widget.mutation.read(widget.reload),
            child: const Text('刷新'),
          ),
          ...widget.children.map(
            (child) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: child,
            ),
          ),
        ],
      ),
    ),
  );
}

class BusinessScopeSelector extends StatelessWidget {
  const BusinessScopeSelector({
    super.key,
    required this.catalogs,
    required this.value,
    required this.onChanged,
    this.allowAll = false,
  });
  final BusinessCatalogs catalogs;
  final BusinessScope? value;
  final ValueChanged<BusinessScope?> onChanged;
  final bool allowAll;
  @override
  Widget build(BuildContext context) => LedgerSelectionRow<BusinessScope?>(
    label: allowAll ? '范围筛选' : '业务范围',
    value: value,
    display: catalogs.scopeName,
    values: [
      if (allowAll) null,
      const BusinessScope.public(),
      ...catalogs.shops
          .where((s) => allowAll || s.isActive)
          .map((s) => BusinessScope.shop(s.id)),
    ],
    onChanged: onChanged,
  );
}

class BusinessCashSelectors extends StatelessWidget {
  const BusinessCashSelectors({
    super.key,
    required this.catalogs,
    required this.direction,
    required this.accountId,
    required this.categoryId,
    required this.onAccount,
    required this.onCategory,
    this.prefix = '',
  });
  final BusinessCatalogs catalogs;
  final CashDirection direction;
  final int? accountId;
  final int? categoryId;
  final ValueChanged<int> onAccount;
  final ValueChanged<int> onCategory;
  final String prefix;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      LedgerSelectionRow<int>(
        label: '$prefix账户',
        value: accountId,
        display: catalogs.accountName,
        values:
            catalogs.accounts
                .where((e) => e.isActive)
                .map((e) => e.id)
                .toList(),
        onChanged: onAccount,
      ),
      LedgerSelectionRow<int>(
        label: '$prefix分类',
        value: categoryId,
        display: catalogs.categoryName,
        values:
            catalogs.categories
                .where((e) => e.isActive && e.direction == direction)
                .map((e) => e.id)
                .toList(),
        onChanged: onCategory,
      ),
    ],
  );
}

class BusinessPartySelector extends StatelessWidget {
  const BusinessPartySelector({
    super.key,
    required this.catalogs,
    required this.kind,
    required this.value,
    required this.onChanged,
  });
  final BusinessCatalogs catalogs;
  final PartyKind kind;
  final int? value;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) {
    final label = kind == PartyKind.supplier ? '厂家' : '买家';
    return Column(
      children: [
        LedgerSelectionRow<int>(
          label: label,
          value: value,
          display: catalogs.partyName,
          values:
              catalogs.parties
                  .where((e) => e.isActive && e.kind == kind)
                  .map((e) => e.id)
                  .toList(),
          onChanged: onChanged,
        ),
        CupertinoButton(
          onPressed: () => context.push('/settings/catalog/parties'),
          child: Text('到基础资料新增$label，返回后刷新'),
        ),
      ],
    );
  }
}

class LedgerStatusButton extends StatelessWidget {
  const LedgerStatusButton({
    super.key,
    required this.label,
    required this.mutation,
    required this.write,
    required this.reload,
  });
  final String label;
  final LedgerMutation mutation;
  final Future<void> Function(String) write;
  final Future<void> Function() reload;
  @override
  Widget build(BuildContext context) => CupertinoButton(
    onPressed:
        !mutation.canAct
            ? null
            : () async {
              var reason = '';
              await showCupertinoDialog<void>(
                context: context,
                builder:
                    (dialogContext) => AnimatedBuilder(
                      animation: mutation,
                      builder:
                          (context, _) => PopScope(
                            canPop: !mutation.pending,
                            child: CupertinoAlertDialog(
                              title: Text('$label原因'),
                              content: Column(
                                children: [
                                  LedgerTextField(
                                    label: '原因',
                                    value: reason,
                                    onChanged: (value) => reason = value,
                                  ),
                                  if (mutation.error != null)
                                    Text(mutation.error!),
                                ],
                              ),
                              actions: [
                                CupertinoDialogAction(
                                  onPressed:
                                      mutation.pending
                                          ? null
                                          : () => Navigator.pop(dialogContext),
                                  child: const Text('取消'),
                                ),
                                CupertinoDialogAction(
                                  onPressed:
                                      !mutation.canAct
                                          ? null
                                          : () async {
                                            final committed = await mutation
                                                .submit(() async {
                                                  if (reason.trim().isEmpty) {
                                                    throw const FormatException(
                                                      '请填写原因',
                                                    );
                                                  }
                                                  await write(reason);
                                                }, reload: reload);
                                            if (committed &&
                                                dialogContext.mounted) {
                                              Navigator.pop(dialogContext);
                                            }
                                          },
                                  child: const Text('确认'),
                                ),
                              ],
                            ),
                          ),
                    ),
              );
            },
    child: Text(label),
  );
}

Widget businessCashLink(
  BuildContext context,
  BusinessCatalogs catalogs,
  CashBill bill, {
  required Future<void> Function() onReturn,
}) => CupertinoButton(
  onPressed: () async {
    await context.push('/ledger/cash/${bill.id}');
    if (context.mounted) await onReturn();
  },
  child: Text(
    '${bill.businessDate.value} · ${catalogs.categoryName(bill.categoryId)} · ${catalogs.accountName(bill.accountId)}${bill.partyId == null ? '' : ' · 往来方 ${catalogs.partyName(bill.partyId!)}'} · ${catalogs.scopeName(bill.scope)} · ${bill.amount.format()}${bill.isVoid ? '（已作废）' : ''} · ${bill.note}',
  ),
);

class LedgerDetailPage extends StatefulWidget {
  const LedgerDetailPage({super.key});
  @override
  State<LedgerDetailPage> createState() => _LedgerDetailPageState();
}

class _LedgerDetailPageState extends State<LedgerDetailPage> {
  final mutation = LedgerMutation();
  final catalogs = BusinessCatalogs();
  late String start =
      '${LocalDate.todayLocal(DateTime.now()).value.substring(0, 7)}-01';
  late String end = LocalDate.todayLocal(DateTime.now()).value;
  BusinessScope? scope;
  LedgerDetailSnapshot? snapshot;
  String? loadedPeriod;
  @override
  void initState() {
    super.initState();
    Future.microtask(() => mutation.read(load));
  }

  Future<void> load() async {
    final from = LocalDate.parse(start.trim());
    final to = LocalDate.parse(end.trim());
    if (from.value.compareTo(to.value) > 0) {
      throw const FormatException('开始日期不能晚于结束日期');
    }
    final catalog = context.read<CatalogRepository>();
    final dashboard = context.read<DashboardRepository>();
    final selectedScope = scope;
    await catalogs.load(catalog);
    final value = await dashboard.loadLedgerDetailSnapshot(
      startDate: from,
      endDate: to,
      scope: selectedScope,
    );
    snapshot = value;
    loadedPeriod =
        '${from.value} 至 ${to.value} · ${catalogs.scopeName(selectedScope)}';
  }

  @override
  void dispose() {
    mutation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: mutation,
    builder: (context, _) {
      final s = snapshot;
      return LedgerBusinessPage(
        title: '账本明细',
        mutation: mutation,
        reload: load,
        children: [
          LedgerTextField(
            label: '开始日期 YYYY-MM-DD',
            value: start,
            onChanged: (v) => start = v,
          ),
          LedgerTextField(
            label: '结束日期 YYYY-MM-DD',
            value: end,
            onChanged: (v) => end = v,
          ),
          BusinessScopeSelector(
            catalogs: catalogs,
            value: scope,
            allowAll: true,
            onChanged: (v) => setState(() => scope = v),
          ),
          CupertinoButton.filled(
            onPressed: mutation.loading ? null : () => mutation.read(load),
            child: const Text('查看期间'),
          ),
          if (s != null) ...[
            InfoCard(
              title: loadedPeriod!,
              body:
                  '现金收入 ${s.cashIncome.format()}\n现金支出 ${s.cashExpense.format()}\n现金净额 ${s.cashNet.format()}\n不含平台主要收入，不代表利润或亏损',
            ),
            InfoCard(
              title: '期间采购',
              body:
                  '有效 ${s.purchaseEffective.format()}\n实付净额 ${s.purchasePaidNet.format()}\n待付 ${s.purchasePayable.format()}',
            ),
            InfoCard(
              title: '期间问题件',
              body:
                  '收入 ${s.resaleIncome.format()}\n费用 ${s.resaleFees.format()}\n净回收 ${s.resaleNetRecovery.format()}',
            ),
            InfoCard(
              title: '期间快递',
              body:
                  '充值 ${s.courierTopUp.format()}\n消耗 ${s.courierConsume.format()}（不产生第二笔现金支出）',
            ),
            if (s.globalCourierRecordedBalance != null)
              InfoCard(
                title: '当前全局快递预付余额（非期间、非单店资产）',
                body: s.globalCourierRecordedBalance!.format(),
              ),
          ],
        ],
      );
    },
  );
}

class ManualLedgerOverview extends StatefulWidget {
  const ManualLedgerOverview({super.key, required this.onReturn});
  final Future<void> Function() onReturn;
  @override
  State<ManualLedgerOverview> createState() => _ManualLedgerOverviewState();
}

class _ManualLedgerOverviewState extends State<ManualLedgerOverview> {
  final mutation = LedgerMutation();
  final catalogs = BusinessCatalogs();
  BusinessScope? scope;
  bool includeVoid = false, wasActive = false;
  List<Purchase> purchases = [];
  List<SupplierOpeningDebt> debts = [];
  List<ProblemResaleDetail> resales = [];
  List<CourierAccount> couriers = [];
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = context.watch<AppTab?>() == AppTab.ledger;
    if (active && !wasActive) mutation.read(load);
    wasActive = active;
  }

  Future<void> load() async {
    final ledger = context.read<LedgerRepository>();
    final catalog = context.read<CatalogRepository>();
    await catalogs.load(catalog);
    final p = await ledger.listPurchases(
      PurchaseFilter(scope: scope, includeVoid: includeVoid),
    );
    final d = await ledger.listSupplierOpeningDebts(
      scope: scope,
      includeVoid: includeVoid,
    );
    final r = await ledger.listProblemResales(
      ProblemResaleFilter(scope: scope, includeVoid: includeVoid),
    );
    final c = await ledger.listCourierAccounts(includeInactive: true);
    purchases = p;
    debts = d;
    // ponytail: one typed detail read per resale; add repository list totals if list size makes this costly.
    resales = await Future.wait(
      r.map((e) => ledger.getProblemResaleDetail(e.id)),
    );
    couriers = c;
  }

  @override
  void dispose() {
    mutation.dispose();
    super.dispose();
  }

  Future<void> open(String path) async {
    await context.push(path);
    if (!mounted) return;
    await mutation.read(load);
    if (mounted) await widget.onReturn();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: mutation,
    builder:
        (context, _) => InfoCard(
          title: '手动经营业务',
          body: '采购记录欠款；现金账不代表利润。',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final entry
                  in {
                    'purchases/new': '采购单',
                    'opening-debts/new': '期初欠款',
                    'resales/new': '问题件转卖',
                    'courier/accounts/new': '新增快递钱包',
                    'detail': '账本明细',
                  }.entries)
                CupertinoButton(
                  onPressed: () => open('/ledger/${entry.key}'),
                  child: Text(entry.value),
                ),
              BusinessScopeSelector(
                catalogs: catalogs,
                value: scope,
                allowAll: true,
                onChanged: (v) {
                  if (mutation.loading) return;
                  setState(() => scope = v);
                  mutation.read(load);
                },
              ),
              CupertinoButton(
                onPressed:
                    mutation.loading
                        ? null
                        : () {
                          setState(() => includeVoid = !includeVoid);
                          mutation.read(load);
                        },
                child: Text(includeVoid ? '隐藏作废业务' : '包含作废业务'),
              ),
              if (mutation.error != null) Text(mutation.error!),
              CupertinoButton(
                onPressed: mutation.loading ? null : () => mutation.read(load),
                child: const Text('刷新业务'),
              ),
              for (final p in purchases)
                CupertinoButton(
                  onPressed: () => open('/ledger/purchases/${p.id}'),
                  child: Text(
                    '采购 #${p.id} · ${catalogs.partyName(p.supplierId)} · ${p.businessDate.value} · ${catalogs.scopeName(p.scope)} · 有效 ${p.position.effectiveTotal.format()} · 已付 ${p.position.paidNet.format()} · 待付 ${p.position.payable.format()}${p.isVoid ? '（已作废）' : ''}',
                  ),
                ),
              for (final d in debts)
                CupertinoButton(
                  onPressed: () => open('/ledger/opening-debts/${d.id}'),
                  child: Text(
                    '期初欠款 #${d.id} · ${catalogs.partyName(d.supplierId)} · ${d.businessDate.value} · ${catalogs.scopeName(d.scope)} · 原额 ${d.amount.format()} · 已付 ${d.paid.format()}${d.isVoid ? '（已作废）' : ''}',
                  ),
                ),
              for (final detail in resales)
                CupertinoButton(
                  onPressed: () => open('/ledger/resales/${detail.resale.id}'),
                  child: Text(
                    '转卖 #${detail.resale.id} · ${detail.resale.description} · ${detail.resale.businessDate.value} · ${catalogs.scopeName(detail.resale.scope)} · 收入 ${detail.resale.incomeAmount.format()} · 费用 ${Money.sumCents(detail.fees.map((e) => e.amount.cents)).format()} · 净回收 ${detail.netRecovery.format()}${detail.resale.isVoid ? '（已作废）' : ''}',
                  ),
                ),
              const Text('全局快递钱包（不按店铺拆分余额）'),
              for (final c in couriers)
                CupertinoButton(
                  onPressed: () => open('/ledger/courier/${c.id}'),
                  child: Text(
                    '${c.name} · 全局余额 ${c.recordedBalance.format()}${c.isActive ? '' : '（已停用）'}',
                  ),
                ),
            ],
          ),
        ),
  );
}
