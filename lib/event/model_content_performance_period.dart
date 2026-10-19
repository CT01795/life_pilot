import 'package:life_pilot/utils/value_parser.dart';

/// Null month means content that has not expired, including today.
/// Selecting this month also means all not-yet-expired content.
/// Other months match expiration dates in that calendar month only.
class ContentPerformancePeriod {
  final DateTime? month;
  final DateTime today;
  ContentPerformancePeriod({DateTime? month, required DateTime now})
    : month =
          month == null || (month.year == now.year && month.month == now.month)
          ? null
          : DateTime(month.year, month.month),
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

  /// Applied at the database, before pagination; no download-all client filtering.
  String get databaseFilter {
    final start = month;
    if (start == null) {
      final day = today.toUtc().toIso8601String();
      return 'end_date.gte.$day,and(end_date.is.null,start_date.gte.$day),'
          'and(end_date.is.null,start_date.is.null)';
    }
    final lower = start.toUtc().toIso8601String();
    final upper = DateTime(
      start.year,
      start.month + 1,
    ).toUtc().toIso8601String();
    return 'and(end_date.gte.$lower,end_date.lt.$upper),'
        'and(end_date.is.null,start_date.gte.$lower,start_date.lt.$upper)';
  }
}
