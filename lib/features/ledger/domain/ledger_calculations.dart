import 'package:personal_finances_pro/core/domain/money.dart';

import 'ledger_models.dart';

abstract final class LedgerCalculations {
  static PurchasePosition purchasePosition({
    required Money originalTotal,
    required Iterable<Money> unpaidWaivers,
    required Iterable<Money> paidRefunds,
    required Iterable<Money> activePayments,
  }) {
    final waivers = Money.sumCents(unpaidWaivers.map((money) => money.cents));
    final refunds = Money.sumCents(paidRefunds.map((money) => money.cents));
    final payments = Money.sumCents(activePayments.map((money) => money.cents));
    final effectiveTotal = Money.sumCents([
      originalTotal.cents,
      -waivers.cents,
      -refunds.cents,
    ]);
    final paidNet = Money.sumCents([payments.cents, -refunds.cents]);
    if (paidNet.cents < 0 || paidNet.cents > effectiveTotal.cents) {
      throw StateError('Purchase paid net must be within effective total');
    }
    return PurchasePosition(
      effectiveTotal: effectiveTotal,
      paidNet: paidNet,
      payable: Money.sumCents([effectiveTotal.cents, -paidNet.cents]),
    );
  }

  static List<CourierEvent> recalculateCourierTimeline(
    Iterable<CourierEvent> events,
  ) {
    final sorted =
        events.toList()..sort((a, b) {
          final byDate = a.businessDate.compareTo(b.businessDate);
          return byDate == 0 ? a.id.compareTo(b.id) : byDate;
        });

    var balance = Money.zero;
    return [
      for (final event in sorted)
        _withBalanceAfter(event, balance = _nextCourierBalance(balance, event)),
    ];
  }

  static void assertCappedAggregate(Iterable<int> activeCentsValues) {
    Money.sumCents(activeCentsValues);
  }

  static Money _nextCourierBalance(Money balance, CourierEvent event) {
    if (event.isVoid) {
      return balance;
    }
    final signedAmount = switch (event.eventType) {
      CourierEventType.opening || CourierEventType.topUp => event.amount.cents,
      CourierEventType.consume ||
      CourierEventType.refund => -event.amount.cents,
    };
    final next = Money.sumCents([balance.cents, signedAmount]);
    if (next.cents < 0) {
      throw StateError('Courier balance cannot become negative');
    }
    return next;
  }

  static CourierEvent _withBalanceAfter(
    CourierEvent event,
    Money balanceAfter,
  ) {
    return CourierEvent(
      id: event.id,
      courierAccountId: event.courierAccountId,
      scope: event.scope,
      businessDate: event.businessDate,
      eventType: event.eventType,
      amount: event.amount,
      cashBillId: event.cashBillId,
      balanceAfter: balanceAfter,
      note: event.note,
      isVoid: event.isVoid,
    );
  }
}
