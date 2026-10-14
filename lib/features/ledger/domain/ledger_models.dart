import 'package:personal_finances_pro/core/domain/local_date.dart';
import 'package:personal_finances_pro/core/domain/money.dart';
import 'package:personal_finances_pro/features/catalog/domain/catalog_models.dart';

enum EntrySource { manual, ai }

enum BusinessOrigin {
  ordinary,
  purchasePayment,
  supplierRefund,
  resaleIncome,
  resaleFee,
  courierTopUp,
  courierRefund,
  openingDebtPayment,
}

enum LinkedBillType {
  purchasePayment,
  supplierRefund,
  openingDebtPayment,
  problemResaleIncome,
  problemResaleFee,
  courierTopUp,
  courierRefund,
}

enum PurchaseAdjustmentKind { unpaidWaiver, paidRefund }

enum CourierEventType { opening, topUp, consume, refund }

final class CashBillDraft {
  const CashBillDraft({
    required this.businessDate,
    required this.direction,
    required this.amount,
    required this.scope,
    required this.categoryId,
    required this.accountId,
    this.partyId,
    this.note = '',
  });

  final LocalDate businessDate;
  final CashDirection direction;
  final Money amount;
  final BusinessScope scope;
  final int categoryId;
  final int accountId;
  final int? partyId;
  final String note;
}

final class CashBill {
  const CashBill({
    required this.id,
    required this.businessDate,
    required this.direction,
    required this.amount,
    required this.scope,
    required this.categoryId,
    required this.accountId,
    required this.partyId,
    required this.note,
    required this.entrySource,
    required this.businessOrigin,
    required this.linkedType,
    required this.linkedId,
    required this.isVoid,
    required this.createdAtUtc,
    required this.updatedAtUtc,
  });

  final int id;
  final LocalDate businessDate;
  final CashDirection direction;
  final Money amount;
  final BusinessScope scope;
  final int categoryId;
  final int accountId;
  final int? partyId;
  final String note;
  final EntrySource entrySource;
  final BusinessOrigin businessOrigin;
  final LinkedBillType? linkedType;
  final int? linkedId;
  final bool isVoid;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
}

final class CashBillFilter {
  const CashBillFilter({
    this.startDate,
    this.endDate,
    this.scope,
    this.categoryId,
    this.partyId,
    this.noteQuery,
    this.includeVoid = false,
  });

  final LocalDate? startDate;
  final LocalDate? endDate;
  final BusinessScope? scope;
  final int? categoryId;
  final int? partyId;
  final String? noteQuery;
  final bool includeVoid;
}

final class PurchaseItemDraft {
  const PurchaseItemDraft({
    required this.description,
    required this.quantity,
    required this.unitPrice,
  });

  final String description;
  final int quantity;
  final Money unitPrice;
}

final class PurchaseDraft {
  PurchaseDraft({
    required this.supplierId,
    required this.scope,
    required this.businessDate,
    required Iterable<PurchaseItemDraft> items,
    required this.supplierFreight,
    this.note = '',
  }) : items = List.unmodifiable(items);

  final int supplierId;
  final BusinessScope scope;
  final LocalDate businessDate;
  final List<PurchaseItemDraft> items;
  final Money supplierFreight;
  final String note;
}

final class PurchasePaymentDraft {
  const PurchasePaymentDraft({
    required this.businessDate,
    required this.amount,
    required this.accountId,
    required this.categoryId,
    this.note = '',
  });

  final LocalDate businessDate;
  final Money amount;
  final int accountId;
  final int categoryId;
  final String note;
}

final class PurchaseAdjustmentDraft {
  const PurchaseAdjustmentDraft({
    required this.purchaseId,
    required this.kind,
    required this.amount,
    required this.reason,
    required this.categoryId,
    this.businessDate,
    this.accountId,
  });

  final int purchaseId;
  final PurchaseAdjustmentKind kind;
  final Money amount;
  final String reason;
  final int categoryId;
  final LocalDate? businessDate;
  final int? accountId;
}

final class SupplierOpeningDebtDraft {
  const SupplierOpeningDebtDraft({
    required this.supplierId,
    required this.scope,
    required this.businessDate,
    required this.amount,
    this.note = '',
  });

  final int supplierId;
  final BusinessScope scope;
  final LocalDate businessDate;
  final Money amount;
  final String note;
}

final class ProblemResaleFeeDraft {
  const ProblemResaleFeeDraft({
    required this.categoryId,
    required this.accountId,
    required this.amount,
    this.partyId,
    this.note = '',
  });

  final int categoryId;
  final int accountId;
  final Money amount;
  final int? partyId;
  final String note;
}

final class ProblemResaleDraft {
  ProblemResaleDraft({
    required this.scope,
    required this.businessDate,
    required this.description,
    required this.quantity,
    required this.incomeAmount,
    required this.incomeAccountId,
    required this.incomeCategoryId,
    required this.buyerId,
    required this.channelId,
    required this.issueNote,
    required Iterable<ProblemResaleFeeDraft> fees,
  }) : fees = List.unmodifiable(fees);

  final BusinessScope scope;
  final LocalDate businessDate;
  final String description;
  final int quantity;
  final Money incomeAmount;
  final int incomeAccountId;
  final int incomeCategoryId;
  final int buyerId;
  final int channelId;
  final String issueNote;
  final List<ProblemResaleFeeDraft> fees;
}

final class CourierAccountDraft {
  const CourierAccountDraft({
    required this.name,
    required this.openingBalance,
    required this.businessDate,
  });

  final String name;
  final Money openingBalance;
  final LocalDate businessDate;
}

final class CourierCashEventDraft {
  const CourierCashEventDraft({
    required this.courierAccountId,
    required this.scope,
    required this.businessDate,
    required this.amount,
    required this.accountId,
    required this.categoryId,
    this.note = '',
  });

  final int courierAccountId;
  final BusinessScope scope;
  final LocalDate businessDate;
  final Money amount;
  final int accountId;
  final int categoryId;
  final String note;
}

final class CourierConsumeDraft {
  const CourierConsumeDraft({
    required this.courierAccountId,
    required this.scope,
    required this.businessDate,
    required this.amount,
    this.note = '',
  });

  final int courierAccountId;
  final BusinessScope scope;
  final LocalDate businessDate;
  final Money amount;
  final String note;
}

final class PurchaseItem {
  const PurchaseItem({
    required this.id,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  final int id;
  final String description;
  final int quantity;
  final Money unitPrice;
  final Money lineTotal;
}

final class PurchasePayment {
  const PurchasePayment({
    required this.id,
    required this.purchaseId,
    required this.cashBillId,
    required this.amount,
    required this.isVoid,
  });

  final int id;
  final int purchaseId;
  final int cashBillId;
  final Money amount;
  final bool isVoid;
}

final class PurchaseAdjustment {
  const PurchaseAdjustment({
    required this.id,
    required this.purchaseId,
    required this.kind,
    required this.amount,
    required this.cashBillId,
    required this.reason,
    required this.isVoid,
  });

  final int id;
  final int purchaseId;
  final PurchaseAdjustmentKind kind;
  final Money amount;
  final int? cashBillId;
  final String reason;
  final bool isVoid;
}

final class PurchasePosition {
  const PurchasePosition({
    required this.effectiveTotal,
    required this.paidNet,
    required this.payable,
  });

  final Money effectiveTotal;
  final Money paidNet;
  final Money payable;
}

final class Purchase {
  const Purchase({
    required this.id,
    required this.supplierId,
    required this.scope,
    required this.businessDate,
    required this.originalTotal,
    required this.supplierFreight,
    required this.note,
    required this.isVoid,
    required this.position,
  });

  final int id;
  final int supplierId;
  final BusinessScope scope;
  final LocalDate businessDate;
  final Money originalTotal;
  final Money supplierFreight;
  final String note;
  final bool isVoid;
  final PurchasePosition position;
}

final class PurchaseDetail {
  PurchaseDetail({
    required this.purchase,
    required Iterable<PurchaseItem> items,
    required Iterable<PurchasePayment> payments,
    required Iterable<PurchaseAdjustment> adjustments,
  }) : items = List.unmodifiable(items),
       payments = List.unmodifiable(payments),
       adjustments = List.unmodifiable(adjustments);

  final Purchase purchase;
  final List<PurchaseItem> items;
  final List<PurchasePayment> payments;
  final List<PurchaseAdjustment> adjustments;
}

final class PurchaseFilter {
  const PurchaseFilter({this.scope, this.supplierId, this.includeVoid = false});

  final BusinessScope? scope;
  final int? supplierId;
  final bool includeVoid;
}

final class SupplierOpeningDebt {
  const SupplierOpeningDebt({
    required this.id,
    required this.supplierId,
    required this.scope,
    required this.businessDate,
    required this.amount,
    required this.paid,
    required this.isVoid,
    required this.note,
  });

  final int id;
  final int supplierId;
  final BusinessScope scope;
  final LocalDate businessDate;
  final Money amount;
  final Money paid;
  final bool isVoid;
  final String note;
}

final class SupplierOpeningDebtPayment {
  const SupplierOpeningDebtPayment({
    required this.id,
    required this.openingDebtId,
    required this.cashBillId,
    required this.amount,
    required this.isVoid,
  });

  final int id;
  final int openingDebtId;
  final int cashBillId;
  final Money amount;
  final bool isVoid;
}

final class SupplierOpeningDebtDetail {
  SupplierOpeningDebtDetail({
    required this.debt,
    required Iterable<SupplierOpeningDebtPayment> payments,
  }) : payments = List.unmodifiable(payments);

  final SupplierOpeningDebt debt;
  final List<SupplierOpeningDebtPayment> payments;
}

final class ProblemResaleFee {
  const ProblemResaleFee({
    required this.id,
    required this.cashBillId,
    required this.categoryId,
    required this.accountId,
    required this.amount,
  });

  final int id;
  final int cashBillId;
  final int categoryId;
  final int accountId;
  final Money amount;
}

final class ProblemResale {
  const ProblemResale({
    required this.id,
    required this.scope,
    required this.businessDate,
    required this.description,
    required this.quantity,
    required this.incomeAmount,
    required this.incomeCashBillId,
    required this.buyerId,
    required this.channelId,
    required this.issueNote,
    required this.isVoid,
  });

  final int id;
  final BusinessScope scope;
  final LocalDate businessDate;
  final String description;
  final int quantity;
  final Money incomeAmount;
  final int incomeCashBillId;
  final int buyerId;
  final int channelId;
  final String issueNote;
  final bool isVoid;
}

final class ProblemResaleDetail {
  ProblemResaleDetail({
    required this.resale,
    required Iterable<ProblemResaleFee> fees,
    required this.netRecovery,
  }) : fees = List.unmodifiable(fees);

  final ProblemResale resale;
  final List<ProblemResaleFee> fees;
  final Money netRecovery;
}

final class ProblemResaleFilter {
  const ProblemResaleFilter({
    this.scope,
    this.channelId,
    this.includeVoid = false,
  });

  final BusinessScope? scope;
  final int? channelId;
  final bool includeVoid;
}

final class CourierAccount {
  const CourierAccount({
    required this.id,
    required this.name,
    required this.isActive,
    required this.recordedBalance,
  });

  final int id;
  final String name;
  final bool isActive;
  final Money recordedBalance;
}

final class CourierEvent {
  const CourierEvent({
    required this.id,
    required this.courierAccountId,
    required this.scope,
    required this.businessDate,
    required this.eventType,
    required this.amount,
    required this.cashBillId,
    required this.balanceAfter,
    required this.note,
    required this.isVoid,
  });

  final int id;
  final int courierAccountId;
  final BusinessScope? scope;
  final LocalDate businessDate;
  final CourierEventType eventType;
  final Money amount;
  final int? cashBillId;
  final Money balanceAfter;
  final String note;
  final bool isVoid;
}

final class CourierAccountDetail {
  CourierAccountDetail({
    required this.account,
    required Iterable<CourierEvent> events,
  }) : events = List.unmodifiable(events);

  final CourierAccount account;
  final List<CourierEvent> events;
}
