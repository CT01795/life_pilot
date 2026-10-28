import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:life_pilot/stock/stock_display_formats.dart';

void main() {
  setUpAll(() => initializeDateFormatting());
  for (final locale in ['zh', 'en', 'ja', 'ko']) {
    test('$locale quantities preserve grouping, signs and rounding', () {
      final formats = StockDisplayFormats.forLocale(locale);
      final original = NumberFormat('#,##0', locale);
      for (final value in [
        0,
        1,
        -1,
        1234567,
        -1234567,
        1234.5,
        -1234.5,
        0.4999,
      ]) {
        expect(formats.quantity(value), original.format(value));
      }
    });
    test('$locale prices preserve exactly two fraction digits', () {
      final formats = StockDisplayFormats.forLocale(locale);
      final original = NumberFormat('#,##0.00', locale);
      for (final value in [0, 1, -1, 1234567, 23.45678, -23.45678]) {
        expect(formats.price(value), original.format(value));
      }
    });
    test('$locale dates always show the year without timezone conversion', () {
      final formats = StockDisplayFormats.forLocale(locale);
      final original = DateFormat('yyyy/MM/dd', locale);
      for (final date in [
        DateTime(2025, 12, 31, 23, 59),
        DateTime(2026, 1, 1),
        DateTime.utc(2027, 1, 1, 23, 59),
        DateTime(2028, 2, 29),
      ]) {
        expect(formats.date(date), original.format(date));
      }
    });
  }
  test('one locale reuses the same formatter owner for many cards', () {
    final formats = StockDisplayFormats.forLocale('en');
    for (var i = 0; i < 10000; i++) {
      expect(StockDisplayFormats.forLocale('en'), same(formats));
      formats.quantity(i);
      formats.price(i);
    }
  });
  test('locale switching does not mutate previously acquired formatters', () {
    final english = StockDisplayFormats.forLocale('en');
    final japanese = StockDisplayFormats.forLocale('ja');
    expect(english, isNot(same(japanese)));
    expect(
      english.price(1234.5),
      NumberFormat('#,##0.00', 'en').format(1234.5),
    );
    expect(
      japanese.price(1234.5),
      NumberFormat('#,##0.00', 'ja').format(1234.5),
    );
    expect(
      StockDisplayFormats.forLocale('en').quantity(-1234),
      english.quantity(-1234),
    );
  });
  test('missing quantities remain distinct from an actual zero', () {
    final formats = StockDisplayFormats.forLocale('en');
    expect(formats.quantity(null), '—');
    expect(formats.quantity(0), '0');
    expect(formats.quantity(500), '500');
  });
}
