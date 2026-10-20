import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/event/model_content_performance.dart';
import 'package:life_pilot/event/model_content_performance_period.dart';
import 'package:life_pilot/event/model_content_performance_query.dart';
import 'package:life_pilot/utils/paged_row_reader.dart';

void main() {
  test(
    'complete pagination continues past capped short pages until empty',
    () async {
      final calls = <(int, int)>[];
      final source = [
        for (var i = 0; i < 5; i++) {'id': '$i'},
      ];
      final rows = await readAllPagedRows(
        fetch: (offset, limit) async {
          calls.add((offset, limit));
          return source.skip(offset).take(2).toList();
        },
      );
      expect(rows.map((row) => row['id']), ['0', '1', '2', '3', '4']);
      expect(calls, [(0, 500), (2, 500), (4, 500), (5, 500)]);
      source.first['id'] = 'mutated';
      expect(rows.first['id'], '0');
    },
  );
  test('empty result requires just one fetch', () async {
    var calls = 0;
    expect(
      await readAllPagedRows(
        fetch: (offset, limit) async {
          calls++;
          return [];
        },
      ),
      isEmpty,
    );
    expect(calls, 1);
  });
  test('duplicate pages fail instead of doubling counts or looping', () async {
    var calls = 0;
    await expectLater(
      readAllPagedRows(
        fetch: (offset, limit) async {
          calls++;
          return [
            {'id': 'same'},
          ];
        },
      ),
      throwsStateError,
    );
    expect(calls, 2);
  });
  test(
    'overlapping partial pages fail without returning partial totals',
    () async {
      await expectLater(
        readAllPagedRows(
          fetch: (offset, limit) async => offset == 0
              ? [
                  {'id': 'a'},
                  {'id': 'b'},
                ]
              : [
                  {'id': 'b'},
                  {'id': 'c'},
                ],
        ),
        throwsStateError,
      );
    },
  );
  test(
    'fetch errors propagate and the next attempt starts from zero',
    () async {
      var fail = true;
      final offsets = <int>[];
      Future<List<dynamic>> fetch(int offset, int limit) async {
        offsets.add(offset);
        if (offset > 0 && fail) throw StateError('offline');
        return offset == 0
            ? [
                {'id': 'a'},
              ]
            : [];
      }

      await expectLater(readAllPagedRows(fetch: fetch), throwsStateError);
      fail = false;
      expect(await readAllPagedRows(fetch: fetch), hasLength(1));
      expect(offsets, [0, 1, 0, 1]);
    },
  );
  test('invalid batch size starts no request', () async {
    await expectLater(
      readAllPagedRows(
        batchSize: 0,
        fetch: (_, _) async => throw StateError('must not fetch'),
      ),
      throwsArgumentError,
    );
  });
  test(
    'custom batch size changes the request size, not end-of-data rules',
    () async {
      final calls = <(int, int)>[];
      await readAllPagedRows(
        batchSize: 2,
        fetch: (offset, limit) async {
          calls.add((offset, limit));
          return offset < 3
              ? [
                  {'id': '$offset'},
                ]
              : [];
        },
      );
      expect(calls, [(0, 2), (1, 2), (2, 2), (3, 2)]);
    },
  );
  for (final details in [false, true]) {
    for (final dated in [false, true]) {
      for (final searched in [false, true]) {
        for (final stats in [false, true]) {
          test(
            'query projection details=$details dated=$dated searched=$searched stats=$stats',
            () {
              final period = dated
                  ? ContentPerformancePeriod(
                      month: DateTime(2026, 7),
                      now: DateTime(2026, 10, 20),
                    )
                  : null;
              final query = ModelContentPerformanceQuery(
                includeSubmissionDetails: details,
                period: period,
                keyword: searched ? '新北,("festival")%_' : '  ',
                statisticsOnly: stats,
              );
              final groups = [
                if (period != null) period.databaseFilter,
                if (searched)
                  contentPerformanceSearchFilter('新北,("festival")%_'),
                if (stats)
                  contentPerformanceColumns
                      .map((column) => '$column.neq.0')
                      .join(','),
              ];
              expect(
                query.filter,
                groups.isEmpty
                    ? null
                    : groups.length == 1
                    ? groups.single
                    : 'and(${groups.map((group) => 'or($group)').join(',')})',
              );
              expect(
                query.columns.contains('city,start_date,end_date'),
                details || dated || stats,
              );
              expect(query.columns, isNot(contains('master_graph_url')));
            },
          );
        }
      }
    }
  }
  test('prepared dates keep the same missing-end expiration fallback', () {
    final item = ContentPerformanceItem({'start_date': '2026-10-20'});
    expect(identical(item.expires, item.starts), true);
    expect(item.ends, null);
    expect(item.visibleEndDate, null);
  });
}
