final class Money {
  const Money._(this.cents);

  static const maxCents = 9000000000000000;
  static const zero = Money._(0);

  final int cents;

  factory Money.fromCents(int cents) {
    if (cents < -maxCents || cents > maxCents) {
      throw RangeError.range(cents, -maxCents, maxCents, 'cents');
    }
    return Money._(cents);
  }

  factory Money.parsePositive(String input) {
    final match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(input.trim());
    if (match == null) {
      throw const FormatException('金额最多两位小数');
    }

    final value =
        BigInt.parse(match[1]!) * BigInt.from(100) +
        BigInt.parse((match[2] ?? '').padRight(2, '0'));
    if (value <= BigInt.zero || value > BigInt.from(maxCents)) {
      throw const FormatException('金额超出允许范围');
    }
    return Money._(value.toInt());
  }

  Money add(Money other) => Money.fromCents(cents + other.cents);

  String format() {
    final digits = cents.abs().toString().padLeft(3, '0');
    final whole = digits
        .substring(0, digits.length - 2)
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
    return '${cents < 0 ? '-' : ''}$whole.${digits.substring(digits.length - 2)}';
  }
}
