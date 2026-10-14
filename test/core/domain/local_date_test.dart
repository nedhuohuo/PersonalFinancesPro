import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finances_pro/core/domain/local_date.dart';

void main() {
  test('accepts real yyyy-mm-dd calendar dates only', () {
    expect(LocalDate.parse('2026-02-28').value, '2026-02-28');
    expect(LocalDate.parse('2024-02-29').value, '2024-02-29');
  });

  test('rejects rollover and non-padded dates', () {
    for (final input in [
      '2026-2-3',
      '2026-02-29',
      '2026-04-31',
      '2026-13-01',
      '20260203',
    ]) {
      expect(() => LocalDate.parse(input), throwsFormatException);
    }
  });
}
