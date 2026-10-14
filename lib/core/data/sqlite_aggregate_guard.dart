import 'package:personal_finances_pro/core/domain/money.dart';
import 'package:sqflite/sqflite.dart';

final class SqliteAggregateGuard {
  const SqliteAggregateGuard._();

  static Future<void> ensureAllActiveTotalsWithinCap(
    DatabaseExecutor db,
  ) async {
    await ensureCashBillTotalWithinCap(db);
    await ensureCurrentLiabilitiesWithinCap(db);
    await ensureCourierWalletTotalsWithinCap(db);
    final consumes = await db.query(
      'courier_events',
      columns: ['amount_cents'],
      where: 'is_void = 0 AND event_type = ?',
      whereArgs: ['consume'],
    );
    Money.sumCents(consumes.map((row) => row['amount_cents']! as int));
  }

  static Future<void> ensureCashBillTotalWithinCap(DatabaseExecutor db) async {
    final rows = await db.query(
      'cash_bills',
      columns: ['direction', 'amount_cents'],
      where: 'is_void = 0',
    );
    final byDirection = <String, List<int>>{};
    for (final row in rows) {
      (byDirection[row['direction']! as String] ??= []).add(
        row['amount_cents']! as int,
      );
    }
    // ponytail: O(n) aggregate scan, replace with materialized totals if ledger size makes writes slow.
    for (final cents in byDirection.values) {
      Money.sumCents(cents);
    }
  }

  static Future<void> ensureCurrentLiabilitiesWithinCap(
    DatabaseExecutor db,
  ) async {
    final cents = <int>[];
    final purchases = await db.query(
      'purchases',
      columns: ['id', 'original_total_cents', 'effective_total_cents'],
      where: 'is_void = 0',
    );
    Money.sumCents(
      purchases.map((row) => row['effective_total_cents']! as int),
    );
    for (final purchase in purchases) {
      final payments = await db.query(
        'purchase_payments',
        columns: ['amount_cents'],
        where: 'purchase_id = ? AND is_void = 0',
        whereArgs: [purchase['id']],
      );
      final paymentTotal = Money.sumCents(
        payments.map((row) => row['amount_cents']! as int),
      );
      final refunds = await db.query(
        'purchase_adjustments',
        columns: ['amount_cents'],
        where: 'purchase_id = ? AND kind = ? AND is_void = 0',
        whereArgs: [purchase['id'], 'paidRefund'],
      );
      final refundTotal = Money.sumCents(
        refunds.map((row) => row['amount_cents']! as int),
      );
      cents.add(
        (purchase['effective_total_cents']! as int) -
            paymentTotal.cents +
            refundTotal.cents,
      );
    }
    final debts = await db.query(
      'supplier_opening_debts',
      columns: ['amount_cents', 'paid_cents'],
      where: 'is_void = 0',
    );
    for (final debt in debts) {
      cents.add((debt['amount_cents']! as int) - (debt['paid_cents']! as int));
    }
    Money.sumCents(cents);
  }

  static Future<void> ensureCourierWalletTotalsWithinCap(
    DatabaseExecutor db,
  ) async {
    final rows = await db.rawQuery('''
SELECT e.balance_after_cents
FROM courier_events e
JOIN (
  SELECT courier_account_id, MAX(business_date || '#' || printf('%020d', id)) AS last_key
  FROM courier_events
  GROUP BY courier_account_id
) last ON last.courier_account_id = e.courier_account_id
  AND last.last_key = e.business_date || '#' || printf('%020d', e.id)
''');
    Money.sumCents(rows.map((row) => row['balance_after_cents']! as int));
  }
}
