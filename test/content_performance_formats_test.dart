import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:life_pilot/event/content_performance_formats.dart';

void main() {
  setUpAll(() => initializeDateFormatting());

  for (final locale in ['zh', 'en', 'ja', 'ko']) {
    test('$locale: shared formats retain date and number output', () {
      final formats = ContentPerformanceFormats.forLocale(locale);
      final date = DateFormat.yMd(locale);
      final count = NumberFormat.decimalPattern(locale);
      for (final value in [DateTime(2026, 10, 21), DateTime(2027, 1, 2)]) {
        expect(formats.date(value), date.format(value));
      }
      for (final value in [0, 1, 1234, 123456789, -1234, 23.4567]) {
        expect(formats.count(value), count.format(value));
      }
      expect(ContentPerformanceFormats.forLocale(locale), same(formats));
    });
  }

  test('locale switching never mutates previously obtained formats', () {
    final english = ContentPerformanceFormats.forLocale('en');
    final japanese = ContentPerformanceFormats.forLocale('ja');
    final date = DateTime(2027, 1, 2);
    expect(english.date(date), DateFormat.yMd('en').format(date));
    expect(japanese.date(date), DateFormat.yMd('ja').format(date));
    final englishAgain = ContentPerformanceFormats.forLocale('en');
    expect(englishAgain.locale, 'en');
    expect(englishAgain.date(date), english.date(date));
    expect(englishAgain.count(1234), english.count(1234));
    expect(ContentPerformanceFormats.forLocale('en'), same(englishAgain));
  });

  test('formatter settings outside the helper cannot modify its output', () {
    final formats = ContentPerformanceFormats.forLocale('en');
    final independent = NumberFormat.decimalPattern('en')..turnOffGrouping();
    expect(independent.format(1234), '1234');
    expect(formats.count(1234), '1,234');
    expect(formats.count(5678), '5,678');
  });
}
