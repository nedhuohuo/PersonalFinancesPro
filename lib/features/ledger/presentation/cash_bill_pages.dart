import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_finances_pro/app/presentation/page_widgets.dart';
import 'package:personal_finances_pro/features/catalog/domain/catalog_models.dart';
import 'package:personal_finances_pro/features/catalog/domain/catalog_repository.dart';
import 'package:personal_finances_pro/features/ledger/domain/cash_bill_repository.dart';
import 'package:personal_finances_pro/features/ledger/domain/ledger_models.dart';
import 'package:personal_finances_pro/features/ledger/presentation/ledger_view_models.dart';
import 'package:provider/provider.dart';

typedef CashLedgerViewModelBuilder =
    CashLedgerViewModel Function(BuildContext context);

class CashBillFormPage extends StatefulWidget {
  const CashBillFormPage({super.key, this.id, this.viewModelBuilder});

  final int? id;
  final CashLedgerViewModelBuilder? viewModelBuilder;

  @override
  State<CashBillFormPage> createState() => _CashBillFormPageState();
}

class _CashBillFormPageState extends State<CashBillFormPage> {
  late final CashLedgerViewModel _viewModel =
      widget.viewModelBuilder?.call(context) ??
      CashLedgerViewModel(
        cashBillRepository: context.read<CashBillRepository>(),
        catalogRepository: context.read<CatalogRepository>(),
      );
  var _loaded = false;
  late bool _formReady = widget.id == null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    if (widget.id == null) _viewModel.beginNewCashBill();
    _viewModel.includeVoid = true;
    _viewModel.reload().then((_) {
      if (!mounted) return;
      final id = widget.id;
      if (id != null) {
        final bill = _viewModel.billById(id);
        if (bill != null) {
          _viewModel.beginEditCashBill(bill);
          setState(() => _formReady = true);
        }
      }
    });
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _viewModel,
      builder:
          (context, _) => CupertinoPageScaffold(
            resizeToAvoidBottomInset: true,
            navigationBar: CupertinoNavigationBar(
              middle: Text(widget.id == null ? '新增现金账' : '编辑现金账'),
              transitionBetweenRoutes: false,
            ),
            child: SafeArea(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.all(appPadding),
                children: [
                  if (_viewModel.isLoading)
                    const InfoCard(title: '正在读取', body: '正在加载现金账。'),
                  if (!_viewModel.isLoading &&
                      !_formReady &&
                      _viewModel.errorMessage == null)
                    const InfoCard(title: '未找到现金账', body: '请返回列表刷新，不会新增账目。'),
                  if (_viewModel.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InfoCard(
                        title: '提示',
                        body: _viewModel.errorMessage!,
                      ),
                    ),
                  LedgerTextField(
                    label: '日期 YYYY-MM-DD',
                    value: _viewModel.businessDateText,
                    keyboardType: TextInputType.datetime,
                    onChanged: (value) => _viewModel.businessDateText = value,
                  ),
                  const SizedBox(height: 12),
                  CupertinoSlidingSegmentedControl<CashDirection>(
                    groupValue: _viewModel.direction,
                    children: const {
                      CashDirection.expense: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('支出'),
                      ),
                      CashDirection.income: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('收入'),
                      ),
                    },
                    onValueChanged: (value) {
                      if (value != null) _viewModel.setDirection(value);
                    },
                  ),
                  const SizedBox(height: 12),
                  LedgerTextField(
                    label: '金额',
                    value: _viewModel.amountText,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (value) => _viewModel.amountText = value,
                  ),
                  const SizedBox(height: 12),
                  LedgerSelectionRow<int?>(
                    label: '店铺范围',
                    value: _viewModel.shopId,
                    display:
                        (id) => id == null ? '公共' : _viewModel.shopName(id),
                    values: <int?>[
                      null,
                      ..._viewModel.activeShops.map((shop) => shop.id),
                    ],
                    onChanged:
                        (value) => setState(() => _viewModel.shopId = value),
                  ),
                  LedgerSelectionRow<int>(
                    label: '分类',
                    value: _viewModel.categoryId,
                    display: _viewModel.categoryName,
                    values:
                        _viewModel.activeDirectionCategories
                            .map((item) => item.id)
                            .toList(),
                    onChanged:
                        (value) =>
                            setState(() => _viewModel.categoryId = value),
                  ),
                  LedgerSelectionRow<int>(
                    label: '账户',
                    value: _viewModel.accountId,
                    display: _viewModel.accountName,
                    values:
                        _viewModel.activeAccounts
                            .map((item) => item.id)
                            .toList(),
                    onChanged:
                        (value) => setState(() => _viewModel.accountId = value),
                  ),
                  LedgerSelectionRow<int?>(
                    label: '往来方',
                    value: _viewModel.partyId,
                    display:
                        (id) => id == null ? '无' : _viewModel.partyName(id)!,
                    values: <int?>[
                      null,
                      ..._viewModel.activeParties.map((item) => item.id),
                    ],
                    onChanged:
                        (value) => setState(() => _viewModel.partyId = value),
                  ),
                  const SizedBox(height: 12),
                  LedgerTextField(
                    label: '备注',
                    value: _viewModel.noteText,
                    onChanged: (value) => _viewModel.noteText = value,
                  ),
                  const SizedBox(height: 18),
                  if (_viewModel.lastSaveCommitted &&
                      _viewModel.errorMessage != null)
                    CupertinoButton(
                      onPressed:
                          _viewModel.isLoading ? null : _viewModel.reload,
                      child: const Text('刷新'),
                    ),
                  CupertinoButton.filled(
                    key: const ValueKey('cash-save-button'),
                    onPressed:
                        _formReady &&
                                !_viewModel.isLoading &&
                                _viewModel.canSubmit
                            ? _save
                            : null,
                    child: Text(_viewModel.isSaving ? '保存中…' : '保存'),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Future<void> _save() async {
    await _viewModel.saveFromForm();
    if (!mounted) return;
    if (_viewModel.lastSaveCommitted && _viewModel.errorMessage == null) {
      Navigator.of(context).pop(true);
    }
  }
}

class CashBillDetailPage extends StatefulWidget {
  const CashBillDetailPage({
    super.key,
    required this.id,
    this.viewModelBuilder,
  });

  final int id;
  final CashLedgerViewModelBuilder? viewModelBuilder;

  @override
  State<CashBillDetailPage> createState() => _CashBillDetailPageState();
}

class _CashBillDetailPageState extends State<CashBillDetailPage> {
  late final CashLedgerViewModel _viewModel =
      widget.viewModelBuilder?.call(context) ??
      CashLedgerViewModel(
        cashBillRepository: context.read<CashBillRepository>(),
        catalogRepository: context.read<CatalogRepository>(),
      );

  @override
  void initState() {
    super.initState();
    _viewModel.includeVoid = true;
    Future<void>.microtask(_viewModel.reload);
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, _) {
        final bill = _viewModel.billById(widget.id);
        return CupertinoPageScaffold(
          navigationBar: const CupertinoNavigationBar(
            middle: Text('现金账详情'),
            transitionBetweenRoutes: false,
          ),
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(appPadding),
              children: [
                if (_viewModel.errorMessage != null)
                  InfoCard(title: '提示', body: _viewModel.errorMessage!),
                CupertinoButton(
                  onPressed:
                      _viewModel.isSaving || _viewModel.isLoading
                          ? null
                          : _viewModel.reload,
                  child: const Text('刷新'),
                ),
                if (_viewModel.isLoading)
                  const InfoCard(title: '正在读取', body: '正在加载现金账。')
                else if (bill == null)
                  const InfoCard(title: '未找到现金账', body: '请返回列表刷新。')
                else
                  _CashBillDetailBody(bill: bill, viewModel: _viewModel),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CashBillDetailBody extends StatelessWidget {
  const _CashBillDetailBody({required this.bill, required this.viewModel});

  final CashBill bill;
  final CashLedgerViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final ordinary = bill.businessOrigin == BusinessOrigin.ordinary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InfoCard(
          title:
              '${bill.direction == CashDirection.income ? '收入' : '支出'} ${bill.amount.format()}',
          body:
              '${bill.businessDate.value} · ${viewModel.shopName(bill.scope.shopId)} · ${viewModel.categoryName(bill.categoryId)} · ${viewModel.accountName(bill.accountId)}${bill.isVoid ? ' · 已作废' : ''}',
          child: Text(bill.note.isEmpty ? '无备注' : bill.note),
        ),
        const SizedBox(height: 12),
        if (ordinary) ...[
          CupertinoButton.filled(
            onPressed:
                viewModel.isSaving
                    ? null
                    : () async {
                      await context.push('/ledger/cash/${bill.id}/edit');
                      await viewModel.reload();
                    },
            child: const Text('编辑'),
          ),
          const SizedBox(height: 8),
          CupertinoButton(
            onPressed:
                viewModel.canChangeStatus(bill)
                    ? () => _askReason(
                      context,
                      viewModel: viewModel,
                      title: bill.isVoid ? '恢复原因' : '作废原因',
                      onSubmit:
                          (reason) =>
                              bill.isVoid
                                  ? viewModel.restoreBill(bill, reason)
                                  : viewModel.voidBill(bill, reason),
                    )
                    : null,
            child: Text(bill.isVoid ? '恢复' : '作废'),
          ),
        ] else
          InfoCard(
            title: '关联账目只读',
            body:
                '这条现金账来自 ${_originLabel(bill.businessOrigin)}，请到对应业务详情处理；Task5 接入前暂不开放通用编辑。',
          ),
      ],
    );
  }
}

Future<void> _askReason(
  BuildContext context, {
  required String title,
  required CashLedgerViewModel viewModel,
  required Future<bool> Function(String reason) onSubmit,
}) async {
  var reason = '';
  await showCupertinoDialog<void>(
    context: context,
    builder:
        (context) => AnimatedBuilder(
          animation: viewModel,
          builder:
              (context, _) => CupertinoAlertDialog(
                title: Text(title),
                content: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    children: [
                      CupertinoTextField(onChanged: (value) => reason = value),
                      if (viewModel.errorMessage != null)
                        Text(viewModel.errorMessage!),
                    ],
                  ),
                ),
                actions: [
                  CupertinoDialogAction(
                    onPressed:
                        viewModel.isSaving
                            ? null
                            : () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                  CupertinoDialogAction(
                    onPressed:
                        viewModel.isSaving
                            ? null
                            : () async {
                              final committed = await onSubmit(reason);
                              if (committed && context.mounted) {
                                Navigator.of(context).pop();
                              }
                            },
                    child: const Text('确认'),
                  ),
                ],
              ),
        ),
  );
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
