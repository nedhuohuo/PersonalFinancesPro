import 'package:personal_finances_pro/features/catalog/domain/catalog_models.dart';

import 'ledger_models.dart';

abstract interface class LedgerRepository {
  Future<int> createPurchase(
    PurchaseDraft draft, {
    PurchasePaymentDraft? initialPayment,
  });
  Future<void> recordPurchasePayment({
    required int purchaseId,
    required PurchasePaymentDraft payment,
  });
  Future<void> voidPurchasePayment({
    required int paymentId,
    required String reason,
  });
  Future<void> restorePurchasePayment({
    required int paymentId,
    required String reason,
  });
  Future<void> voidPurchaseWithoutActivePayments({
    required int purchaseId,
    required String reason,
  });
  Future<void> restorePurchase({
    required int purchaseId,
    required String reason,
  });
  Future<void> adjustPurchase(PurchaseAdjustmentDraft draft);
  Future<void> voidPurchaseAdjustment({
    required int adjustmentId,
    required String reason,
  });
  Future<void> restorePurchaseAdjustment({
    required int adjustmentId,
    required String reason,
  });
  Future<List<Purchase>> listPurchases(PurchaseFilter filter);
  Future<PurchaseDetail> getPurchaseDetail(int purchaseId);

  Future<int> createSupplierOpeningDebt(SupplierOpeningDebtDraft draft);
  Future<void> paySupplierOpeningDebt({
    required int openingDebtId,
    required PurchasePaymentDraft payment,
  });
  Future<void> voidSupplierOpeningDebtPayment({
    required int paymentId,
    required String reason,
  });
  Future<void> restoreSupplierOpeningDebtPayment({
    required int paymentId,
    required String reason,
  });
  Future<List<SupplierOpeningDebt>> listSupplierOpeningDebts({
    BusinessScope? scope,
    int? supplierId,
    bool includeVoid = false,
  });
  Future<SupplierOpeningDebtDetail> getSupplierOpeningDebtDetail(
    int openingDebtId,
  );

  Future<int> createProblemResale(ProblemResaleDraft draft);
  Future<void> voidProblemResale({
    required int resaleId,
    required String reason,
  });
  Future<void> restoreProblemResale({
    required int resaleId,
    required String reason,
  });
  Future<List<ProblemResale>> listProblemResales(ProblemResaleFilter filter);
  Future<ProblemResaleDetail> getProblemResaleDetail(int resaleId);

  Future<int> createCourierAccount(CourierAccountDraft draft);
  Future<void> recordCourierTopUp(CourierCashEventDraft draft);
  Future<void> recordCourierConsume(CourierConsumeDraft draft);
  Future<void> recordCourierRefund(CourierCashEventDraft draft);
  Future<void> voidCourierEvent({required int eventId, required String reason});
  Future<void> restoreCourierEvent({
    required int eventId,
    required String reason,
  });
  Future<List<CourierAccount>> listCourierAccounts({
    bool includeInactive = false,
  });
  Future<CourierAccountDetail> getCourierAccountDetail(int courierAccountId);
}
