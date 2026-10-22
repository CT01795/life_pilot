import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/event/model_content_performance.dart';
import 'package:life_pilot/utils/value_parser.dart';

void main() {
  test(
    'indexed aggregation matches named totals for randomized metric values',
    () {
      final random = Random(20261022);
      const values = <Object?>[null, 'invalid', '', 0, 1, -1, '12', '-5', 200];
      for (var batch = 0; batch < 100; batch++) {
        final rows = List<Map<String, dynamic>>.generate(
          100,
          (i) => {
            'id': '$i',
            'name': '$i',
            'city': 'City ${i % 3}',
            'start_date': '2026-10-01',
            'end_date': '2026-10-31',
            for (final metric in ContentPerformanceMetric.values)
              metric.column: values[random.nextInt(values.length)],
          },
        );
        for (final statisticsOnly in [false, true]) {
          final matching = rows
              .where(
                (row) =>
                    !statisticsOnly ||
                    ContentPerformanceMetric.values.any(
                      (metric) => parseIntValue(row[metric.column]) != 0,
                    ),
              )
              .toList();
          final expected = {
            for (final metric in ContentPerformanceMetric.values)
              metric.column: matching.fold<int>(
                0,
                (sum, row) => sum + parseIntValue(row[metric.column]),
              ),
          };
          for (final attractions in [false, true]) {
            final model = ModelContentPerformance(
              rows,
              statisticsOnly: statisticsOnly,
              sortByExpiry: true,
              attractions: attractions,
            );
            expect(model.totals, expected, reason: 'batch $batch');
            expect(model.items.length, matching.length);
            expect(model.totals.keys, contentPerformanceColumns);
            for (final metric in ContentPerformanceMetric.values) {
              expect(model.totalFor(metric), expected[metric.column]);
            }
          }
        }
      }
    },
  );

  test(
    'totals remain independent immutable snapshots including zero metrics',
    () {
      final row = <String, dynamic>{'page_views': 3, 'saves': -2};
      final first = ModelContentPerformance([row], statisticsOnly: true);
      row['page_views'] = 9;
      row['saves'] = 0;
      final second = ModelContentPerformance([row], statisticsOnly: true);
      expect(first.totalFor(ContentPerformanceMetric.pageViews), 3);
      expect(first.totalFor(ContentPerformanceMetric.saves), -2);
      expect(second.totalFor(ContentPerformanceMetric.pageViews), 9);
      expect(second.totalFor(ContentPerformanceMetric.saves), 0);
      expect(first.totals, hasLength(ContentPerformanceMetric.values.length));
      expect(() => first.totals.clear(), throwsUnsupportedError);
      final empty = ModelContentPerformance([], statisticsOnly: true);
      expect(empty.totals.values, everyElement(0));
      expect(empty.visibleMetrics, isEmpty);
    },
  );
}
