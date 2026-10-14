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

final class _ResaleFeeInput {
  String amount = '', note = '';
  int? account, category, party;
  ProblemResaleFeeDraft draft() => ProblemResaleFeeDraft(
    categoryId: requiredLedgerId(category, '费用分类'),
    accountId: requiredLedgerId(account, '费用账户'),
    amount: Money.parsePositive(amount),
    partyId: party,
    note: note,
  );
}

class ProblemResaleFormPage extends StatefulWidget {
  const ProblemResaleFormPage({super.key});
  @override
  State<ProblemResaleFormPage> createState() => _ProblemResaleFormPageState();
}

class _ProblemResaleFormPageState extends State<ProblemResaleFormPage> {
  final mutation = LedgerMutation();
  final catalogs = BusinessCatalogs();
  final fees = <_ResaleFeeInput>[];
  String date = LocalDate.todayLocal(DateTime.now()).value;
  String description = '', quantity = '1', amount = '', note = '';
  BusinessScope scope = const BusinessScope.public();
  int? buyer, channel, account, category, savedId;
  @override
  void initState() {
    super.initState();
    Future.microtask(() => mutation.read(load));
  }

  Future<void> load() async {
    final catalog = context.read<CatalogRepository>();
    final ledger = context.read<LedgerRepository>();
    await catalogs.load(catalog);
    if (savedId != null) await ledger.getProblemResaleDetail(savedId!);
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
        savedId = await ledger.createProblemResale(
          ProblemResaleDraft(
            scope: scope,
            businessDate: LocalDate.parse(date.trim()),
            description: description,
            quantity: positiveLedgerQuantity(quantity),
            incomeAmount: Money.parsePositive(amount),
            incomeAccountId: requiredLedgerId(account, '收入账户'),
            incomeCategoryId: requiredLedgerId(category, '收入分类'),
            buyerId: requiredLedgerId(buyer, '买家'),
            channelId: requiredLedgerId(channel, '渠道'),
            issueNote: note,
            fees: fees.map((e) => e.draft()),
          ),
        );
      },
      reload: load,
      newDraft: true,
    );
    if (mounted && committed && mutation.error == null) {
      context.pushReplacement('/ledger/resales/$savedId');
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: mutation,
    builder:
        (context, _) => LedgerBusinessPage(
          title: '问题件转卖',
          mutation: mutation,
          reload: load,
          children: [
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
            LedgerTextField(
              label: '问题件描述',
              value: description,
              onChanged: (v) => description = v,
            ),
            LedgerTextField(
              label: '数量',
              value: quantity,
              onChanged: (v) => quantity = v,
            ),
            LedgerTextField(
              label: '转卖收入',
              value: amount,
              onChanged: (v) => amount = v,
            ),
            BusinessPartySelector(
              catalogs: catalogs,
              kind: PartyKind.buyer,
              value: buyer,
              onChanged: (v) => setState(() => buyer = v),
            ),
            LedgerSelectionRow<int>(
              label: '转卖渠道',
              value: channel,
              display: catalogs.channelName,
              values:
                  catalogs.channels
                      .where((e) => e.isActive)
                      .map((e) => e.id)
                      .toList(),
              onChanged: (v) => setState(() => channel = v),
            ),
            BusinessCashSelectors(
              catalogs: catalogs,
              direction: CashDirection.income,
              accountId: account,
              categoryId: category,
              prefix: '收入',
              onAccount: (v) => setState(() => account = v),
              onCategory: (v) => setState(() => category = v),
            ),
            for (var i = 0; i < fees.length; i++)
              InfoCard(
                title: '独立费用 ${i + 1}',
                body: '费用可使用不同于收入的账户；无费用请移除本行。',
                child: Column(
                  children: [
                    LedgerTextField(
                      label: '费用金额 ${i + 1}',
                      value: fees[i].amount,
                      onChanged: (v) => fees[i].amount = v,
                    ),
                    BusinessCashSelectors(
                      catalogs: catalogs,
                      direction: CashDirection.expense,
                      accountId: fees[i].account,
                      categoryId: fees[i].category,
                      prefix: '费用 ${i + 1} ',
                      onAccount: (v) => setState(() => fees[i].account = v),
                      onCategory: (v) => setState(() => fees[i].category = v),
                    ),
                    LedgerSelectionRow<int?>(
                      label: '费用往来方 ${i + 1}',
                      value: fees[i].party,
                      display:
                          (id) => id == null ? '无' : catalogs.partyName(id),
                      values: [
                        null,
                        ...catalogs.parties
                            .where((e) => e.isActive)
                            .map((e) => e.id),
                      ],
                      onChanged: (v) => setState(() => fees[i].party = v),
                    ),
                    LedgerTextField(
                      label: '费用备注 ${i + 1}',
                      value: fees[i].note,
                      onChanged: (v) => fees[i].note = v,
                    ),
                    CupertinoButton(
                      onPressed:
                          mutation.canSave
                              ? () => setState(() => fees.removeAt(i))
                              : null,
                      child: const Text('移除费用'),
                    ),
                  ],
                ),
              ),
            CupertinoButton(
              onPressed:
                  mutation.canSave
                      ? () => setState(() => fees.add(_ResaleFeeInput()))
                      : null,
              child: const Text('添加独立费用'),
            ),
            LedgerTextField(
              label: '问题说明（可空）',
              value: note,
              onChanged: (v) => note = v,
            ),
            CupertinoButton.filled(
              key: const ValueKey('resale-save-button'),
              onPressed: mutation.canSave ? save : null,
              child: const Text('保存转卖'),
            ),
          ],
        ),
  );
}

class ProblemResaleDetailPage extends StatefulWidget {
  const ProblemResaleDetailPage({super.key, required this.id});
  final int id;
  @override
  State<ProblemResaleDetailPage> createState() =>
      _ProblemResaleDetailPageState();
}

class _ProblemResaleDetailPageState extends State<ProblemResaleDetailPage> {
  final mutation = LedgerMutation();
  final catalogs = BusinessCatalogs();
  ProblemResaleDetail? detail;
  List<CashBill> bills = [];
  @override
  void initState() {
    super.initState();
    Future.microtask(() => mutation.read(load));
  }

  Future<void> load() async {
    final catalog = context.read<CatalogRepository>();
    final ledger = context.read<LedgerRepository>();
    final cash = context.read<CashBillRepository>();
    await catalogs.load(catalog);
    final rows = await cash.listCashBills(
      const CashBillFilter(includeVoid: true),
    );
    detail = await ledger.getProblemResaleDetail(widget.id);
    bills = rows;
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
      final d = detail;
      final r = d?.resale;
      final ledger = context.read<LedgerRepository>();
      return LedgerBusinessPage(
        title: '转卖详情',
        mutation: mutation,
        reload: load,
        children: [
          if (d != null && r != null) ...[
            InfoCard(
              title: '${r.description}${r.isVoid ? '（已作废）' : ''}',
              body:
                  '${r.businessDate.value} · ${catalogs.scopeName(r.scope)} · 数量 ${r.quantity}\n${catalogs.partyName(r.buyerId)} · ${catalogs.channelName(r.channelId)}\n收入 ${r.incomeAmount.format()}\n费用 ${Money.sumCents(d.fees.map((f) => f.amount.cents)).format()}\n净回收 ${d.netRecovery.format()}\n${r.issueNote}',
            ),
            for (final b in bills.where((b) => b.id == r.incomeCashBillId))
              businessCashLink(
                context,
                catalogs,
                b,
                onReturn: () => mutation.read(load),
              ),
            for (final fee in d.fees)
              InfoCard(
                title: '费用 ${fee.amount.format()}',
                body:
                    '${catalogs.categoryName(fee.categoryId)} · ${catalogs.accountName(fee.accountId)}',
                child: Column(
                  children: [
                    for (final b in bills.where((b) => b.id == fee.cashBillId))
                      businessCashLink(
                        context,
                        catalogs,
                        b,
                        onReturn: () => mutation.read(load),
                      ),
                  ],
                ),
              ),
            LedgerStatusButton(
              label: r.isVoid ? '恢复转卖整组' : '作废转卖整组',
              mutation: mutation,
              reload: load,
              write:
                  (reason) =>
                      r.isVoid
                          ? ledger.restoreProblemResale(
                            resaleId: r.id,
                            reason: reason,
                          )
                          : ledger.voidProblemResale(
                            resaleId: r.id,
                            reason: reason,
                          ),
            ),
          ] else if (!mutation.loading)
            const Text('详情不可用；请刷新或返回，不会新增业务。'),
        ],
      );
    },
  );
}
