import 'package:life_pilot/utils/value_parser.dart';

/// Null month means content that has not expired, including today.
/// Every explicit month matches expiration dates in that calendar month only.
class ContentPerformancePeriod {
  final DateTime? month;
  final DateTime today;
  ContentPerformancePeriod({DateTime? month, required DateTime now})
    : month = month == null ? null : DateTime(month.year, month.month),
      today = DateTime(now.year, now.month, now.day);

  static DateTime? expiration(Map<String, dynamic> row) =>
      tryParseDateTimeValue(row['end_date'], toLocal: true) ??
      tryParseDateTimeValue(row['start_date'], toLocal: true);

  bool matches(Map<String, dynamic> row) {
    final end = expiration(row);
    final start = month;
    if (start == null) return end == null || !end.isBefore(today);
    return end != null &&
        !end.isBefore(start) &&
        end.isBefore(DateTime(start.year, start.month + 1));
  }
}
