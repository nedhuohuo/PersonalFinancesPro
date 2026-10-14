import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finances_pro/features/ledger/presentation/ledger_view_models.dart';

import '../../../support/widget_test_app.dart';

void main() {
  test(
    'cash view model reports committed save with refresh failure without duplicate retry',
    () async {
      final repo = RecordingCashBillRepository(refreshThrows: true);
      final vm = CashLedgerViewModel(
        cashBillRepository: repo,
        catalogRepository: RecordingCatalogRepository(),
      );

      await vm.saveCashBill(validDraft);

      expect(vm.lastSaveCommitted, isTrue);
      expect(vm.errorMessage, contains('已保存，但刷新失败'));
      await vm.saveCashBill(validDraft);
      expect(repo.createCashBillCalls, 1);
      vm.dispose();
    },
  );

  test('commit failure keeps user input and allows corrected retry', () async {
    final repo = RecordingCashBillRepository(commitThrows: true);
    final vm = CashLedgerViewModel(
      cashBillRepository: repo,
      catalogRepository: RecordingCatalogRepository(),
    );

    vm.amountText = '18.00';
    await vm.saveFromForm();

    expect(vm.amountText, '18.00');
    expect(vm.lastSaveCommitted, isFalse);
    expect(vm.isSaving, isFalse);
    expect(repo.createCashBillCalls, 1);
    vm.dispose();
  });

  test(
    'new cash form resets committed guard so identical later data can save',
    () async {
      final repo = RecordingCashBillRepository(refreshThrows: true);
      final vm = CashLedgerViewModel(
        cashBillRepository: repo,
        catalogRepository: RecordingCatalogRepository(),
      );

      await vm.saveCashBill(validDraft);
      await vm.saveCashBill(validDraft);
      vm.beginNewCashBill();
      await vm.saveCashBill(validDraft);

      expect(repo.createCashBillCalls, 2);
      vm.dispose();
    },
  );
}
