import 'package:intl/intl.dart';

/// View formatting only. Retains one locale's private formatters, not account
/// data or formatted results; chart calculations remain locale-independent.
class RecordStatisticsFormats {
  RecordStatisticsFormats._(this.locale);
  final String locale;
  static RecordStatisticsFormats? _current;

  factory RecordStatisticsFormats.forLocale(String locale) {
    final current = _current;
    if (current != null && current.locale == locale) return current;
    return _current = RecordStatisticsFormats._(locale);
  }

  late final _number = NumberFormat('#,##0.####', locale);
  late final _month = DateFormat.MMM(locale);
  late final _yearMonth = DateFormat.yMMM(locale);

  String value(num value) => _number.format(value);
  String month(DateTime date) => _yearMonth.format(date);
  String axisMonth(DateTime date, {required int currentYear}) =>
      date.year == currentYear ? _month.format(date) : month(date);
}
