import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/record_statistics/model_record_statistics.dart';
import 'package:life_pilot/record_statistics/record_statistics_formats.dart';
import 'package:life_pilot/record_statistics/record_statistics_presentation.dart';

class _CountingFormats implements RecordStatisticsFormats {
  @override
  final String locale;
  _CountingFormats(this.locale);
  int monthCalls = 0, axisCalls = 0, valueCalls = 0;
  @override
  String month(DateTime date) {
    monthCalls++;
    return '$locale:${date.year}/${date.month}';
  }

  @override
  String axisMonth(DateTime date, {required int currentYear}) {
    axisCalls++;
    return date.year == currentYear
        ? '${date.month}'
        : '${date.year}/${date.month}';
  }

  @override
  String value(num value) {
    valueCalls++;
    return '$locale:$value';
  }
}

void main() {
  ModelRecordStatistics data(num value) => ModelRecordStatistics.fromRows([
    {'date': DateTime(2025, 12, 1), 'value': 100},
    {'date': DateTime(2026, 1, 1), 'value': value},
  ], now: DateTime(2026, 1, 15));

  test(
    'format each row once and reuse its text without calling formatters',
    () {
      final series = data(-25.1234).series(cumulative: false);
      final formats = _CountingFormats('en');
      final display = RecordStatisticsPresentation(
        series: series,
        formats: formats,
        currentYear: 2026,
      );
      expect(display.rows.length, 12);
      for (var pass = 0; pass < 100; pass++) {
        for (var i = 0; i < display.rows.length; i++) {
          final row = display.rows[i];
          expect(row.month, series.months[i].month);
          expect(row.value, series.values[i]);
          expect(row.valueLabel, 'en:${series.values[i]}');
          expect(row.monthLabel, startsWith('en:'));
        }
        expect(
          display.matches(series: series, formats: formats, currentYear: 2026),
          isTrue,
        );
      }
      expect(formats.monthCalls, 12);
      expect(formats.axisCalls, 12);
      expect(formats.valueCalls, 12);
      expect(() => display.rows.clear(), throwsUnsupportedError);
    },
  );

  test('monthly and cumulative series require different presentations', () {
    final model = data(-25);
    final formats = _CountingFormats('en');
    final monthly = model.series(cumulative: false);
    final cumulative = model.series(cumulative: true);
    final display = RecordStatisticsPresentation(
      series: monthly,
      formats: formats,
      currentYear: 2026,
    );
    expect(display.rows.first.value, -25);
    expect(
      display.matches(series: cumulative, formats: formats, currentYear: 2026),
      isFalse,
    );
    expect(
      RecordStatisticsPresentation(
        series: cumulative,
        formats: formats,
        currentYear: 2026,
      ).rows.first.value,
      75,
    );
  });

  test('replacement data and formatter instances cannot reuse old text', () {
    final series = data(1).series(cumulative: false);
    final formats = _CountingFormats('en');
    final display = RecordStatisticsPresentation(
      series: series,
      formats: formats,
      currentYear: 2026,
    );
    expect(
      display.matches(
        series: data(2).series(cumulative: false),
        formats: formats,
        currentYear: 2026,
      ),
      isFalse,
    );
    expect(
      display.matches(
        series: series,
        formats: _CountingFormats('zh'),
        currentYear: 2026,
      ),
      isFalse,
    );
    expect(display.rows.first.valueLabel, 'en:1');
  });

  test('new calendar year refreshes year-qualified axis labels', () {
    final series = data(1).series(cumulative: false);
    final formats = _CountingFormats('en');
    final old = RecordStatisticsPresentation(
      series: series,
      formats: formats,
      currentYear: 2026,
    );
    expect(old.rows.first.axisLabel, '1');
    expect(old.rows[1].axisLabel, '2025/12');
    expect(
      old.matches(series: series, formats: formats, currentYear: 2027),
      isFalse,
    );
    expect(
      RecordStatisticsPresentation(
        series: series,
        formats: formats,
        currentYear: 2027,
      ).rows.first.axisLabel,
      '2026/1',
    );
  });
}
