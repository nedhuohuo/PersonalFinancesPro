import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finances_pro/core/domain/money.dart';

void main() {
  test('checks quantity times unit price before converting to int cents', () {
    expect(
      Money.checkedProduct(quantity: 3, unitPrice: Money.fromCents(199)).cents,
      597,
    );
    expect(
      () => Money.checkedProduct(
        quantity: 1000000000,
        unitPrice: Money.fromCents(9000000000000000),
      ),
      throwsFormatException,
    );
  });

  test('sums money in Dart without SQL integer overflow', () {
    expect(Money.sumCents([1, 2, -3]).cents, 0);
    expect(() => Money.sumCents([9000000000000000, 1]), throwsFormatException);
  });
}
