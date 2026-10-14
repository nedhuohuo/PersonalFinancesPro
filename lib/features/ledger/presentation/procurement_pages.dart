import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:personal_finances_pro/app/presentation/page_widgets.dart';
import 'package:personal_finances_pro/core/domain/local_date.dart';
import 'package:personal_finances_pro/core/domain/money.dart';
import 'package:personal_finances_pro/features/catalog/domain/catalog_models.dart';
import 'package:personal_finances_pro/features/catalog/domain/catalog_repository.dart';
import 'package:personal_finances_pro/features/ledger/domain/cash_bill_repository.dart';
import 'package:personal_finances_pro/features/ledger/domain/ledger_models.dart';
import 'package:personal_finances_pro/features/ledger/domain/ledger_repository.dart';
import 'ledger_detail_pages.dart';
import 'ledger_view_models.dart';

String _today() => LocalDate.todayLocal(DateTime.now()).value;

final class _PurchaseItemInput {
  String description = '';
  String quantity = '1';
  String price = '';
  PurchaseItemDraft draft() => PurchaseItemDraft(
    description: description,
    quantity: positiveLedgerQuantity(quantity),
    unitPrice: Money.parsePositive(price),
  );
}

final class PurchasePaymentInput {
  String date = _today();
  String amount = '';
  String note = '';
  int? account;
  int? category;
  PurchasePaymentDraft draft() => PurchasePaymentDraft(
    businessDate: LocalDate.parse(date.trim()),
    amount: Money.parsePositive(amount),
    accountId: requiredLedgerId(account, '付款账户'),
    categoryId: requiredLedgerId(category, '付款分类'),
    note: note,
  );
}

class PurchasePaymentFields extends StatelessWidget {
  const PurchasePaymentFields({
    super.key,
    required this.input,
    required this.catalogs,
    required this.changed,
    this.initial = false,
  });
  final PurchasePaymentInput input;
  final BusinessCatalogs catalogs;
  final VoidCallback changed;
  final bool initial;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      LedgerTextField(
        label: initial ? '首付款金额（可空）' : '付款金额',
        value: input.amount,
        onChanged: (v) => input.amount = v,
      ),
      LedgerTextField(
        label: '付款日期 YYYY-MM-DD',
        value: input.date,
        onChanged: (v) => input.date = v,
      ),
      BusinessCashSelectors(
        catalogs: catalogs,
        direction: CashDirection.expense,
        accountId: input.account,
        categoryId: input.category,
        prefix: '付款',
        onAccount: (v) {
          input.account = v;
          changed();
        },
        onCategory: (v) {
          input.category = v;
          changed();
        },
      ),
      LedgerTextField(
        label: '付款备注',
        value: input.note,
        onChanged: (v) => input.note = v,
      ),
    ],
  );
}

class PurchaseFormPage extends StatefulWidget {
  const PurchaseFormPage({super.key, this.openingDebt = false});
  final bool openingDebt;
  @override
  State<PurchaseFormPage> createState() => _PurchaseFormPageState();
}

class _PurchaseFormPageState extends State<PurchaseFormPage> {
  final mutation = LedgerMutation();
  final catalogs = BusinessCatalogs();
  final items = [_PurchaseItemInput()];
  final payment = PurchasePaymentInput();
  String date = _today(), freight = '', amount = '', note = '';
  int? supplier;
  BusinessScope scope = const BusinessScope.public();
  int? savedId;
  @override
  void initState() {
    super.initState();
    Future.microtask(() => mutation.read(load));
  }

  Future<void> load() async {
    final catalog = context.read<CatalogRepository>();
    final ledger = context.read<LedgerRepository>();
    await catalogs.load(catalog);
    if (savedId != null) {
      if (widget.openingDebt) {
        await ledger.getSupplierOpeningDebtDetail(savedId!);
      } else {
        await ledger.getPurchaseDetail(savedId!);
      }
    }
  }

  @override
  void dispose() {
    mutation.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final ledger = context.read<LedgerRepository>();
    final committed = await mutation.submit(
      () async {
        final supplierId = requiredLedgerId(supplier, '厂家');
        final businessDate = LocalDate.parse(date.trim());
        if (widget.openingDebt) {
          savedId = await ledger.createSupplierOpeningDebt(
            SupplierOpeningDebtDraft(
              supplierId: supplierId,
              scope: scope,
              businessDate: businessDate,
              amount: Money.parsePositive(amount),
              note: note,
            ),
          );
        } else {
          savedId = await ledger.createPurchase(
            PurchaseDraft(
              supplierId: supplierId,
              scope: scope,
              businessDate: businessDate,
              items: items.map((e) => e.draft()),
              supplierFreight: nonnegativeLedgerMoney(freight),
              note: note,
            ),
            initialPayment:
                payment.amount.trim().isEmpty ? null : payment.draft(),
          );
        }
      },
      reload: load,
      newDraft: true,
    );
    if (!mounted) return;
    if (committed && mutation.error == null) {
      context.pushReplacement(
        '/ledger/${widget.openingDebt ? 'opening-debts' : 'purchases'}/$savedId',
      );
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: mutation,
    builder:
        (context, _) => LedgerBusinessPage(
          title: widget.openingDebt ? '新增期初欠款' : '采购单',
          mutation: mutation,
          reload: load,
          children: [
            const Text('未付款采购只记欠款，不是现金支出。期初欠款不产生现金账。'),
            LedgerTextField(
              label: '业务日期 YYYY-MM-DD',
              value: date,
              onChanged: (v) => date = v,
            ),
            BusinessScopeSelector(
              catalogs: catalogs,
              value: scope,
              onChanged: (v) => setState(() => scope = v!),
            ),
            BusinessPartySelector(
              catalogs: catalogs,
              kind: PartyKind.supplier,
              value: supplier,
              onChanged: (v) => setState(() => supplier = v),
            ),
            if (widget.openingDebt)
              LedgerTextField(
                label: '期初欠款金额',
                value: amount,
                onChanged: (v) => amount = v,
              )
            else ...[
              for (var i = 0; i < items.length; i++)
                InfoCard(
                  title: '商品 ${i + 1}',
                  body: '数量为正整数，金额最多两位小数',
                  child: Column(
                    children: [
                      LedgerTextField(
                        label: '商品描述 ${i + 1}',
                        value: items[i].description,
                        onChanged: (v) => items[i].description = v,
                      ),
                      LedgerTextField(
                        label: '数量 ${i + 1}',
                        value: items[i].quantity,
                        onChanged: (v) => items[i].quantity = v,
                      ),
                      LedgerTextField(
                        label: '单价 ${i + 1}',
                        value: items[i].price,
                        onChanged: (v) => items[i].price = v,
                      ),
                      if (items.length > 1)
                        CupertinoButton(
                          onPressed:
                              mutation.canSave
                                  ? () => setState(() => items.removeAt(i))
                                  : null,
                          child: const Text('移除商品'),
                        ),
                    ],
                  ),
                ),
              CupertinoButton(
                onPressed:
                    mutation.canSave
                        ? () => setState(() => items.add(_PurchaseItemInput()))
                        : null,
                child: const Text('添加商品'),
              ),
              LedgerTextField(
                label: '厂家运费（空为零）',
                value: freight,
                onChanged: (v) => freight = v,
              ),
              PurchasePaymentFields(
                input: payment,
                catalogs: catalogs,
                changed: () => setState(() {}),
                initial: true,
              ),
            ],
            LedgerTextField(
              label: '备注',
              value: note,
              onChanged: (v) => note = v,
            ),
            CupertinoButton.filled(
              key: ValueKey(
                widget.openingDebt
                    ? 'opening-debt-save-button'
                    : 'purchase-save-button',
              ),
              onPressed: mutation.canSave ? save : null,
              child: Text(mutation.pending ? '保存中…' : '保存'),
            ),
          ],
        ),
  );
}

class PurchasePaymentPage extends StatefulWidget {
  const PurchasePaymentPage({
    super.key,
    required this.id,
    this.openingDebt = false,
  });
  final int id;
  final bool openingDebt;
  @override
  State<PurchasePaymentPage> createState() => _PurchasePaymentPageState();
}

class _PurchasePaymentPageState extends State<PurchasePaymentPage> {
  final mutation = LedgerMutation();
  final catalogs = BusinessCatalogs();
  final input = PurchasePaymentInput();
  String position = '';
  @override
  void initState() {
    super.initState();
    Future.microtask(() => mutation.read(load));
  }

  Future<void> load() async {
    final ledger = context.read<LedgerRepository>();
    final catalog = context.read<CatalogRepository>();
    await catalogs.load(catalog);
    if (widget.openingDebt) {
      final d = (await ledger.getSupplierOpeningDebtDetail(widget.id)).debt;
      position = '原欠款 ${d.amount.format()} · 已付 ${d.paid.format()}';
    } else {
      final p = (await ledger.getPurchaseDetail(widget.id)).purchase.position;
      position = '待付 ${p.payable.format()}';
    }
  }

  @override
  void dispose() {
    mutation.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final ledger = context.read<LedgerRepository>();
    final committed = await mutation.submit(
      () async {
        final draft = input.draft();
        if (widget.openingDebt) {
          await ledger.paySupplierOpeningDebt(
            openingDebtId: widget.id,
            payment: draft,
          );
        } else {
          await ledger.recordPurchasePayment(
            purchaseId: widget.id,
            payment: draft,
          );
        }
      },
      reload: load,
      newDraft: true,
    );
    if (mounted && committed && mutation.error == null) context.pop(true);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: mutation,
    builder:
        (context, _) => LedgerBusinessPage(
          title: '新增付款',
          mutation: mutation,
          reload: load,
          children: [
            Text(position),
            PurchasePaymentFields(
              input: input,
              catalogs: catalogs,
              changed: () => setState(() {}),
            ),
            CupertinoButton.filled(
              key: const ValueKey('payment-save-button'),
              onPressed: mutation.canSave ? save : null,
              child: const Text('保存付款'),
            ),
          ],
        ),
  );
}

class PurchaseAdjustmentPage extends StatefulWidget {
  const PurchaseAdjustmentPage({super.key, required this.id});
  final int id;
  @override
  State<PurchaseAdjustmentPage> createState() => _PurchaseAdjustmentPageState();
}

class _PurchaseAdjustmentPageState extends State<PurchaseAdjustmentPage> {
  final mutation = LedgerMutation();
  final catalogs = BusinessCatalogs();
  PurchaseAdjustmentKind kind = PurchaseAdjustmentKind.unpaidWaiver;
  String amount = '', reason = '', date = _today();
  int? account, category;
  @override
  void initState() {
    super.initState();
    Future.microtask(() => mutation.read(load));
  }

  Future<void> load() async {
    final ledger = context.read<LedgerRepository>();
    final catalog = context.read<CatalogRepository>();
    await catalogs.load(catalog);
    await ledger.getPurchaseDetail(widget.id);
  }

  @override
  void dispose() {
    mutation.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final ledger = context.read<LedgerRepository>();
    final committed = await mutation.submit(
      () async {
        if (reason.trim().isEmpty) throw const FormatException('请填写原因');
        await ledger.adjustPurchase(
          PurchaseAdjustmentDraft(
            purchaseId: widget.id,
            kind: kind,
            amount: Money.parsePositive(amount),
            reason: reason,
            categoryId: requiredLedgerId(category, '调整分类'),
            accountId:
                kind == PurchaseAdjustmentKind.paidRefund
                    ? requiredLedgerId(account, '退款账户')
                    : null,
            businessDate: LocalDate.parse(date.trim()),
          ),
        );
      },
      reload: load,
      newDraft: true,
    );
    if (mounted && committed && mutation.error == null) context.pop(true);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: mutation,
    builder:
        (context, _) => LedgerBusinessPage(
          title: '采购调整',
          mutation: mutation,
          reload: load,
          children: [
            LedgerSelectionRow<PurchaseAdjustmentKind>(
              label: '调整类型',
              value: kind,
              display:
                  (v) =>
                      v == PurchaseAdjustmentKind.unpaidWaiver
                          ? '未付减免（无现金）'
                          : '已付退款（收入）',
              values: PurchaseAdjustmentKind.values,
              onChanged:
                  (v) => setState(() {
                    kind = v;
                    category = null;
                  }),
            ),
            LedgerTextField(
              label: '调整金额',
              value: amount,
              onChanged: (v) => amount = v,
            ),
            LedgerTextField(
              label: '调整日期 YYYY-MM-DD',
              value: date,
              onChanged: (v) => date = v,
            ),
            if (kind == PurchaseAdjustmentKind.paidRefund)
              BusinessCashSelectors(
                catalogs: catalogs,
                direction: CashDirection.income,
                accountId: account,
                categoryId: category,
                prefix: '退款',
                onAccount: (v) => setState(() => account = v),
                onCategory: (v) => setState(() => category = v),
              )
            else
              LedgerSelectionRow<int>(
                label: '减免分类（非现金）',
                value: category,
                display: catalogs.categoryName,
                values:
                    catalogs.categories
                        .where(
                          (e) =>
                              e.isActive &&
                              e.direction == CashDirection.expense,
                        )
                        .map((e) => e.id)
                        .toList(),
                onChanged: (v) => setState(() => category = v),
              ),
            LedgerTextField(
              label: '调整原因',
              value: reason,
              onChanged: (v) => reason = v,
            ),
            CupertinoButton.filled(
              key: const ValueKey('adjustment-save-button'),
              onPressed: mutation.canSave ? save : null,
              child: const Text('保存调整'),
            ),
          ],
        ),
  );
}

class PurchaseDetailPage extends StatefulWidget {
  const PurchaseDetailPage({
    super.key,
    required this.id,
    this.openingDebt = false,
  });
  final int id;
  final bool openingDebt;
  @override
  State<PurchaseDetailPage> createState() => _PurchaseDetailPageState();
}

class _PurchaseDetailPageState extends State<PurchaseDetailPage> {
  final mutation = LedgerMutation();
  final catalogs = BusinessCatalogs();
  PurchaseDetail? purchase;
  SupplierOpeningDebtDetail? debt;
  List<CashBill> cash = [];
  @override
  void initState() {
    super.initState();
    Future.microtask(() => mutation.read(load));
  }

  Future<void> load() async {
    final ledger = context.read<LedgerRepository>();
    final catalog = context.read<CatalogRepository>();
    final cashRepo = context.read<CashBillRepository>();
    await catalogs.load(catalog);
    final bills = await cashRepo.listCashBills(
      const CashBillFilter(includeVoid: true),
    );
    if (widget.openingDebt) {
      debt = await ledger.getSupplierOpeningDebtDetail(widget.id);
    } else {
      purchase = await ledger.getPurchaseDetail(widget.id);
    }
    cash = bills;
  }

  @override
  void dispose() {
    mutation.dispose();
    super.dispose();
  }

  Future<void> open(String path) async {
    await context.push(path);
    if (mounted) await mutation.read(load);
  }

  List<Widget> cashLink(int id) => [
    for (final b in cash.where((b) => b.id == id))
      businessCashLink(
        context,
        catalogs,
        b,
        onReturn: () => mutation.read(load),
      ),
  ];
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: mutation,
    builder: (context, _) {
      final ledger = context.read<LedgerRepository>();
      final p = purchase?.purchase;
      final d = debt?.debt;
      return LedgerBusinessPage(
        title: widget.openingDebt ? '期初欠款详情' : '采购详情',
        mutation: mutation,
        reload: load,
        children: [
          if (p != null) ...[
            InfoCard(
              title: '采购 #${p.id}${p.isVoid ? '（已作废）' : ''}',
              body:
                  '${p.businessDate.value} · ${catalogs.scopeName(p.scope)} · ${catalogs.partyName(p.supplierId)}\n原额 ${p.originalTotal.format()} · 运费 ${p.supplierFreight.format()}\n有效 ${p.position.effectiveTotal.format()}\n实付净额 ${p.position.paidNet.format()}\n待付 ${p.position.payable.format()}\n${p.note}\n未付款采购不是现金支出',
            ),
            for (final item in purchase!.items)
              Text(
                '${item.description} · ${item.quantity} × ${item.unitPrice.format()} = ${item.lineTotal.format()}',
              ),
            CupertinoButton(
              onPressed:
                  mutation.canAct
                      ? () => open('/ledger/purchases/${p.id}/payment')
                      : null,
              child: const Text('新增付款'),
            ),
            CupertinoButton(
              onPressed:
                  mutation.canAct
                      ? () => open('/ledger/purchases/${p.id}/adjust')
                      : null,
              child: const Text('减免 / 退款'),
            ),
            LedgerStatusButton(
              label: p.isVoid ? '恢复采购' : '作废采购',
              mutation: mutation,
              reload: load,
              write:
                  (reason) =>
                      p.isVoid
                          ? ledger.restorePurchase(
                            purchaseId: p.id,
                            reason: reason,
                          )
                          : ledger.voidPurchaseWithoutActivePayments(
                            purchaseId: p.id,
                            reason: reason,
                          ),
            ),
            if (p.isVoid) const Text('请先恢复采购，再恢复付款或调整。'),
            for (final payment in purchase!.payments)
              InfoCard(
                title:
                    '付款 #${payment.id} ${payment.amount.format()}${payment.isVoid ? '（已作废）' : ''}',
                body: '付款明细',
                child: Column(
                  children: [
                    ...cashLink(payment.cashBillId),
                    if (p.isVoid && payment.isVoid)
                      CupertinoButton(
                        onPressed: null,
                        child: Text('恢复付款 #${payment.id}'),
                      )
                    else
                      LedgerStatusButton(
                        label:
                            payment.isVoid
                                ? '恢复付款 #${payment.id}'
                                : '作废付款 #${payment.id}',
                        mutation: mutation,
                        reload: load,
                        write:
                            (reason) =>
                                payment.isVoid
                                    ? ledger.restorePurchasePayment(
                                      paymentId: payment.id,
                                      reason: reason,
                                    )
                                    : ledger.voidPurchasePayment(
                                      paymentId: payment.id,
                                      reason: reason,
                                    ),
                      ),
                  ],
                ),
              ),
            for (final adjustment in purchase!.adjustments)
              InfoCard(
                title:
                    '${adjustment.kind == PurchaseAdjustmentKind.unpaidWaiver ? '未付减免' : '已付退款'} #${adjustment.id} ${adjustment.amount.format()}${adjustment.isVoid ? '（已作废）' : ''}',
                body: adjustment.reason,
                child: Column(
                  children: [
                    if (adjustment.cashBillId != null)
                      ...cashLink(adjustment.cashBillId!),
                    if (p.isVoid && adjustment.isVoid)
                      CupertinoButton(
                        onPressed: null,
                        child: Text('恢复调整 #${adjustment.id}'),
                      )
                    else
                      LedgerStatusButton(
                        label:
                            adjustment.isVoid
                                ? '恢复调整 #${adjustment.id}'
                                : '作废调整 #${adjustment.id}',
                        mutation: mutation,
                        reload: load,
                        write:
                            (reason) =>
                                adjustment.isVoid
                                    ? ledger.restorePurchaseAdjustment(
                                      adjustmentId: adjustment.id,
                                      reason: reason,
                                    )
                                    : ledger.voidPurchaseAdjustment(
                                      adjustmentId: adjustment.id,
                                      reason: reason,
                                    ),
                      ),
                  ],
                ),
              ),
          ],
          if (d != null) ...[
            InfoCard(
              title: '期初欠款 #${d.id}${d.isVoid ? '（已作废）' : ''}',
              body:
                  '${d.businessDate.value} · ${catalogs.scopeName(d.scope)} · ${catalogs.partyName(d.supplierId)}\n原欠款 ${d.amount.format()} · 已付 ${d.paid.format()} · 待付 ${Money.sumCents([d.amount.cents, -d.paid.cents]).format()}\n${d.note}',
            ),
            CupertinoButton(
              onPressed:
                  mutation.canAct
                      ? () => open('/ledger/opening-debts/${d.id}/payment')
                      : null,
              child: const Text('新增付款'),
            ),
            for (final payment in debt!.payments)
              InfoCard(
                title:
                    '欠款付款 #${payment.id} ${payment.amount.format()}${payment.isVoid ? '（已作废）' : ''}',
                body: '付款明细',
                child: Column(
                  children: [
                    ...cashLink(payment.cashBillId),
                    LedgerStatusButton(
                      label:
                          payment.isVoid
                              ? '恢复欠款付款 #${payment.id}'
                              : '作废欠款付款 #${payment.id}',
                      mutation: mutation,
                      reload: load,
                      write:
                          (reason) =>
                              payment.isVoid
                                  ? ledger.restoreSupplierOpeningDebtPayment(
                                    paymentId: payment.id,
                                    reason: reason,
                                  )
                                  : ledger.voidSupplierOpeningDebtPayment(
                                    paymentId: payment.id,
                                    reason: reason,
                                  ),
                    ),
                  ],
                ),
              ),
          ],
          if (p == null && d == null && !mutation.loading)
            const Text('详情不可用；请刷新或返回，不会新增业务。'),
        ],
      );
    },
  );
}
