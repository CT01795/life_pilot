import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/event/model_content_performance.dart';
import 'package:life_pilot/event/model_content_performance_period.dart';
import 'package:life_pilot/event/model_content_performance_query.dart';

class _Comparisons {
  int count = 0;
}

class _CountedDate implements DateTime {
  final DateTime value;
  final _Comparisons comparisons;
  _CountedDate(this.value, this.comparisons);
  @override
  DateTime toLocal() => this;
  @override
  int compareTo(DateTime other) {
    comparisons.count++;
    return value.compareTo(other is _CountedDate ? other.value : other);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final attractions in [false, true]) {
    test(
      '$attractions strictly ordered records require only adjacent checks',
      () {
        final comparisons = _Comparisons();
        final rows = [
          for (var i = 0; i < 1000; i++)
            <String, dynamic>{
              'id': '$i',
              'name': 'Event $i',
              'city': 'City',
              'end_date': _CountedDate(DateTime(2026, 1, i + 1), comparisons),
              'page_views': 1,
            },
        ];
        final model = ModelContentPerformance(
          rows,
          sortByExpiry: true,
          attractions: attractions,
        );
        expect(comparisons.count, 999);
        expect(
          model.items.map((item) => item.id),
          rows.map((row) => row['id']),
        );
        expect(model.totalFor(ContentPerformanceMetric.pageViews), 1000);
        expect(() => model.items.clear(), throwsUnsupportedError);
      },
    );

    test(
      '$attractions shuffled and tied rows match the original sort exactly',
      () {
        final random = Random(20261028);
        for (var batch = 0; batch < 100; batch++) {
          final rows = List<Map<String, dynamic>>.generate(
            60,
            (i) => {
              'id': '${random.nextInt(4)}',
              'name': 'Name ${random.nextInt(3)}',
              'city': 'City ${random.nextInt(3)}',
              'start_date': random.nextBool()
                  ? null
                  : '2026-0${random.nextInt(3) + 1}-01',
              'end_date': random.nextBool()
                  ? null
                  : '2026-0${random.nextInt(3) + 1}-28',
              'page_views': i % 3,
              'probe': i,
            },
          );
          for (final statisticsOnly in [false, true]) {
            final expected =
                rows
                    .where((r) => !statisticsOnly || r['page_views'] != 0)
                    .map(ContentPerformanceItem.new)
                    .toList()
                  ..sort((a, b) => a.compare(b, attractions: attractions));
            final model = ModelContentPerformance(
              rows,
              sortByExpiry: true,
              attractions: attractions,
              statisticsOnly: statisticsOnly,
            );
            expect(
              model.items.map((r) => r.source['probe']),
              expected.map((r) => r.source['probe']),
              reason: 'batch $batch',
            );
            expect(rows.first['probe'], 0); // Never reorder the caller's list.
          }
        }
      },
    );
  }

  test('disabled sorting performs no date comparisons', () {
    final comparisons = _Comparisons();
    final model = ModelContentPerformance([
      for (var i = 3; i > 0; i--)
        <String, dynamic>{
          'id': '$i',
          'end_date': _CountedDate(DateTime(2026, i), comparisons),
        },
    ]);
    expect(comparisons.count, 0);
    expect(model.items.map((item) => item.id), ['3', '2', '1']);
  });

  test('zero-statistic rows do not force sorting or decode excluded dates', () {
    final comparisons = _Comparisons();
    final model = ModelContentPerformance(
      [
        {
          'id': 'first',
          'page_views': 1,
          'end_date': _CountedDate(DateTime(2026, 1), comparisons),
        },
        {'id': 'excluded', 'page_views': 0, 'end_date': 'invalid'},
        {
          'id': 'last',
          'page_views': 1,
          'end_date': _CountedDate(DateTime(2026, 2), comparisons),
        },
      ],
      sortByExpiry: true,
      statisticsOnly: true,
    );
    expect(comparisons.count, 1);
    expect(model.items.map((item) => item.id), ['first', 'last']);
  });

  test('shared query fragments do not retain month, keyword or user data', () {
    final july = ContentPerformancePeriod(
      month: DateTime(2026, 7),
      now: DateTime(2026, 10, 28),
    );
    final query = ModelContentPerformanceQuery(
      period: july,
      keyword: '台北',
      statisticsOnly: true,
    );
    final plain = ModelContentPerformanceQuery();
    expect(query.filter, contains(july.databaseFilter));
    expect(query.filter, contains('台北'));
    expect(plain.filter, isNull);
    expect(plain.columns, isNot(contains('city')));
    expect(query.columns, endsWith(',city,start_date,end_date'));
    final next = ModelContentPerformanceQuery(
      keyword: '高雄',
      statisticsOnly: true,
    );
    expect(next.filter, isNot(contains('台北')));
    expect(next.filter, isNot(contains(july.databaseFilter)));
    for (final column in contentPerformanceColumns) {
      expect(next.filter, contains('$column.neq.0'));
    }
  });
}
