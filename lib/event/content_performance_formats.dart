import 'package:intl/intl.dart';

/// Locale-specific presentation only: no user data or formatted results cached.
/// Keep just the current locale, and do not expose mutable intl formatters.
class ContentPerformanceFormats {
  ContentPerformanceFormats._(this.locale);

  static ContentPerformanceFormats? _current;
  factory ContentPerformanceFormats.forLocale(String locale) {
    final current = _current;
    if (current != null && current.locale == locale) return current;
    return _current = ContentPerformanceFormats._(locale);
  }

  final String locale;
  late final DateFormat _date = DateFormat.yMd(locale);
  late final NumberFormat _count = NumberFormat.decimalPattern(locale);

  String date(DateTime value) => _date.format(value);
  String count(num value) => _count.format(value);
}
