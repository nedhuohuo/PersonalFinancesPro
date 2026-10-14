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

String courierEventLabel(CourierEventType type) => switch (type) {
  CourierEventType.opening => '非现金期初',
  CourierEventType.topUp => '充值',
  CourierEventType.consume => '消耗',
  CourierEventType.refund => '退款',
};

class CourierFormPage extends StatefulWidget {
  const CourierFormPage({
    super.key,
    this.id,
    this.type = CourierEventType.opening,
  });
  final int? id;
  final CourierEventType type;
  @override
  State<CourierFormPage> createState() => _CourierFormPageState();
}

class _CourierFormPageState extends State<CourierFormPage> {
  final mutation = LedgerMutation();
  final catalogs = BusinessCatalogs();
  String date = LocalDate.todayLocal(DateTime.now()).value;
  String name = '', amount = '', note = '';
  int? account, category, savedId;
  BusinessScope scope = const BusinessScope.public();
  CourierAccountDetail? detail;
  bool get opening => widget.type == CourierEventType.opening;
  @override
  void initState() {
    super.initState();
    Future.microtask(() => mutation.read(load));
  }

  Future<void> load() async {
    final catalog = context.read<CatalogRepository>();
    final ledger = context.read<LedgerRepository>();
    await catalogs.load(catalog);
    final id = widget.id ?? savedId;
    if (id != null) detail = await ledger.getCourierAccountDetail(id);
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
        final businessDate = LocalDate.parse(date.trim());
        if (opening) {
          savedId = await ledger.createCourierAccount(
            CourierAccountDraft(
              name: name,
              openingBalance: nonnegativeLedgerMoney(amount),
              businessDate: businessDate,
            ),
          );
        } else if (widget.type == CourierEventType.consume) {
          await ledger.recordCourierConsume(
            CourierConsumeDraft(
              courierAccountId: widget.id!,
              scope: scope,
              businessDate: businessDate,
              amount: Money.parsePositive(amount),
              note: note,
            ),
          );
        } else {
          final draft = CourierCashEventDraft(
            courierAccountId: widget.id!,
            scope: scope,
            businessDate: businessDate,
            amount: Money.parsePositive(amount),
            accountId: requiredLedgerId(account, '现金账户'),
            categoryId: requiredLedgerId(category, '现金分类'),
            note: note,
          );
          if (widget.type == CourierEventType.topUp) {
            await ledger.recordCourierTopUp(draft);
          } else {
            await ledger.recordCourierRefund(draft);
          }
        }
      },
      reload: load,
      newDraft: true,
    );
    if (!mounted) return;
    if (committed && mutation.error == null) {
      if (opening) {
        context.pushReplacement('/ledger/courier/$savedId');
      } else {
        context.pop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: mutation,
    builder:
        (context, _) => LedgerBusinessPage(
          title: opening ? '新增快递钱包' : '快递${courierEventLabel(widget.type)}',
          mutation: mutation,
          reload: load,
          children: [
            if (detail != null)
              Text(
                '${detail!.account.name} · 全局记录余额 ${detail!.account.recordedBalance.format()}（不是单店余额）',
              ),
            if (opening)
              LedgerTextField(
                label: '钱包名称',
                value: name,
                onChanged: (v) => name = v,
              ),
            LedgerTextField(
              label: '业务日期 YYYY-MM-DD',
              value: date,
              onChanged: (v) => date = v,
            ),
            if (!opening)
              BusinessScopeSelector(
                catalogs: catalogs,
                value: scope,
                onChanged: (v) => setState(() => scope = v!),
              ),
            Text(
              opening
                  ? '期初余额为非现金记录，空为零。'
                  : widget.type == CourierEventType.consume
                  ? '不产生第二笔现金支出'
                  : widget.type == CourierEventType.topUp
                  ? '充值产生现金支出'
                  : '退款产生现金收入',
            ),
            LedgerTextField(
              label: opening ? '期初余额（空为零）' : '事件金额',
              value: amount,
              onChanged: (v) => amount = v,
            ),
            if (!opening && widget.type != CourierEventType.consume)
              BusinessCashSelectors(
                catalogs: catalogs,
                direction:
                    widget.type == CourierEventType.refund
                        ? CashDirection.income
                        : CashDirection.expense,
                accountId: account,
                categoryId: category,
                prefix: '现金',
                onAccount: (v) => setState(() => account = v),
                onCategory: (v) => setState(() => category = v),
              ),
            if (!opening)
              LedgerTextField(
                label: '事件备注',
                value: note,
                onChanged: (v) => note = v,
              ),
            CupertinoButton.filled(
              key: const ValueKey('courier-save-button'),
              onPressed: mutation.canSave ? save : null,
              child: const Text('保存快递记录'),
            ),
          ],
        ),
  );
}

class CourierDetailPage extends StatefulWidget {
  const CourierDetailPage({super.key, required this.id});
  final int id;
  @override
  State<CourierDetailPage> createState() => _CourierDetailPageState();
}

class _CourierDetailPageState extends State<CourierDetailPage> {
  final mutation = LedgerMutation();
  final catalogs = BusinessCatalogs();
  CourierAccountDetail? detail;
  List<CashBill> cash = [];
  @override
  void initState() {
    super.initState();
    Future.microtask(() => mutation.read(load));
  }

  Future<void> load() async {
    final catalog = context.read<CatalogRepository>();
    final ledger = context.read<LedgerRepository>();
    final cashRepo = context.read<CashBillRepository>();
    await catalogs.load(catalog);
    final bills = await cashRepo.listCashBills(
      const CashBillFilter(includeVoid: true),
    );
    detail = await ledger.getCourierAccountDetail(widget.id);
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

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: mutation,
    builder: (context, _) {
      final d = detail;
      final ledger = context.read<LedgerRepository>();
      return LedgerBusinessPage(
        title: '快递钱包详情',
        mutation: mutation,
        reload: load,
        children: [
          if (d != null) ...[
            InfoCard(
              title: '${d.account.name}${d.account.isActive ? '' : '（已停用）'}',
              body:
                  '全局记录余额 ${d.account.recordedBalance.format()}\n不代表任何单店资产；账户标签不计算真实银行余额。',
            ),
            for (final action
                in {'topup': '充值', 'consume': '消耗', 'refund': '退款'}.entries)
              CupertinoButton(
                onPressed:
                    mutation.canAct && d.account.isActive
                        ? () => open(
                          '/ledger/courier/${d.account.id}/${action.key}',
                        )
                        : null,
                child: Text('新增${action.value}'),
              ),
            for (final event in d.events)
              InfoCard(
                title:
                    '${courierEventLabel(event.eventType)} #${event.id} ${event.amount.format()}${event.isVoid ? '（已作废）' : ''}',
                body:
                    '${event.businessDate.value} · ${event.scope == null ? '全局非现金期初' : catalogs.scopeName(event.scope)}\n全局余额轨迹 ${event.balanceAfter.format()}\n${event.note}${event.eventType == CourierEventType.consume ? '\n不产生第二笔现金支出' : ''}',
                child: Column(
                  children: [
                    for (final bill in cash.where(
                      (b) => b.id == event.cashBillId,
                    ))
                      businessCashLink(
                        context,
                        catalogs,
                        bill,
                        onReturn: () => mutation.read(load),
                      ),
                    if (event.eventType == CourierEventType.opening)
                      const Text('期初余额不可作废')
                    else
                      LedgerStatusButton(
                        label:
                            event.isVoid
                                ? '恢复事件 #${event.id}'
                                : '作废事件 #${event.id}',
                        mutation: mutation,
                        reload: load,
                        write:
                            (reason) =>
                                event.isVoid
                                    ? ledger.restoreCourierEvent(
                                      eventId: event.id,
                                      reason: reason,
                                    )
                                    : ledger.voidCourierEvent(
                                      eventId: event.id,
                                      reason: reason,
                                    ),
                      ),
                  ],
                ),
              ),
          ] else if (!mutation.loading)
            const Text('详情不可用；请刷新或返回，不会新增业务。'),
        ],
      );
    },
  );
}
