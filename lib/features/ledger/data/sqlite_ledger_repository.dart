import 'dart:convert';

import 'package:personal_finances_pro/core/data/sqlite_aggregate_guard.dart';
import 'package:personal_finances_pro/core/data/sqlite_statement.dart';
import 'package:personal_finances_pro/core/domain/local_date.dart';
import 'package:personal_finances_pro/core/domain/money.dart';
import 'package:personal_finances_pro/features/catalog/domain/catalog_models.dart';
import 'package:personal_finances_pro/features/ledger/data/sqlite_cash_bill_repository.dart';
import 'package:personal_finances_pro/features/ledger/domain/ledger_calculations.dart';
import 'package:personal_finances_pro/features/ledger/domain/ledger_models.dart';
import 'package:personal_finances_pro/features/ledger/domain/ledger_repository.dart';
import 'package:sqflite/sqflite.dart';

final class SqliteLedgerRepository implements LedgerRepository {
  SqliteLedgerRepository({
    required Database database,
    required SqliteCashBillRepository cashBills,
  }) : _db = database {
    cashBills.hashCode;
  }

  final Database _db;

  @override
  Future<int> createPurchase(
    PurchaseDraft draft, {
    PurchasePaymentDraft? initialPayment,
  }) async {
    _validatePurchaseDraft(draft);
    return _db.transaction((txn) async {
      await _requireParty(txn, draft.supplierId, PartyKind.supplier);
      await _validateScope(txn, draft.scope);
      if (initialPayment != null) {
        _validatePositive(initialPayment.amount);
        await _validatePaymentCashRefs(
          txn,
          initialPayment,
          CashDirection.expense,
        );
      }
      final itemTotals = [
        for (final item in draft.items)
          Money.checkedProduct(
            quantity: item.quantity,
            unitPrice: item.unitPrice,
          ),
      ];
      final itemTotal = Money.sumCents(itemTotals.map((money) => money.cents));
      final originalTotal = Money.sumCents([
        itemTotal.cents,
        draft.supplierFreight.cents,
      ]);
      _validatePositive(originalTotal);
      final now = utcNowIso();
      final purchaseId = await txn.insert('purchases', {
        'supplier_id': draft.supplierId,
        'business_date': draft.businessDate.value,
        ..._scopeValues(draft.scope),
        'item_total_cents': itemTotal.cents,
        'supplier_freight_cents': draft.supplierFreight.cents,
        'original_total_cents': originalTotal.cents,
        'effective_total_cents': originalTotal.cents,
        'note': draft.note.trim(),
        'created_at_utc': now,
        'updated_at_utc': now,
      });
      for (var i = 0; i < draft.items.length; i += 1) {
        final item = draft.items[i];
        await txn.insert('purchase_items', {
          'purchase_id': purchaseId,
          'description': item.description.trim(),
          'quantity': item.quantity,
          'unit_price_cents': item.unitPrice.cents,
          'line_total_cents': itemTotals[i].cents,
        });
      }
      if (initialPayment != null) {
        await _insertPurchasePayment(txn, purchaseId, initialPayment);
      }
      await _refreshPurchasePosition(txn, purchaseId);
      await SqliteAggregateGuard.ensureAllActiveTotalsWithinCap(txn);
      await _audit(
        txn,
        'purchase',
        purchaseId,
        'create',
        '',
        await _row(txn, 'purchases', purchaseId),
      );
      return purchaseId;
    });
  }

  @override
  Future<void> recordPurchasePayment({
    required int purchaseId,
    required PurchasePaymentDraft payment,
  }) async {
    _validatePositive(payment.amount);
    await _db.transaction((txn) async {
      final purchase = await _activePurchase(txn, purchaseId);
      await _validatePaymentCashRefs(txn, payment, CashDirection.expense);
      await _insertPurchasePayment(txn, purchaseId, payment);
      await _refreshPurchasePosition(txn, purchaseId);
      await SqliteAggregateGuard.ensureAllActiveTotalsWithinCap(txn);
      await _audit(txn, 'purchase', purchaseId, 'record_payment', '', purchase);
    });
  }

  @override
  Future<void> voidPurchasePayment({
    required int paymentId,
    required String reason,
  }) async {
    final why = _validatedReason(reason);
    await _db.transaction((txn) async {
      final payment = await _row(txn, 'purchase_payments', paymentId);
      if (sqliteBool(payment['is_void'])) return;
      final now = utcNowIso();
      await txn.update(
        'purchase_payments',
        {'is_void': 1, 'voided_at_utc': now, 'updated_at_utc': now},
        where: 'id = ?',
        whereArgs: [paymentId],
      );
      await _setCashVoid(txn, payment['cash_bill_id']! as int, true, now);
      await _refreshPurchasePosition(txn, payment['purchase_id']! as int);
      await SqliteAggregateGuard.ensureAllActiveTotalsWithinCap(txn);
      await _audit(
        txn,
        'purchase_payment',
        paymentId,
        'void',
        why,
        await _row(txn, 'purchase_payments', paymentId),
      );
    });
  }

  @override
  Future<void> restorePurchasePayment({
    required int paymentId,
    required String reason,
  }) async {
    final why = _validatedReason(reason);
    await _db.transaction((txn) async {
      final payment = await _row(txn, 'purchase_payments', paymentId);
      if (!sqliteBool(payment['is_void'])) return;
      await _activePurchase(txn, payment['purchase_id']! as int);
      final now = utcNowIso();
      await txn.update(
        'purchase_payments',
        {'is_void': 0, 'voided_at_utc': null, 'updated_at_utc': now},
        where: 'id = ?',
        whereArgs: [paymentId],
      );
      await _setCashVoid(txn, payment['cash_bill_id']! as int, false, now);
      await _refreshPurchasePosition(txn, payment['purchase_id']! as int);
      await SqliteAggregateGuard.ensureAllActiveTotalsWithinCap(txn);
      await _audit(
        txn,
        'purchase_payment',
        paymentId,
        'restore',
        why,
        await _row(txn, 'purchase_payments', paymentId),
      );
    });
  }

  @override
  Future<void> voidPurchaseWithoutActivePayments({
    required int purchaseId,
    required String reason,
  }) async {
    final why = _validatedReason(reason);
    await _db.transaction((txn) async {
      final purchase = await _activePurchase(txn, purchaseId);
      final activePayments = await txn.query(
        'purchase_payments',
        where: 'purchase_id = ? AND is_void = 0',
        whereArgs: [purchaseId],
      );
      final activePaidRefunds = await txn.query(
        'purchase_adjustments',
        where: 'purchase_id = ? AND kind = ? AND is_void = 0',
        whereArgs: [purchaseId, PurchaseAdjustmentKind.paidRefund.name],
      );
      if (activePayments.isNotEmpty || activePaidRefunds.isNotEmpty) {
        throw StateError('采购已有活动付款或退款');
      }
      final now = utcNowIso();
      await txn.update(
        'purchases',
        {'is_void': 1, 'voided_at_utc': now, 'updated_at_utc': now},
        where: 'id = ?',
        whereArgs: [purchaseId],
      );
      await SqliteAggregateGuard.ensureAllActiveTotalsWithinCap(txn);
      await _audit(txn, 'purchase', purchaseId, 'void', why, purchase);
    });
  }

  @override
  Future<void> restorePurchase({
    required int purchaseId,
    required String reason,
  }) async {
    final why = _validatedReason(reason);
    await _db.transaction((txn) async {
      final purchase = await _row(txn, 'purchases', purchaseId);
      if (!sqliteBool(purchase['is_void'])) return;
      final now = utcNowIso();
      await txn.update(
        'purchases',
        {'is_void': 0, 'voided_at_utc': null, 'updated_at_utc': now},
        where: 'id = ?',
        whereArgs: [purchaseId],
      );
      await _refreshPurchasePosition(txn, purchaseId);
      await SqliteAggregateGuard.ensureAllActiveTotalsWithinCap(txn);
      await _audit(
        txn,
        'purchase',
        purchaseId,
        'restore',
        why,
        await _row(txn, 'purchases', purchaseId),
      );
    });
  }

  @override
  Future<void> adjustPurchase(PurchaseAdjustmentDraft draft) async {
    _validatePositive(draft.amount);
    final why = _validatedReason(draft.reason);
    await _db.transaction((txn) async {
      final purchase = await _activePurchase(txn, draft.purchaseId);
      await _requireActiveId(txn, 'categories', draft.categoryId);
      int? cashBillId;
      if (draft.kind == PurchaseAdjustmentKind.paidRefund) {
        if (draft.accountId == null) throw const FormatException('收款账户不能为空');
        final payment = PurchasePaymentDraft(
          businessDate:
              draft.businessDate ??
              LocalDate.parse(purchase['business_date']! as String),
          amount: draft.amount,
          accountId: draft.accountId!,
          categoryId: draft.categoryId,
        );
        await _validatePaymentCashRefs(txn, payment, CashDirection.income);
        cashBillId = await _insertLinkedCashBill(
          txn,
          businessDate: payment.businessDate,
          direction: CashDirection.income,
          amount: draft.amount,
          scope: businessScopeFromSql(purchase),
          categoryId: draft.categoryId,
          accountId: draft.accountId!,
          partyId: purchase['supplier_id']! as int,
          note: why,
          origin: BusinessOrigin.supplierRefund,
          linkedType: LinkedBillType.supplierRefund,
          linkedId: draft.purchaseId,
        );
      }
      final now = utcNowIso();
      final adjustmentId = await txn.insert('purchase_adjustments', {
        'purchase_id': draft.purchaseId,
        'kind': draft.kind.name,
        'amount_cents': draft.amount.cents,
        'cash_bill_id': cashBillId,
        'reason': why,
        'created_at_utc': now,
        'updated_at_utc': now,
      });
      await _refreshPurchasePosition(txn, draft.purchaseId);
      await SqliteAggregateGuard.ensureAllActiveTotalsWithinCap(txn);
      await _audit(
        txn,
        'purchase_adjustment',
        adjustmentId,
        'create',
        why,
        await _row(txn, 'purchase_adjustments', adjustmentId),
      );
    });
  }

  @override
  Future<void> voidPurchaseAdjustment({
    required int adjustmentId,
    required String reason,
  }) async => _setPurchaseAdjustmentVoid(adjustmentId, true, reason);

  @override
  Future<void> restorePurchaseAdjustment({
    required int adjustmentId,
    required String reason,
  }) async => _setPurchaseAdjustmentVoid(adjustmentId, false, reason);

  @override
  Future<List<Purchase>> listPurchases(PurchaseFilter filter) async {
    final rows = await _db.query(
      'purchases',
      where: _purchaseWhere(filter).$1,
      whereArgs: _purchaseWhere(filter).$2,
      orderBy: 'business_date ASC, id ASC',
    );
    return Future.wait(rows.map((row) => _purchaseFromRow(_db, row)));
  }

  @override
  Future<PurchaseDetail> getPurchaseDetail(int purchaseId) async {
    final purchase = await _row(_db, 'purchases', purchaseId);
    final items = await _db.query(
      'purchase_items',
      where: 'purchase_id = ?',
      whereArgs: [purchaseId],
      orderBy: 'id ASC',
    );
    final payments = await _db.query(
      'purchase_payments',
      where: 'purchase_id = ?',
      whereArgs: [purchaseId],
      orderBy: 'id ASC',
    );
    final adjustments = await _db.query(
      'purchase_adjustments',
      where: 'purchase_id = ?',
      whereArgs: [purchaseId],
      orderBy: 'id ASC',
    );
    return PurchaseDetail(
      purchase: await _purchaseFromRow(_db, purchase),
      items: items.map(_purchaseItemFromRow),
      payments: payments.map(_purchasePaymentFromRow),
      adjustments: adjustments.map(_purchaseAdjustmentFromRow),
    );
  }

  @override
  Future<int> createSupplierOpeningDebt(SupplierOpeningDebtDraft draft) async {
    _validatePositive(draft.amount);
    return _db.transaction((txn) async {
      await _requireParty(txn, draft.supplierId, PartyKind.supplier);
      await _validateScope(txn, draft.scope);
      final now = utcNowIso();
      final id = await txn.insert('supplier_opening_debts', {
        'supplier_id': draft.supplierId,
        'business_date': draft.businessDate.value,
        ..._scopeValues(draft.scope),
        'amount_cents': draft.amount.cents,
        'paid_cents': 0,
        'note': draft.note.trim(),
        'created_at_utc': now,
        'updated_at_utc': now,
      });
      await SqliteAggregateGuard.ensureAllActiveTotalsWithinCap(txn);
      await _audit(
        txn,
        'supplier_opening_debt',
        id,
        'create',
        '',
        await _row(txn, 'supplier_opening_debts', id),
      );
      return id;
    });
  }

  @override
  Future<void> paySupplierOpeningDebt({
    required int openingDebtId,
    required PurchasePaymentDraft payment,
  }) async {
    _validatePositive(payment.amount);
    await _db.transaction((txn) async {
      final debt = await _activeDebt(txn, openingDebtId);
      await _validatePaymentCashRefs(txn, payment, CashDirection.expense);
      final cashId = await _insertLinkedCashBill(
        txn,
        businessDate: payment.businessDate,
        direction: CashDirection.expense,
        amount: payment.amount,
        scope: businessScopeFromSql(debt),
        categoryId: payment.categoryId,
        accountId: payment.accountId,
        partyId: debt['supplier_id']! as int,
        note: payment.note.trim(),
        origin: BusinessOrigin.openingDebtPayment,
        linkedType: LinkedBillType.openingDebtPayment,
        linkedId: openingDebtId,
      );
      final now = utcNowIso();
      final id = await txn.insert('supplier_opening_debt_payments', {
        'opening_debt_id': openingDebtId,
        'cash_bill_id': cashId,
        'amount_cents': payment.amount.cents,
        'created_at_utc': now,
        'updated_at_utc': now,
      });
      await _refreshOpeningDebtPaid(txn, openingDebtId);
      await SqliteAggregateGuard.ensureAllActiveTotalsWithinCap(txn);
      await _audit(
        txn,
        'supplier_opening_debt_payment',
        id,
        'create',
        '',
        await _row(txn, 'supplier_opening_debt_payments', id),
      );
    });
  }

  @override
  Future<void> voidSupplierOpeningDebtPayment({
    required int paymentId,
    required String reason,
  }) async => _setOpeningDebtPaymentVoid(paymentId, true, reason);

  @override
  Future<void> restoreSupplierOpeningDebtPayment({
    required int paymentId,
    required String reason,
  }) async => _setOpeningDebtPaymentVoid(paymentId, false, reason);

  @override
  Future<List<SupplierOpeningDebt>> listSupplierOpeningDebts({
    BusinessScope? scope,
    int? supplierId,
    bool includeVoid = false,
  }) async {
    final where = <String>[];
    final args = <Object?>[];
    if (!includeVoid) where.add('is_void = 0');
    if (supplierId != null) {
      where.add('supplier_id = ?');
      args.add(supplierId);
    }
    _addScopeWhere(where, args, scope);
    final rows = await _db.query(
      'supplier_opening_debts',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args,
      orderBy: 'business_date ASC, id ASC',
    );
    return rows.map(_debtFromRow).toList();
  }

  @override
  Future<SupplierOpeningDebtDetail> getSupplierOpeningDebtDetail(
    int openingDebtId,
  ) async {
    final debt = await _row(_db, 'supplier_opening_debts', openingDebtId);
    final payments = await _db.query(
      'supplier_opening_debt_payments',
      where: 'opening_debt_id = ?',
      whereArgs: [openingDebtId],
      orderBy: 'id ASC',
    );
    return SupplierOpeningDebtDetail(
      debt: _debtFromRow(debt),
      payments: payments.map(_debtPaymentFromRow),
    );
  }

  @override
  Future<int> createProblemResale(ProblemResaleDraft draft) async {
    _validateProblemResaleDraft(draft);
    return _db.transaction((txn) async {
      await _validateScope(txn, draft.scope);
      await _requireParty(txn, draft.buyerId, PartyKind.buyer);
      await _requireActiveId(txn, 'resale_channels', draft.channelId);
      await _requireCategory(txn, draft.incomeCategoryId, CashDirection.income);
      await _requireActiveId(txn, 'account_labels', draft.incomeAccountId);
      for (final fee in draft.fees) {
        await _requireCategory(txn, fee.categoryId, CashDirection.expense);
        await _requireActiveId(txn, 'account_labels', fee.accountId);
        if (fee.partyId != null) {
          await _requireActiveId(txn, 'parties', fee.partyId!);
        }
      }
      final now = utcNowIso();
      final resaleId = await txn.insert('problem_resales', {
        'business_date': draft.businessDate.value,
        ..._scopeValues(draft.scope),
        'description': draft.description.trim(),
        'quantity': draft.quantity,
        'income_cents': draft.incomeAmount.cents,
        'income_cash_bill_id': null,
        'buyer_id': draft.buyerId,
        'channel_id': draft.channelId,
        'issue_note': draft.issueNote.trim(),
        'created_at_utc': now,
        'updated_at_utc': now,
      });
      final incomeCashId = await _insertLinkedCashBill(
        txn,
        businessDate: draft.businessDate,
        direction: CashDirection.income,
        amount: draft.incomeAmount,
        scope: draft.scope,
        categoryId: draft.incomeCategoryId,
        accountId: draft.incomeAccountId,
        partyId: draft.buyerId,
        note: draft.issueNote.trim(),
        origin: BusinessOrigin.resaleIncome,
        linkedType: LinkedBillType.problemResaleIncome,
        linkedId: resaleId,
      );
      await txn.update(
        'problem_resales',
        {'income_cash_bill_id': incomeCashId, 'updated_at_utc': utcNowIso()},
        where: 'id = ?',
        whereArgs: [resaleId],
      );
      for (final fee in draft.fees) {
        final cashId = await _insertLinkedCashBill(
          txn,
          businessDate: draft.businessDate,
          direction: CashDirection.expense,
          amount: fee.amount,
          scope: draft.scope,
          categoryId: fee.categoryId,
          accountId: fee.accountId,
          partyId: fee.partyId,
          note: fee.note.trim(),
          origin: BusinessOrigin.resaleFee,
          linkedType: LinkedBillType.problemResaleFee,
          linkedId: resaleId,
        );
        await txn.insert('problem_resale_fees', {
          'resale_id': resaleId,
          'cash_bill_id': cashId,
          'category_id': fee.categoryId,
          'account_id': fee.accountId,
          'amount_cents': fee.amount.cents,
          'created_at_utc': utcNowIso(),
        });
      }
      final row = await _row(txn, 'problem_resales', resaleId);
      if (row['income_cash_bill_id'] == null) throw StateError('转卖收入账单缺失');
      await SqliteAggregateGuard.ensureAllActiveTotalsWithinCap(txn);
      await _audit(txn, 'problem_resale', resaleId, 'create', '', row);
      return resaleId;
    });
  }

  @override
  Future<void> voidProblemResale({
    required int resaleId,
    required String reason,
  }) async => _setProblemResaleVoid(resaleId, true, reason);

  @override
  Future<void> restoreProblemResale({
    required int resaleId,
    required String reason,
  }) async => _setProblemResaleVoid(resaleId, false, reason);

  @override
  Future<List<ProblemResale>> listProblemResales(
    ProblemResaleFilter filter,
  ) async {
    final where = <String>[];
    final args = <Object?>[];
    if (!filter.includeVoid) where.add('is_void = 0');
    if (filter.channelId != null) {
      where.add('channel_id = ?');
      args.add(filter.channelId);
    }
    _addScopeWhere(where, args, filter.scope);
    final rows = await _db.query(
      'problem_resales',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args,
      orderBy: 'business_date ASC, id ASC',
    );
    return rows.map(_resaleFromRow).toList();
  }

  @override
  Future<ProblemResaleDetail> getProblemResaleDetail(int resaleId) async {
    final resale = await _row(_db, 'problem_resales', resaleId);
    final feeRows = await _db.query(
      'problem_resale_fees',
      where: 'resale_id = ?',
      whereArgs: [resaleId],
      orderBy: 'id ASC',
    );
    final feeCents = <int>[];
    for (final fee in feeRows) {
      final cash = await _row(_db, 'cash_bills', fee['cash_bill_id']! as int);
      if (!sqliteBool(cash['is_void'])) {
        feeCents.add(fee['amount_cents']! as int);
      }
    }
    final incomeCash = await _row(
      _db,
      'cash_bills',
      resale['income_cash_bill_id']! as int,
    );
    final activeIncome =
        sqliteBool(resale['is_void']) || sqliteBool(incomeCash['is_void'])
            ? 0
            : resale['income_cents']! as int;
    return ProblemResaleDetail(
      resale: _resaleFromRow(resale),
      fees: feeRows.map(_resaleFeeFromRow),
      netRecovery: Money.sumCents([
        activeIncome,
        -Money.sumCents(feeCents).cents,
      ]),
    );
  }

  @override
  Future<int> createCourierAccount(CourierAccountDraft draft) async {
    final name = _validatedName(draft.name);
    _validateNonNegative(draft.openingBalance);
    return _db.transaction((txn) async {
      final now = utcNowIso();
      final id = await txn.insert('courier_accounts', {
        'name': name,
        'created_at_utc': now,
        'updated_at_utc': now,
      });
      final eventId = await txn.insert('courier_events', {
        'courier_account_id': id,
        'business_date': draft.businessDate.value,
        'event_type': CourierEventType.opening.name,
        'amount_cents': draft.openingBalance.cents,
        'scope_type': null,
        'shop_id': null,
        'cash_bill_id': null,
        'balance_after_cents': draft.openingBalance.cents,
        'note': '',
        'created_at_utc': now,
        'updated_at_utc': now,
      });
      await _recalculateCourier(txn, id);
      await SqliteAggregateGuard.ensureAllActiveTotalsWithinCap(txn);
      await _audit(
        txn,
        'courier_account',
        id,
        'create',
        '',
        await _row(txn, 'courier_accounts', id),
      );
      await _audit(
        txn,
        'courier_event',
        eventId,
        'create',
        '',
        await _row(txn, 'courier_events', eventId),
      );
      return id;
    });
  }

  @override
  Future<void> recordCourierTopUp(CourierCashEventDraft draft) =>
      _recordCourierCashEvent(draft, CourierEventType.topUp);

  @override
  Future<void> recordCourierRefund(CourierCashEventDraft draft) =>
      _recordCourierCashEvent(draft, CourierEventType.refund);

  @override
  Future<void> recordCourierConsume(CourierConsumeDraft draft) async {
    _validatePositive(draft.amount);
    await _db.transaction((txn) async {
      await _requireActiveId(txn, 'courier_accounts', draft.courierAccountId);
      await _validateScope(txn, draft.scope);
      final now = utcNowIso();
      final id = await txn.insert('courier_events', {
        'courier_account_id': draft.courierAccountId,
        'business_date': draft.businessDate.value,
        'event_type': CourierEventType.consume.name,
        'amount_cents': draft.amount.cents,
        ..._nullableScopeValues(draft.scope),
        'cash_bill_id': null,
        'balance_after_cents': 0,
        'note': draft.note.trim(),
        'created_at_utc': now,
        'updated_at_utc': now,
      });
      await _recalculateCourier(txn, draft.courierAccountId);
      await SqliteAggregateGuard.ensureAllActiveTotalsWithinCap(txn);
      await _audit(
        txn,
        'courier_event',
        id,
        'create',
        '',
        await _row(txn, 'courier_events', id),
      );
    });
  }

  @override
  Future<void> voidCourierEvent({
    required int eventId,
    required String reason,
  }) async => _setCourierEventVoid(eventId, true, reason);

  @override
  Future<void> restoreCourierEvent({
    required int eventId,
    required String reason,
  }) async => _setCourierEventVoid(eventId, false, reason);

  @override
  Future<List<CourierAccount>> listCourierAccounts({
    bool includeInactive = false,
  }) async {
    final rows = await _db.query(
      'courier_accounts',
      where: includeInactive ? null : 'is_active = 1',
      orderBy: 'id ASC',
    );
    return Future.wait(rows.map((row) => _courierAccountFromRow(_db, row)));
  }

  @override
  Future<CourierAccountDetail> getCourierAccountDetail(
    int courierAccountId,
  ) async {
    final account = await _row(_db, 'courier_accounts', courierAccountId);
    final events = await _courierEvents(_db, courierAccountId);
    return CourierAccountDetail(
      account: await _courierAccountFromRow(_db, account),
      events: events,
    );
  }

  Future<void> _setPurchaseAdjustmentVoid(
    int adjustmentId,
    bool isVoid,
    String reason,
  ) async {
    final why = _validatedReason(reason);
    await _db.transaction((txn) async {
      final adjustment = await _row(txn, 'purchase_adjustments', adjustmentId);
      if (sqliteBool(adjustment['is_void']) == isVoid) return;
      if (!isVoid) {
        await _activePurchase(txn, adjustment['purchase_id']! as int);
      }
      final now = utcNowIso();
      await txn.update(
        'purchase_adjustments',
        {
          'is_void': sqliteBoolValue(isVoid),
          'voided_at_utc': isVoid ? now : null,
          'updated_at_utc': now,
        },
        where: 'id = ?',
        whereArgs: [adjustmentId],
      );
      final cashId = adjustment['cash_bill_id'] as int?;
      if (cashId != null) await _setCashVoid(txn, cashId, isVoid, now);
      await _refreshPurchasePosition(txn, adjustment['purchase_id']! as int);
      await SqliteAggregateGuard.ensureAllActiveTotalsWithinCap(txn);
      await _audit(
        txn,
        'purchase_adjustment',
        adjustmentId,
        isVoid ? 'void' : 'restore',
        why,
        await _row(txn, 'purchase_adjustments', adjustmentId),
      );
    });
  }

  Future<void> _setOpeningDebtPaymentVoid(
    int paymentId,
    bool isVoid,
    String reason,
  ) async {
    final why = _validatedReason(reason);
    await _db.transaction((txn) async {
      final payment = await _row(
        txn,
        'supplier_opening_debt_payments',
        paymentId,
      );
      if (sqliteBool(payment['is_void']) == isVoid) return;
      final now = utcNowIso();
      await txn.update(
        'supplier_opening_debt_payments',
        {
          'is_void': sqliteBoolValue(isVoid),
          'voided_at_utc': isVoid ? now : null,
          'updated_at_utc': now,
        },
        where: 'id = ?',
        whereArgs: [paymentId],
      );
      await _setCashVoid(txn, payment['cash_bill_id']! as int, isVoid, now);
      await _refreshOpeningDebtPaid(txn, payment['opening_debt_id']! as int);
      await SqliteAggregateGuard.ensureAllActiveTotalsWithinCap(txn);
      await _audit(
        txn,
        'supplier_opening_debt_payment',
        paymentId,
        isVoid ? 'void' : 'restore',
        why,
        await _row(txn, 'supplier_opening_debt_payments', paymentId),
      );
    });
  }

  Future<void> _setProblemResaleVoid(
    int resaleId,
    bool isVoid,
    String reason,
  ) async {
    final why = _validatedReason(reason);
    await _db.transaction((txn) async {
      final resale = await _row(txn, 'problem_resales', resaleId);
      if (sqliteBool(resale['is_void']) == isVoid) return;
      final now = utcNowIso();
      await txn.update(
        'problem_resales',
        {
          'is_void': sqliteBoolValue(isVoid),
          'voided_at_utc': isVoid ? now : null,
          'updated_at_utc': now,
        },
        where: 'id = ?',
        whereArgs: [resaleId],
      );
      await _setCashVoid(
        txn,
        resale['income_cash_bill_id']! as int,
        isVoid,
        now,
      );
      final fees = await txn.query(
        'problem_resale_fees',
        where: 'resale_id = ?',
        whereArgs: [resaleId],
      );
      for (final fee in fees) {
        await _setCashVoid(txn, fee['cash_bill_id']! as int, isVoid, now);
      }
      await SqliteAggregateGuard.ensureAllActiveTotalsWithinCap(txn);
      await _audit(
        txn,
        'problem_resale',
        resaleId,
        isVoid ? 'void' : 'restore',
        why,
        await _row(txn, 'problem_resales', resaleId),
      );
    });
  }

  Future<void> _recordCourierCashEvent(
    CourierCashEventDraft draft,
    CourierEventType type,
  ) async {
    _validatePositive(draft.amount);
    await _db.transaction((txn) async {
      await _requireActiveId(txn, 'courier_accounts', draft.courierAccountId);
      await _validateScope(txn, draft.scope);
      final direction =
          type == CourierEventType.topUp
              ? CashDirection.expense
              : CashDirection.income;
      await _requireCategory(txn, draft.categoryId, direction);
      await _requireActiveId(txn, 'account_labels', draft.accountId);
      final cashId = await _insertLinkedCashBill(
        txn,
        businessDate: draft.businessDate,
        direction: direction,
        amount: draft.amount,
        scope: draft.scope,
        categoryId: draft.categoryId,
        accountId: draft.accountId,
        partyId: null,
        note: draft.note.trim(),
        origin:
            type == CourierEventType.topUp
                ? BusinessOrigin.courierTopUp
                : BusinessOrigin.courierRefund,
        linkedType:
            type == CourierEventType.topUp
                ? LinkedBillType.courierTopUp
                : LinkedBillType.courierRefund,
        linkedId: draft.courierAccountId,
      );
      final now = utcNowIso();
      final id = await txn.insert('courier_events', {
        'courier_account_id': draft.courierAccountId,
        'business_date': draft.businessDate.value,
        'event_type': type.name,
        'amount_cents': draft.amount.cents,
        ..._nullableScopeValues(draft.scope),
        'cash_bill_id': cashId,
        'balance_after_cents': 0,
        'note': draft.note.trim(),
        'created_at_utc': now,
        'updated_at_utc': now,
      });
      await _recalculateCourier(txn, draft.courierAccountId);
      await SqliteAggregateGuard.ensureAllActiveTotalsWithinCap(txn);
      await _audit(
        txn,
        'courier_event',
        id,
        'create',
        '',
        await _row(txn, 'courier_events', id),
      );
    });
  }

  Future<void> _setCourierEventVoid(
    int eventId,
    bool isVoid,
    String reason,
  ) async {
    final why = _validatedReason(reason);
    await _db.transaction((txn) async {
      final event = await _row(txn, 'courier_events', eventId);
      if (event['event_type'] == CourierEventType.opening.name && isVoid) {
        throw StateError('期初余额不能作废');
      }
      if (sqliteBool(event['is_void']) == isVoid) return;
      final now = utcNowIso();
      await txn.update(
        'courier_events',
        {
          'is_void': sqliteBoolValue(isVoid),
          'voided_at_utc': isVoid ? now : null,
          'updated_at_utc': now,
        },
        where: 'id = ?',
        whereArgs: [eventId],
      );
      final cashId = event['cash_bill_id'] as int?;
      if (cashId != null) await _setCashVoid(txn, cashId, isVoid, now);
      await _recalculateCourier(txn, event['courier_account_id']! as int);
      await SqliteAggregateGuard.ensureAllActiveTotalsWithinCap(txn);
      await _audit(
        txn,
        'courier_event',
        eventId,
        isVoid ? 'void' : 'restore',
        why,
        await _row(txn, 'courier_events', eventId),
      );
    });
  }

  Future<int> _insertPurchasePayment(
    Transaction txn,
    int purchaseId,
    PurchasePaymentDraft payment,
  ) async {
    final purchase = await _row(txn, 'purchases', purchaseId);
    final cashId = await _insertLinkedCashBill(
      txn,
      businessDate: payment.businessDate,
      direction: CashDirection.expense,
      amount: payment.amount,
      scope: businessScopeFromSql(purchase),
      categoryId: payment.categoryId,
      accountId: payment.accountId,
      partyId: purchase['supplier_id']! as int,
      note: payment.note.trim(),
      origin: BusinessOrigin.purchasePayment,
      linkedType: LinkedBillType.purchasePayment,
      linkedId: purchaseId,
    );
    final now = utcNowIso();
    final paymentId = await txn.insert('purchase_payments', {
      'purchase_id': purchaseId,
      'cash_bill_id': cashId,
      'amount_cents': payment.amount.cents,
      'created_at_utc': now,
      'updated_at_utc': now,
    });
    await _audit(
      txn,
      'purchase_payment',
      paymentId,
      'create',
      '',
      await _row(txn, 'purchase_payments', paymentId),
    );
    return paymentId;
  }

  Future<void> _refreshPurchasePosition(Transaction txn, int purchaseId) async {
    final purchase = await _row(txn, 'purchases', purchaseId);
    final position = await _purchasePosition(txn, purchase);
    final now = utcNowIso();
    await txn.update(
      'purchases',
      {
        'effective_total_cents': position.effectiveTotal.cents,
        'updated_at_utc': now,
      },
      where: 'id = ?',
      whereArgs: [purchaseId],
    );
  }

  Future<void> _refreshOpeningDebtPaid(Transaction txn, int debtId) async {
    final debt = await _row(txn, 'supplier_opening_debts', debtId);
    final rows = await txn.query(
      'supplier_opening_debt_payments',
      columns: ['amount_cents'],
      where: 'opening_debt_id = ? AND is_void = 0',
      whereArgs: [debtId],
    );
    final paid = Money.sumCents(rows.map((row) => row['amount_cents']! as int));
    if (paid.cents > (debt['amount_cents']! as int)) {
      throw StateError('期初欠款付款超额');
    }
    await txn.update(
      'supplier_opening_debts',
      {'paid_cents': paid.cents, 'updated_at_utc': utcNowIso()},
      where: 'id = ?',
      whereArgs: [debtId],
    );
  }

  Future<void> _recalculateCourier(
    Transaction txn,
    int courierAccountId,
  ) async {
    final events = await _courierEvents(txn, courierAccountId);
    final recalculated = LedgerCalculations.recalculateCourierTimeline(events);
    for (final event in recalculated) {
      await txn.update(
        'courier_events',
        {'balance_after_cents': event.balanceAfter.cents},
        where: 'id = ?',
        whereArgs: [event.id],
      );
    }
  }

  Future<Map<String, Object?>> _activePurchase(
    DatabaseExecutor db,
    int id,
  ) async {
    final row = await _row(db, 'purchases', id);
    if (sqliteBool(row['is_void'])) throw StateError('采购已作废');
    return row;
  }

  Future<Map<String, Object?>> _activeDebt(DatabaseExecutor db, int id) async {
    final row = await _row(db, 'supplier_opening_debts', id);
    if (sqliteBool(row['is_void'])) throw StateError('期初欠款已作废');
    return row;
  }
}

Future<int> _insertLinkedCashBill(
  DatabaseExecutor db, {
  required LocalDate businessDate,
  required CashDirection direction,
  required Money amount,
  required BusinessScope scope,
  required int categoryId,
  required int accountId,
  required int? partyId,
  required String note,
  required BusinessOrigin origin,
  required LinkedBillType linkedType,
  required int linkedId,
}) async {
  _validatePositive(amount);
  await _requireCategory(db, categoryId, direction);
  await _requireActiveId(db, 'account_labels', accountId);
  if (partyId != null) await _requireActiveId(db, 'parties', partyId);
  await _validateScope(db, scope);
  final now = utcNowIso();
  final id = await db.insert('cash_bills', {
    'business_date': businessDate.value,
    'direction': direction.name,
    'amount_cents': amount.cents,
    ..._scopeValues(scope),
    'category_id': categoryId,
    'account_id': accountId,
    'party_id': partyId,
    'note': note,
    'entry_source': EntrySource.manual.name,
    'business_origin': origin.name,
    'linked_type': linkedType.name,
    'linked_id': linkedId,
    'created_at_utc': now,
    'updated_at_utc': now,
  });
  await _audit(
    db,
    'cash_bill',
    id,
    'create',
    '',
    await _row(db, 'cash_bills', id),
  );
  return id;
}

Future<void> _setCashVoid(
  DatabaseExecutor db,
  int cashId,
  bool isVoid,
  String now,
) async {
  await db.update(
    'cash_bills',
    {
      'is_void': sqliteBoolValue(isVoid),
      'voided_at_utc': isVoid ? now : null,
      'updated_at_utc': now,
    },
    where: 'id = ?',
    whereArgs: [cashId],
  );
  await _audit(
    db,
    'cash_bill',
    cashId,
    isVoid ? 'void' : 'restore',
    '',
    await _row(db, 'cash_bills', cashId),
  );
}

Future<PurchasePosition> _purchasePosition(
  DatabaseExecutor db,
  Map<String, Object?> purchase,
) async {
  final purchaseId = purchase['id']! as int;
  final payments = await db.query(
    'purchase_payments',
    columns: ['amount_cents'],
    where: 'purchase_id = ? AND is_void = 0',
    whereArgs: [purchaseId],
  );
  final adjustments = await db.query(
    'purchase_adjustments',
    columns: ['kind', 'amount_cents'],
    where: 'purchase_id = ? AND is_void = 0',
    whereArgs: [purchaseId],
  );
  return LedgerCalculations.purchasePosition(
    originalTotal: Money.fromCents(purchase['original_total_cents']! as int),
    unpaidWaivers: adjustments
        .where((row) => row['kind'] == PurchaseAdjustmentKind.unpaidWaiver.name)
        .map((row) => Money.fromCents(row['amount_cents']! as int)),
    paidRefunds: adjustments
        .where((row) => row['kind'] == PurchaseAdjustmentKind.paidRefund.name)
        .map((row) => Money.fromCents(row['amount_cents']! as int)),
    activePayments: payments.map(
      (row) => Money.fromCents(row['amount_cents']! as int),
    ),
  );
}

Future<Purchase> _purchaseFromRow(
  DatabaseExecutor db,
  Map<String, Object?> row,
) async => Purchase(
  id: row['id']! as int,
  supplierId: row['supplier_id']! as int,
  scope: businessScopeFromSql(row),
  businessDate: LocalDate.parse(row['business_date']! as String),
  originalTotal: Money.fromCents(row['original_total_cents']! as int),
  supplierFreight: Money.fromCents(row['supplier_freight_cents']! as int),
  note: row['note']! as String,
  isVoid: sqliteBool(row['is_void']),
  position: await _purchasePosition(db, row),
);

PurchaseItem _purchaseItemFromRow(Map<String, Object?> row) => PurchaseItem(
  id: row['id']! as int,
  description: row['description']! as String,
  quantity: row['quantity']! as int,
  unitPrice: Money.fromCents(row['unit_price_cents']! as int),
  lineTotal: Money.fromCents(row['line_total_cents']! as int),
);

PurchasePayment _purchasePaymentFromRow(Map<String, Object?> row) =>
    PurchasePayment(
      id: row['id']! as int,
      purchaseId: row['purchase_id']! as int,
      cashBillId: row['cash_bill_id']! as int,
      amount: Money.fromCents(row['amount_cents']! as int),
      isVoid: sqliteBool(row['is_void']),
    );

PurchaseAdjustment _purchaseAdjustmentFromRow(Map<String, Object?> row) =>
    PurchaseAdjustment(
      id: row['id']! as int,
      purchaseId: row['purchase_id']! as int,
      kind: PurchaseAdjustmentKind.values.byName(row['kind']! as String),
      amount: Money.fromCents(row['amount_cents']! as int),
      cashBillId: row['cash_bill_id'] as int?,
      reason: row['reason']! as String,
      isVoid: sqliteBool(row['is_void']),
    );

SupplierOpeningDebt _debtFromRow(Map<String, Object?> row) =>
    SupplierOpeningDebt(
      id: row['id']! as int,
      supplierId: row['supplier_id']! as int,
      scope: businessScopeFromSql(row),
      businessDate: LocalDate.parse(row['business_date']! as String),
      amount: Money.fromCents(row['amount_cents']! as int),
      paid: Money.fromCents(row['paid_cents']! as int),
      isVoid: sqliteBool(row['is_void']),
      note: row['note']! as String,
    );

SupplierOpeningDebtPayment _debtPaymentFromRow(Map<String, Object?> row) =>
    SupplierOpeningDebtPayment(
      id: row['id']! as int,
      openingDebtId: row['opening_debt_id']! as int,
      cashBillId: row['cash_bill_id']! as int,
      amount: Money.fromCents(row['amount_cents']! as int),
      isVoid: sqliteBool(row['is_void']),
    );

ProblemResale _resaleFromRow(Map<String, Object?> row) => ProblemResale(
  id: row['id']! as int,
  scope: businessScopeFromSql(row),
  businessDate: LocalDate.parse(row['business_date']! as String),
  description: row['description']! as String,
  quantity: row['quantity']! as int,
  incomeAmount: Money.fromCents(row['income_cents']! as int),
  incomeCashBillId: row['income_cash_bill_id']! as int,
  buyerId: row['buyer_id']! as int,
  channelId: row['channel_id']! as int,
  issueNote: row['issue_note']! as String,
  isVoid: sqliteBool(row['is_void']),
);

ProblemResaleFee _resaleFeeFromRow(Map<String, Object?> row) =>
    ProblemResaleFee(
      id: row['id']! as int,
      cashBillId: row['cash_bill_id']! as int,
      categoryId: row['category_id']! as int,
      accountId: row['account_id']! as int,
      amount: Money.fromCents(row['amount_cents']! as int),
    );

Future<CourierAccount> _courierAccountFromRow(
  DatabaseExecutor db,
  Map<String, Object?> row,
) async {
  final events = await _courierEvents(db, row['id']! as int);
  final balance = events.isEmpty ? Money.zero : events.last.balanceAfter;
  return CourierAccount(
    id: row['id']! as int,
    name: row['name']! as String,
    isActive: sqliteBool(row['is_active']),
    recordedBalance: balance,
  );
}

Future<List<CourierEvent>> _courierEvents(
  DatabaseExecutor db,
  int courierAccountId,
) async {
  final rows = await db.query(
    'courier_events',
    where: 'courier_account_id = ?',
    whereArgs: [courierAccountId],
    orderBy: 'business_date ASC, id ASC',
  );
  return rows.map(_courierEventFromRow).toList();
}

CourierEvent _courierEventFromRow(Map<String, Object?> row) => CourierEvent(
  id: row['id']! as int,
  courierAccountId: row['courier_account_id']! as int,
  scope: row['scope_type'] == null ? null : businessScopeFromSql(row),
  businessDate: LocalDate.parse(row['business_date']! as String),
  eventType: CourierEventType.values.byName(row['event_type']! as String),
  amount: Money.fromCents(row['amount_cents']! as int),
  cashBillId: row['cash_bill_id'] as int?,
  balanceAfter: Money.fromCents(row['balance_after_cents']! as int),
  note: row['note']! as String,
  isVoid: sqliteBool(row['is_void']),
);

(String?, List<Object?>) _purchaseWhere(PurchaseFilter filter) {
  final where = <String>[];
  final args = <Object?>[];
  if (!filter.includeVoid) where.add('is_void = 0');
  if (filter.supplierId != null) {
    where.add('supplier_id = ?');
    args.add(filter.supplierId);
  }
  _addScopeWhere(where, args, filter.scope);
  return (where.isEmpty ? null : where.join(' AND '), args);
}

Map<String, Object?> _scopeValues(BusinessScope scope) => {
  'scope_type': scope.type.name,
  'shop_id': scope.shopId,
};

Map<String, Object?> _nullableScopeValues(BusinessScope scope) => {
  'scope_type': scope.type.name,
  'shop_id': scope.shopId,
};

void _addScopeWhere(
  List<String> where,
  List<Object?> args,
  BusinessScope? scope,
) {
  if (scope == null) return;
  where.add('scope_type = ?');
  args.add(scope.type.name);
  if (scope.shopId == null) {
    where.add('shop_id IS NULL');
  } else {
    where.add('shop_id = ?');
    args.add(scope.shopId);
  }
}

Future<Map<String, Object?>> _row(
  DatabaseExecutor db,
  String table,
  int id,
) async {
  final rows = await db.query(
    table,
    where: 'id = ?',
    whereArgs: [id],
    limit: 1,
  );
  if (rows.isEmpty) throw StateError('资料不存在');
  return rows.single;
}

Future<void> _requireParty(DatabaseExecutor db, int id, PartyKind kind) async {
  final row = await _row(db, 'parties', id);
  if (row['kind'] != kind.name) throw StateError('往来单位类型不匹配');
  if (!sqliteBool(row['is_active'])) throw StateError('资料已停用');
}

Future<void> _requireCategory(
  DatabaseExecutor db,
  int id,
  CashDirection direction,
) async {
  final row = await _row(db, 'categories', id);
  if (row['direction'] != direction.name) throw StateError('收支方向不匹配');
  if (!sqliteBool(row['is_active'])) throw StateError('资料已停用');
}

Future<void> _requireActiveId(DatabaseExecutor db, String table, int id) async {
  final row = await _row(db, table, id);
  if (!sqliteBool(row['is_active'])) throw StateError('资料已停用');
}

Future<void> _validateScope(DatabaseExecutor db, BusinessScope scope) async {
  if (scope.shopId != null) await _requireActiveId(db, 'shops', scope.shopId!);
}

Future<void> _validatePaymentCashRefs(
  DatabaseExecutor db,
  PurchasePaymentDraft draft,
  CashDirection direction,
) async {
  await _requireCategory(db, draft.categoryId, direction);
  await _requireActiveId(db, 'account_labels', draft.accountId);
}

void _validatePurchaseDraft(PurchaseDraft draft) {
  if (draft.items.isEmpty) throw const FormatException('采购明细不能为空');
  _validateNonNegative(draft.supplierFreight);
  for (final item in draft.items) {
    if (item.description.trim().isEmpty) throw const FormatException('明细不能为空');
    if (item.quantity <= 0) throw const FormatException('数量必须大于零');
    _validatePositive(item.unitPrice);
    Money.checkedProduct(quantity: item.quantity, unitPrice: item.unitPrice);
  }
}

void _validateProblemResaleDraft(ProblemResaleDraft draft) {
  if (draft.description.trim().isEmpty) throw const FormatException('说明不能为空');
  if (draft.quantity <= 0) throw const FormatException('数量必须大于零');
  _validatePositive(draft.incomeAmount);
  for (final fee in draft.fees) {
    _validatePositive(fee.amount);
  }
}

void _validatePositive(Money amount) {
  if (amount.cents <= 0 || amount.cents > Money.maxCents) {
    throw const FormatException('金额超出允许范围');
  }
}

void _validateNonNegative(Money amount) {
  if (amount.cents < 0 || amount.cents > Money.maxCents) {
    throw const FormatException('金额超出允许范围');
  }
}

String _validatedReason(String reason) {
  final trimmed = reason.trim();
  if (trimmed.isEmpty) throw const FormatException('原因不能为空');
  return trimmed;
}

String _validatedName(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) throw const FormatException('名称不能为空');
  return trimmed;
}

Future<void> _audit(
  DatabaseExecutor db,
  String entityType,
  int entityId,
  String action,
  String reason,
  Map<String, Object?> snapshot,
) {
  return db.insert('audit_logs', {
    'entity_type': entityType,
    'entity_id': entityId,
    'action': action,
    'reason': reason,
    'snapshot_json': jsonEncode(snapshot),
    'created_at_utc': utcNowIso(),
  });
}
