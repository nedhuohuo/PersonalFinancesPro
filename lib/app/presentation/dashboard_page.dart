import 'package:flutter/cupertino.dart';
import 'package:personal_finances_pro/app/presentation/page_widgets.dart';
import 'package:personal_finances_pro/core/domain/money.dart';
import 'package:personal_finances_pro/features/dashboard/domain/dashboard_repository.dart';
import 'package:personal_finances_pro/features/dashboard/presentation/dashboard_view_model.dart';
import 'package:personal_finances_pro/features/ledger/domain/ledger_models.dart';
import 'package:provider/provider.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  DashboardViewModel? _viewModel;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _viewModel ??= DashboardViewModel(
      dashboardRepository: context.read<DashboardRepository>(),
    )..reload();
  }

  @override
  void dispose() {
    _viewModel?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = _viewModel;
    if (viewModel == null) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: viewModel,
      builder: (context, _) {
        final snapshot = viewModel.snapshot;
        return AppSliverPage(
          title: '平台外经营账本',
          compactTitle: '首页',
          slivers: [
            paddedSliver([
              if (viewModel.isLoading) const _LoadingCard(),
              if (viewModel.errorMessage != null)
                InfoCard(title: '读取失败', body: viewModel.errorMessage!),
              _MoneyCard(title: '本月实付支出', money: snapshot.monthCashExpense),
              _MoneyCard(title: '当前厂家待付款', money: snapshot.supplierPayable),
              _MoneyCard(title: '本月问题件回收', money: snapshot.monthResaleIncome),
              InfoCard(
                title: '最近账目',
                body:
                    snapshot.recentBills.isEmpty
                        ? '暂无现金账。'
                        : '最近 ${snapshot.recentBills.length} 条现金账。',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final bill in snapshot.recentBills.take(5))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '${bill.businessDate.value} ${_directionLabel(bill)} ${bill.amount.format()}',
                        ),
                      ),
                  ],
                ),
              ),
              const InfoCard(
                title: '范围说明',
                body: '本 App 只记录平台外经营流水；不含平台订单收入，不把现金差额标成利润。',
              ),
            ]),
          ],
        );
      },
    );
  }
}

class _MoneyCard extends StatelessWidget {
  const _MoneyCard({required this.title, required this.money});

  final String title;
  final Money money;

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      title: title,
      body: '来自本地账本的实际数据。',
      child: Text(
        money.format(),
        style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
          fontSize: 38,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.2,
          color: appColor(context, CupertinoColors.label),
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) =>
      const InfoCard(title: '正在读取', body: '正在加载本地账本。');
}

String _directionLabel(CashBill bill) =>
    bill.direction.name == 'income' ? '收入' : '支出';
