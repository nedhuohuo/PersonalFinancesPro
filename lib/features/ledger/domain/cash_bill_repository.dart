import 'ledger_models.dart';

abstract interface class CashBillRepository {
  Future<CashBill> createCashBill(CashBillDraft draft);
  Future<CashBill> updateCashBill({
    required int id,
    required CashBillDraft draft,
  });
  Future<void> voidCashBill(int id, {required String reason});
  Future<void> restoreCashBill(int id, {required String reason});
  Future<List<CashBill>> listCashBills(CashBillFilter filter);
}
