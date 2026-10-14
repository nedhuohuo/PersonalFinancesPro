final class LocalDate implements Comparable<LocalDate> {
  const LocalDate._(this.value);

  final String value;

  factory LocalDate.parse(String input) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(input);
    if (match == null) {
      throw const FormatException('Expected YYYY-MM-DD');
    }

    final year = int.parse(match[1]!);
    final month = int.parse(match[2]!);
    final day = int.parse(match[3]!);
    final parsed = DateTime.utc(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      throw const FormatException('Invalid calendar date');
    }
    return LocalDate._(input);
  }

  factory LocalDate.todayLocal(DateTime now) {
    final local = now.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return LocalDate._('$year-$month-$day');
  }

  @override
  int compareTo(LocalDate other) => value.compareTo(other.value);
}
