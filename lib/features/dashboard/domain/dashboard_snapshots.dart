import 'package:personal_finances_pro/core/domain/money.dart';
import 'package:personal_finances_pro/features/ledger/domain/ledger_models.dart';

final class DashboardSnapshot {
  DashboardSnapshot({
    required this.monthCashExpense,
    required this.supplierPayable,
    required this.monthResaleIncome,
    required Iterable<CashBill> recentBills,
  }) : recentBills = List.unmodifiable(recentBills);

  final Money monthCashExpense;
  final Money supplierPayable;
  final Money monthResaleIncome;
  final List<CashBill> recentBills;
}

final class LedgerDetailSnapshot {
  const LedgerDetailSnapshot({
    required this.cashIncome,
    required this.cashExpense,
    required this.cashNet,
    required this.purchaseEffective,
    required this.purchasePaidNet,
    required this.purchasePayable,
    required this.resaleIncome,
    required this.resaleFees,
    required this.resaleNetRecovery,
    required this.courierTopUp,
    required this.courierConsume,
    required this.globalCourierRecordedBalance,
  });

  final Money cashIncome;
  final Money cashExpense;
  final Money cashNet;
  final Money purchaseEffective;
  final Money purchasePaidNet;
  final Money purchasePayable;
  final Money resaleIncome;
  final Money resaleFees;
  final Money resaleNetRecovery;
  final Money courierTopUp;
  final Money courierConsume;
  final Money? globalCourierRecordedBalance;
}
