import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/event/model_content_performance.dart';
import 'package:life_pilot/record_statistics/model_record_statistics.dart';

void main() {
  test('zero-only performance has no visible overview or item metrics', () {
    final model = ModelContentPerformance([{}]);
    expect(model.visibleMetrics, isEmpty);
    expect(model.items.single.visibleMetrics, isEmpty);
  });

  test(
    'nonzero metric projections keep enum order, negatives and immutable identity',
    () {
      final model = ModelContentPerformance([
        {
          'dislike_counts': 4,
          'like_counts': 0,
          'saves': 2,
          'page_views': '10',
          'card_clicks': -1,
        },
      ]);
      final item = model.items.single;
      final expected = [
        ContentPerformanceMetric.pageViews,
        ContentPerformanceMetric.navigationClicks,
        ContentPerformanceMetric.saves,
        ContentPerformanceMetric.dislikes,
      ];
      expect(item.visibleMetrics.map((value) => value.metric), expected);
      expect(model.visibleMetrics.map((value) => value.metric), expected);
      expect(item.visibleMetrics.map((value) => value.count), [10, -1, 2, 4]);
      expect(identical(item.visibleMetrics, item.visibleMetrics), true);
      expect(identical(model.visibleMetrics, model.visibleMetrics), true);
      expect(() => item.visibleMetrics.clear(), throwsUnsupportedError);
      expect(() => model.visibleMetrics.clear(), throwsUnsupportedError);
    },
  );

  test(
    'new response rebuilds nonzero lists without changing old snapshots',
    () {
      final row = <String, dynamic>{'page_views': 2, 'saves': 0};
      final old = ModelContentPerformance([row]);
      final oldMetrics = old.visibleMetrics;
      row['page_views'] = 0;
      row['saves'] = 7;
      final fresh = ModelContentPerformance([row]);
      expect(oldMetrics.single.metric, ContentPerformanceMetric.pageViews);
      expect(old.items.single.visibleMetrics.single.count, 2);
      expect(
        fresh.visibleMetrics.single.metric,
        ContentPerformanceMetric.saves,
      );
      expect(fresh.items.single.visibleMetrics.single.count, 7);
    },
  );

  test(
    'zero aggregate metric stays hidden while individual nonzero values remain',
    () {
      final model = ModelContentPerformance([
        {'page_views': 5},
        {'page_views': -5},
      ]);
      expect(model.visibleMetrics, isEmpty);
      expect(model.items.first.visibleMetrics.single.count, 5);
      expect(model.items.last.visibleMetrics.single.count, -5);
      expect(model.totalFor(ContentPerformanceMetric.pageViews), 0);
    },
  );

  test('metric denominator remains the filtered result total', () {
    final all = ModelContentPerformance([
      {'page_views': 3},
      {'page_views': 7},
    ]);
    final filtered = ModelContentPerformance([
      {'page_views': 3},
    ]);
    expect(all.visibleMetrics.single.count, 10);
    expect(filtered.visibleMetrics.single.count, 3);
    expect(
      all.shareFor(all.items.first, ContentPerformanceMetric.pageViews),
      0.3,
    );
    expect(
      filtered.shareFor(
        filtered.items.first,
        ContentPerformanceMetric.pageViews,
      ),
      1,
    );
  });

  test(
    'statistics-only filtering and null/string counters preserve visible metrics',
    () {
      final model = ModelContentPerformance([
        {'id': 'empty'},
        {
          'id': 'used',
          'page_views': null,
          'saves': '8',
          'like_counts': 'invalid',
          'dislike_counts': '2',
        },
      ], statisticsOnly: true);
      expect(model.items.single.id, 'used');
      expect(model.visibleMetrics.map((value) => value.count), [8, 2]);
      expect(model.items.single.visibleMetrics.map((value) => value.metric), [
        ContentPerformanceMetric.saves,
        ContentPerformanceMetric.dislikes,
      ]);
    },
  );
  test(
    'chart modes cache separate immutable projections without changing chronological totals',
    () {
      final model = ModelRecordStatistics.fromRows([
        {'date': '2020-01-01', 'value': 1000},
        {'date': '2026-09-01', 'value': -50},
        {'date': '2026-10-01', 'value': 25.1234},
      ], now: DateTime(2026, 10, 19));
      final cumulative = model.series(cumulative: true);
      final monthly = model.series(cumulative: false);
      expect(identical(cumulative, model.series(cumulative: true)), true);
      expect(identical(monthly, model.series(cumulative: false)), true);
      expect(identical(cumulative, monthly), false);
      expect(cumulative.months.first.month, DateTime(2026, 10));
      expect(cumulative.values.first, closeTo(975.1234, 0.000001));
      expect(monthly.values.take(2), [25.1234, -50]);
      expect(monthly.maximum, 50);
      expect(model.months.first.month, DateTime(2025, 11));
      expect(() => model.months.clear(), throwsUnsupportedError);
      expect(() => cumulative.values.add(1), throwsUnsupportedError);
      expect(() => monthly.months.clear(), throwsUnsupportedError);
    },
  );
  test('zero-only chart has a nonzero scale and no NaN bars', () {
    final model = ModelRecordStatistics.fromRows(
      [],
      now: DateTime(2026, 10, 19),
    );
    expect(model.series(cumulative: true).maximum, 1);
    expect(model.series(cumulative: false).maximum, 1);
  });
  test(
    'typed performance entries and totals are stable snapshots with counters parsed once',
    () {
      final row = <String, dynamic>{
        'id': 'a',
        'name': 'Original',
        'city': 'A',
        'is_approved': true,
        'page_views': '1234',
        'saves': 5,
        'like_counts': 2,
        'start_date': '2026-06-01',
        'end_date': '2026-07-31',
      };
      final model = ModelContentPerformance([row]);
      row['name'] = 'Changed';
      row['page_views'] = 0;
      final item = model.items.single;
      expect(item.name, 'Original');
      expect(item.source['name'], 'Original');
      expect(item.counts, [1234, 0, 0, 5, 2, 0]);
      expect(item.maximum, 1234);
      expect(item.approved, true);
      expect(item.expires, DateTime(2026, 7, 31));
      expect(model.totals['page_views'], 1234);
      expect(() => item.source['name'] = 'bad', throwsUnsupportedError);
      expect(() => item.counts.clear(), throwsUnsupportedError);
      expect(() => model.items.clear(), throwsUnsupportedError);
      expect(() => model.totals.clear(), throwsUnsupportedError);
    },
  );
  test(
    'prepared activity sort preserves expiry ascending, city ascending and start descending',
    () {
      final rows = <Map<String, dynamic>>[
        {'id': 'no-date'},
        {'id': 'later', 'start_date': '2027-01-01'},
        {
          'id': 'B',
          'city': 'B',
          'start_date': '2026-07-01',
          'end_date': '2026-07-31',
        },
        {
          'id': 'A',
          'city': 'A',
          'start_date': '2026-07-01',
          'end_date': '2026-07-31',
        },
        {'id': 'early', 'start_date': '2026-06-01', 'end_date': '2026-07-31'},
      ];
      final expected = [...rows]..sort(compareContentPerformance);
      final prepared = ModelContentPerformance(rows, sortByExpiry: true);
      expect(
        prepared.items.map((item) => item.id),
        expected.map((row) => row['id']),
      );
      expect(prepared.items.map((item) => item.id), [
        'early',
        'A',
        'B',
        'later',
        'no-date',
      ]);
    },
  );
}
