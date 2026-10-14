import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finances_pro/features/catalog/domain/catalog_models.dart';
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

    await vm.reload();
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
  test(
    'form validation catches invalid input without changing exact fields',
    () async {
      final repo = RecordingCashBillRepository();
      final vm = CashLedgerViewModel(
        cashBillRepository: repo,
        catalogRepository: RecordingCatalogRepository(),
      );
      await vm.reload();
      for (final input in [
        ('2026-02-30', '18.00'),
        ('2026-10-14', '18.001'),
        ('2026-10-14', 'oops'),
      ]) {
        vm.businessDateText = input.$1;
        vm.amountText = input.$2;
        vm.noteText = ' 保留 ';
        await vm.saveFromForm();
        expect(vm.errorMessage, isNotNull);
        expect(vm.businessDateText, input.$1);
        expect(vm.amountText, input.$2);
        expect(vm.noteText, ' 保留 ');
        expect(vm.isSaving, isFalse);
        expect(repo.createCashBillCalls, 0);
      }
      vm.businessDateText = '2026-10-14';
      vm.amountText = '18.00';
      vm.categoryId = null;
      await vm.saveFromForm();
      expect(vm.errorMessage, contains('分类'));
      expect(repo.createCashBillCalls, 0);
      vm.categoryId = 1;
      vm.accountId = null;
      await vm.saveFromForm();
      expect(vm.errorMessage, contains('账户'));
      expect(repo.createCashBillCalls, 0);
      vm.accountId = 1;
      await vm.saveFromForm();
      expect(repo.createCashBillCalls, 1);
      vm.dispose();
    },
  );

  test(
    'direction and field changes cannot unlock committed form after failed refresh',
    () async {
      final repo = RecordingCashBillRepository();
      final vm = CashLedgerViewModel(
        cashBillRepository: repo,
        catalogRepository: RecordingCatalogRepository(),
      );
      await vm.reload();
      vm.amountText = '10.00';
      repo.refreshThrows = true;
      await vm.saveFromForm();
      vm.setDirection(CashDirection.income);
      vm.categoryId = 2;
      vm.amountText = '20.00';
      vm.noteText = 'changed';
      expect(vm.canSubmit, isFalse);
      await vm.saveFromForm();
      expect(repo.createCashBillCalls, 1);
      vm.beginNewCashBill();
      await vm.saveCashBill(validDraft);
      expect(repo.createCashBillCalls, 2);
      vm.dispose();
    },
  );

  test(
    'status validation, commit errors and pending submissions stay at shared boundary',
    () async {
      final repo = RecordingCashBillRepository();
      final bill = await repo.createCashBill(validDraft);
      final vm = CashLedgerViewModel(
        cashBillRepository: repo,
        catalogRepository: RecordingCatalogRepository(),
      );
      vm.includeVoid = true;
      await vm.reload();
      await vm.voidBill(bill, '   ');
      expect(vm.errorMessage, contains('原因'));
      expect(repo.voidCashBillCalls, 0);
      final gate = Completer<void>();
      repo.statusGate = gate.future;
      repo.statusError = Exception('数据库拒绝');
      final first = vm.voidBill(bill, '保留原因');
      await Future<void>.delayed(Duration.zero);
      expect(vm.isSaving, isTrue);
      await vm.voidBill(bill, '第二次');
      expect(repo.voidCashBillCalls, 1);
      gate.complete();
      await first;
      expect(vm.isSaving, isFalse);
      expect(vm.errorMessage, contains('数据库拒绝'));
      expect(vm.billById(bill.id)!.isVoid, isFalse);
      repo.statusGate = null;
      repo.statusError = null;
      await vm.voidBill(bill, '重试');
      final voided = vm.billById(bill.id)!;
      repo.statusError = Exception('恢复超限');
      await vm.restoreBill(voided, '恢复原因');
      expect(vm.errorMessage, contains('恢复超限'));
      expect(vm.billById(bill.id)!.isVoid, isTrue);
      vm.dispose();
    },
  );

  test(
    'status commit plus refresh failure cannot repeat cached action',
    () async {
      final repo = RecordingCashBillRepository();
      final bill = await repo.createCashBill(validDraft);
      final vm = CashLedgerViewModel(
        cashBillRepository: repo,
        catalogRepository: RecordingCatalogRepository(),
      );
      vm.includeVoid = true;
      await vm.reload();
      repo.refreshThrows = true;
      await vm.voidBill(bill, '作废');
      expect(vm.errorMessage, contains('已作废，但刷新失败'));
      await vm.voidBill(bill, '不能重复');
      expect(repo.voidCashBillCalls, 1);
      repo.refreshThrows = false;
      await vm.reload();
      final voided = vm.billById(bill.id)!;
      repo.refreshThrows = true;
      await vm.restoreBill(voided, '恢复');
      expect(vm.errorMessage, contains('已恢复，但刷新失败'));
      await vm.restoreBill(voided, '不能重复');
      expect(repo.restoreCashBillCalls, 1);
      repo.refreshThrows = false;
      await vm.reload();
      await vm.voidBill(vm.billById(bill.id)!, '下一轮');
      expect(repo.voidCashBillCalls, 2);
      vm.dispose();
    },
  );
}
