import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/event/model_content_performance.dart';
import 'package:life_pilot/record_statistics/model_record_statistics.dart';

void main() {
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
