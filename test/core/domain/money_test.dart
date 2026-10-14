import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finances_pro/core/domain/money.dart';

void main() {
  test('parses decimal input without losing cents', () {
    expect(Money.parsePositive('18.00').cents, 1800);
    expect(Money.parsePositive('0.01').cents, 1);
    expect(Money.parsePositive('90000000000000.00').cents, 9000000000000000);
  });

  test('rejects excessive precision and out-of-range input', () {
    for (final input in ['', '-1', '0', '1e3', '18.005', '90000000000000.01']) {
      expect(() => Money.parsePositive(input), throwsFormatException);
    }
  });

  test('formats signed integer cents and guards aggregate overflow', () {
    expect(Money.fromCents(-296000).format(), '-2,960.00');
    expect(Money.fromCents(1).format(), '0.01');
    expect(
      () => Money.fromCents(9000000000000000).add(Money.fromCents(1)),
      throwsRangeError,
    );
  });

  test('formats zero and guards signed construction limits', () {
    expect(Money.zero.format(), '0.00');
    expect(Money.fromCents(-9000000000000000).cents, -9000000000000000);
    expect(() => Money.fromCents(-9000000000000001), throwsRangeError);
    expect(() => Money.fromCents(9000000000000001), throwsRangeError);
  });
}
