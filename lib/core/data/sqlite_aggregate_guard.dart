import 'package:personal_finances_pro/core/domain/money.dart';
import 'package:sqflite/sqflite.dart';

final class SqliteAggregateGuard {
  const SqliteAggregateGuard._();

  static Future<void> ensureCashBillTotalWithinCap(DatabaseExecutor db) async {
    final rows = await db.query(
      'cash_bills',
      columns: ['amount_cents'],
      where: 'is_void = 0',
    );
    final total = rows.fold<BigInt>(
      BigInt.zero,
      (sum, row) => sum + BigInt.from(row['amount_cents']! as int),
    );
    if (total > BigInt.from(Money.maxCents)) {
      throw const FormatException('金额超出允许范围');
    }
  }
}
