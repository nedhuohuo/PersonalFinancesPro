import 'package:personal_finances_pro/core/domain/money.dart';
import 'package:sqflite/sqflite.dart';

final class SqliteAggregateGuard {
  const SqliteAggregateGuard._();

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
}
