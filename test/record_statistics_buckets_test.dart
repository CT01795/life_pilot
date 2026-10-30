import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/record_statistics/model_record_statistics.dart';
import 'package:life_pilot/record_statistics/model_record_statistics_buckets.dart';

void main() {
  for (final now in [
    DateTime(2026, 10, 1),
    DateTime(2026, 10, 15),
    DateTime(2026, 10, 31),
  ]) {
    test(
      'compact projection preserves opening, daily, monthly, future and decimals on $now',
      () {
        final first = DateTime(now.year, now.month - 11);
        final rows = <Map<String, dynamic>>[
          {
            'date': DateTime(first.year - 1).toIso8601String(),
            'value': 100.1234,
          },
          {
            'date': DateTime(now.year, now.month, now.day).toIso8601String(),
            'value': -3.25,
          },
          {
            'date': DateTime(
              now.year,
              now.month,
              now.day == 1 ? 2 : 1,
            ).toIso8601String(),
            'value': 8.5,
          },
          {
            'date': DateTime(now.year, now.month + 2).toIso8601String(),
            'value': 19.4321,
          },
        ];
        final original = ModelRecordStatistics.fromRows(rows, now: now);
        final compactRows = ModelRecordStatisticsBuckets.toRows({
          'opening': 100.1234,
          'today': -3.25,
          'future': 19.4321,
          'months': [...List.filled(11, 0), 5.25],
          'has_history': true,
        }, now);
        final compact = ModelRecordStatistics.fromRows(compactRows, now: now);
        expect(compactRows.length, lessThanOrEqualTo(15));
        expect(compact.total, closeTo(original.total, 0.0000001));
        expect(compact.today, original.today);
        expect(compact.month, original.month);
        expect(
          compact.months.map((m) => m.net),
          original.months.map((m) => m.net),
        );
        for (var i = 0; i < 12; i++) {
          expect(
            compact.months[i].cumulative,
            closeTo(original.months[i].cumulative, 0.0000001),
          );
        }
      },
    );
  }
  for (final hasHistory in [false, true]) {
    test('zero-net history preserves empty-chart semantics: $hasHistory', () {
      final now = DateTime(2026, 10, 1);
      final result = ModelRecordStatistics.fromRows(
        ModelRecordStatisticsBuckets.toRows({
          'months': List.filled(12, 0),
          'opening': 0,
          'today': 0,
          'future': 0,
          'has_history': hasHistory,
        }, now),
        now: now,
      );
      expect(result.hasChartData, hasHistory);
    });
  }
  test(
    'future-only records remain absent from the chart but included in total',
    () {
      final now = DateTime(2026, 10, 1);
      final result = ModelRecordStatistics.fromRows(
        ModelRecordStatisticsBuckets.toRows({
          'months': List.filled(12, 0),
          'opening': 0,
          'today': 0,
          'future': 100,
          'has_history': false,
        }, now),
        now: now,
      );
      expect(result.total, 100);
      expect(result.hasChartData, false);
    },
  );
}
