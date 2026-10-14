import 'package:flutter/foundation.dart';
import 'package:personal_finances_pro/core/domain/local_date.dart';
import 'package:personal_finances_pro/core/domain/money.dart';
import 'package:personal_finances_pro/features/catalog/domain/catalog_models.dart';
import 'package:personal_finances_pro/features/dashboard/domain/dashboard_repository.dart';
import 'package:personal_finances_pro/features/dashboard/domain/dashboard_snapshots.dart';
import 'package:personal_finances_pro/features/ledger/domain/ledger_models.dart';

final class DashboardViewModel extends ChangeNotifier {
  DashboardViewModel({
    required DashboardRepository dashboardRepository,
    DateTime Function()? now,
  }) : _dashboardRepository = dashboardRepository,
       _now = now ?? DateTime.now;

  final DashboardRepository _dashboardRepository;
  final DateTime Function() _now;
  var _disposed = false;

  bool isLoading = false;
  String? errorMessage;
  DashboardSnapshot snapshot = DashboardSnapshot(
    monthCashExpense: Money.zero,
    supplierPayable: Money.zero,
    monthResaleIncome: Money.zero,
    recentBills: const <CashBill>[],
  );

  Future<void> reload({BusinessScope? scope}) async {
    isLoading = true;
    errorMessage = null;
    _notify();
    try {
      final now = _now();
      final start = LocalDate.parse(
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-01',
      );
      final nextMonth =
          now.month == 12
              ? DateTime(now.year + 1, 1)
              : DateTime(now.year, now.month + 1);
      final endDate = nextMonth.subtract(const Duration(days: 1));
      final end = LocalDate.parse(
        '${endDate.year.toString().padLeft(4, '0')}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}',
      );
      snapshot = await _dashboardRepository.loadDashboardSnapshot(
        monthStart: start,
        monthEnd: end,
        scope: scope,
      );
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      isLoading = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
