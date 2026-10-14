import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finances_pro/core/domain/local_date.dart';
import 'package:personal_finances_pro/core/domain/money.dart';
import 'package:personal_finances_pro/features/ledger/domain/ledger_calculations.dart';
import 'package:personal_finances_pro/features/ledger/domain/ledger_models.dart';

void main() {
  test('purchase position preserves paid net invariant', () {
    final position = LedgerCalculations.purchasePosition(
      originalTotal: Money.fromCents(2300),
      unpaidWaivers: [Money.fromCents(500)],
      paidRefunds: [Money.fromCents(700)],
      activePayments: [Money.fromCents(1000)],
    );
    expect(position.effectiveTotal.cents, 1100);
    expect(position.paidNet.cents, 300);
    expect(
      () => LedgerCalculations.purchasePosition(
        originalTotal: Money.fromCents(2300),
        unpaidWaivers: [Money.fromCents(500)],
        paidRefunds: [Money.fromCents(700)],
        activePayments: [Money.fromCents(2000)],
      ),
      throwsStateError,
    );
  });

  test('aggregate cap rejects before a write can create unreadable totals', () {
    expect(
      () => LedgerCalculations.assertCappedAggregate([9000000000000000, 1]),
      throwsFormatException,
    );
  });

  test('courier timeline sorts events and rejects negative prefixes', () {
    final topUp = _courierEvent(
      id: 2,
      date: '2026-01-02',
      type: CourierEventType.topUp,
      amountCents: 500,
    );
    final opening = _courierEvent(
      id: 1,
      date: '2026-01-01',
      type: CourierEventType.opening,
      amountCents: 1000,
    );
    final consume = _courierEvent(
      id: 3,
      date: '2026-01-03',
      type: CourierEventType.consume,
      amountCents: 1200,
    );

    final timeline = LedgerCalculations.recalculateCourierTimeline([
      consume,
      topUp,
      opening,
    ]);

    expect(timeline.map((event) => event.id), [1, 2, 3]);
    expect(timeline.map((event) => event.balanceAfter.cents), [
      1000,
      1500,
      300,
    ]);
    expect(
      () => LedgerCalculations.recalculateCourierTimeline([consume, opening]),
      throwsStateError,
    );
  });
}

CourierEvent _courierEvent({
  required int id,
  required String date,
  required CourierEventType type,
  required int amountCents,
}) {
  return CourierEvent(
    id: id,
    courierAccountId: 1,
    scope: null,
    businessDate: LocalDate.parse(date),
    eventType: type,
    amount: Money.fromCents(amountCents),
    cashBillId: null,
    balanceAfter: Money.zero,
    note: '',
    isVoid: false,
  );
}
