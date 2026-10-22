import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:life_pilot/record_statistics/record_statistics_formats.dart';

void main() {
  setUpAll(() => initializeDateFormatting());
  for (final locale in ['zh', 'en', 'ja', 'ko']) {
    test('$locale: month labels match the existing year and locale rules', () {
      final formats = RecordStatisticsFormats.forLocale(locale);
      for (final date in [
        DateTime(2025, 12),
        DateTime(2026, 10),
        DateTime(2027, 1),
      ]) {
        expect(formats.month(date), DateFormat.yMMM(locale).format(date));
        expect(
          formats.axisMonth(date, currentYear: 2026),
          (date.year == 2026 ? DateFormat.MMM(locale) : DateFormat.yMMM(locale))
              .format(date),
        );
      }
      expect(RecordStatisticsFormats.forLocale(locale), same(formats));
    });
    test('$locale: signed values retain grouping and four decimal digits', () {
      final formats = RecordStatisticsFormats.forLocale(locale);
      final previous = NumberFormat('#,##0.####', locale);
      for (final value in [0, 1234, -1234, 1234.5678, -23.4567, 23.456789]) {
        expect(formats.value(value), previous.format(value));
      }
    });
  }
  test('locale switching does not mutate previously obtained formatters', () {
    final english = RecordStatisticsFormats.forLocale('en');
    final japanese = RecordStatisticsFormats.forLocale('ja');
    final date = DateTime(2026, 10);
    expect(english.month(date), DateFormat.yMMM('en').format(date));
    expect(japanese.month(date), DateFormat.yMMM('ja').format(date));
    final englishAgain = RecordStatisticsFormats.forLocale('en');
    expect(englishAgain.month(date), english.month(date));
    expect(englishAgain.value(1234.5678), english.value(1234.5678));
  });
  test('axis labels use the supplied current year rather than cached time', () {
    final formats = RecordStatisticsFormats.forLocale('en');
    final date = DateTime(2026, 12);
    expect(formats.axisMonth(date, currentYear: 2026), 'Dec');
    expect(formats.axisMonth(date, currentYear: 2027), 'Dec 2026');
  });
}
