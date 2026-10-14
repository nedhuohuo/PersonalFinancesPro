import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finances_pro/core/domain/money.dart';
import 'package:personal_finances_pro/features/dashboard/presentation/dashboard_view_model.dart';

import '../../../support/widget_test_app.dart';

void main() {
  test('dashboard view model loads empty ledger zeros', () async {
    final vm = DashboardViewModel(
      dashboardRepository: RecordingDashboardRepository(),
      now: () => DateTime(2026, 10, 14),
    );

    await vm.reload();

    expect(vm.errorMessage, isNull);
    expect(vm.snapshot.monthCashExpense.cents, Money.zero.cents);
    expect(vm.snapshot.supplierPayable.cents, Money.zero.cents);
    expect(vm.snapshot.monthResaleIncome.cents, Money.zero.cents);
    vm.dispose();
  });
}
