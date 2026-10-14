import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_finances_pro/app/presentation/page_widgets.dart';
import 'package:personal_finances_pro/features/catalog/domain/catalog_models.dart';
import 'package:personal_finances_pro/features/catalog/domain/catalog_repository.dart';
import 'package:personal_finances_pro/features/ledger/domain/cash_bill_repository.dart';
import 'package:personal_finances_pro/features/ledger/domain/ledger_models.dart';
import 'package:personal_finances_pro/features/ledger/presentation/ledger_view_models.dart';
import 'package:provider/provider.dart';

class LedgerPage extends StatefulWidget {
  const LedgerPage({super.key});

  @override
  State<LedgerPage> createState() => _LedgerPageState();
}

class _LedgerPageState extends State<LedgerPage> {
  CashLedgerViewModel? _viewModel;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _viewModel ??= CashLedgerViewModel(
      cashBillRepository: context.read<CashBillRepository>(),
      catalogRepository: context.read<CatalogRepository>(),
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
      builder:
          (context, _) => AppSliverPage(
            title: '账本',
            slivers: [
              paddedSliver([
                CupertinoButton.filled(
                  key: const ValueKey('new-cash-bill-button'),
                  onPressed: () async {
                    final changed = await context.push<bool>(
                      '/ledger/cash/new',
                    );
                    if (changed == true) await viewModel.reload();
                  },
                  child: const Text('新增现金账'),
                ),
                _FilterCard(viewModel: viewModel),
                if (viewModel.isLoading)
                  const InfoCard(title: '正在读取', body: '正在加载现金账。'),
                if (viewModel.errorMessage != null)
                  InfoCard(title: '读取失败', body: viewModel.errorMessage!),
                if (!viewModel.isLoading && viewModel.bills.isEmpty)
                  const InfoCard(title: '还没有账目', body: '当前筛选下没有现金账，金额为 0.00。'),
                for (final bill in viewModel.bills)
                  _CashBillCard(viewModel: viewModel, bill: bill),
                const InfoCard(title: '采购单', body: 'Task5 接入采购单详情和修正操作。'),
                const InfoCard(title: '快递预付', body: 'Task5 接入快递预付详情和修正操作。'),
              ]),
            ],
          ),
    );
  }
}

class _FilterCard extends StatelessWidget {
  const _FilterCard({required this.viewModel});

  final CashLedgerViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      title: '现金账筛选',
      body: '按日期、店铺、分类、往来方和备注筛选。',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: CupertinoTextField(
                  placeholder: '开始日期',
                  onChanged: (value) => viewModel.startDateText = value,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: CupertinoTextField(
                  placeholder: '结束日期',
                  onChanged: (value) => viewModel.endDateText = value,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          CupertinoTextField(
            placeholder: '备注包含',
            onChanged: (value) => viewModel.noteQueryText = value,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: CupertinoButton(
                  onPressed: () => viewModel.applyFilters(),
                  child: const Text('应用筛选'),
                ),
              ),
              Expanded(
                child: CupertinoButton(
                  onPressed: () {
                    viewModel.includeVoid = !viewModel.includeVoid;
                    viewModel.applyFilters();
                  },
                  child: Text(viewModel.includeVoid ? '隐藏作废' : '包含作废'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CashBillCard extends StatelessWidget {
  const _CashBillCard({required this.viewModel, required this.bill});

  final CashLedgerViewModel viewModel;
  final CashBill bill;

  @override
  Widget build(BuildContext context) {
    final ordinary = bill.businessOrigin == BusinessOrigin.ordinary;
    return GestureDetector(
      onTap: () async {
        await context.push('/ledger/cash/${bill.id}');
        await viewModel.reload();
      },
      child: InfoCard(
        title:
            '${bill.direction == CashDirection.income ? '收入' : '支出'} ${bill.amount.format()}${bill.isVoid ? '（已作废）' : ''}',
        body:
            '${bill.businessDate.value} · ${viewModel.shopName(bill.scope.shopId)} · ${viewModel.categoryName(bill.categoryId)} · ${viewModel.accountName(bill.accountId)}',
        child: Text(
          ordinary
              ? (bill.note.isEmpty ? '普通现金账' : bill.note)
              : '关联业务只读：${_originLabel(bill.businessOrigin)}',
        ),
      ),
    );
  }
}

String _originLabel(BusinessOrigin origin) => switch (origin) {
  BusinessOrigin.ordinary => '普通现金账',
  BusinessOrigin.purchasePayment => '采购付款',
  BusinessOrigin.supplierRefund => '厂家退款',
  BusinessOrigin.resaleIncome => '问题件收入',
  BusinessOrigin.resaleFee => '问题件费用',
  BusinessOrigin.courierTopUp => '快递充值',
  BusinessOrigin.courierRefund => '快递退款',
  BusinessOrigin.openingDebtPayment => '期初欠款付款',
};
