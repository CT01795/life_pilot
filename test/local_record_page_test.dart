import 'dart:collection';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/utils/model_local_record_page.dart';
import 'package:life_pilot/utils/record_row_utils.dart';
import 'package:life_pilot/utils/value_parser.dart';

class _LightRow extends MapBase<String, dynamic> {
  final String date;
  _LightRow(this.date);
  @override
  dynamic operator [](Object? key) => switch (key) {
    'account_id' => 'a',
    'type' => 'balance',
    'value' => 1,
    'date' => date,
    'primary_category' => 'food',
    _ => throw StateError('Unexpected field $key'),
  };
  @override
  Iterable<String> get keys => throw StateError('Must not clone row maps');
  @override
  void operator []=(String key, dynamic value) =>
      throw UnsupportedError('read-only');
  @override
  void clear() => throw UnsupportedError('read-only');
  @override
  dynamic remove(Object? key) => throw UnsupportedError('read-only');
}

void main() {
  final from = DateTime(2026, 10, 1), to = DateTime(2026, 10, 30);
  ModelLocalRecordPage select(
    Iterable<RecordRow> rows, {
    bool points = false,
    bool fallback = false,
    bool reserved = true,
  }) =>
      (points ? ModelLocalRecordPage.points : ModelLocalRecordPage.accounting)(
        rows,
        accountId: 'a',
        type: 'balance',
        from: from,
        to: to,
        includeLatestFallback: fallback,
        includeReservedRecords: reserved,
      );
  RecordRow row(
    String id,
    String? date, {
    Object? value = 1,
    String category = 'food',
    String account = 'a',
    String type = 'balance',
  }) => {
    'id': id,
    'date': date,
    'value': value,
    'primary_category': category,
    'account_id': account,
    'type': type,
  };

  for (final points in [false, true]) {
    group(points ? 'points' : 'accounting', () {
      test('matches previous filter/sort/total across 100 random batches', () {
        final random = Random(38);
        for (var batch = 0; batch < 100; batch++) {
          final rows = List.generate(
            50,
            (i) => row(
              '$i',
              i % 11 == 0
                  ? null
                  : i % 13 == 0
                  ? 'invalid'
                  : from
                        .add(Duration(days: random.nextInt(100) - 40))
                        .toIso8601String(),
              value: i % 7 == 0 ? '-12.3456' : random.nextInt(100) - 50.1234,
              account: i % 3 == 0 ? 'other' : 'a',
              type: i % 5 == 0
                  ? 'other'
                  : i % 2 == 0
                  ? 'BALANCE'
                  : 'balance',
              category: i % 9 == 0 ? 'reserved' : 'food',
            ),
          );
          final matching = rows
              .where(
                (r) =>
                    parseStringValue(r['account_id']) == 'a' &&
                    parseStringValue(r['type']).toLowerCase() == 'balance',
              )
              .toList();
          final total = matching.fold<num>(
            0,
            (sum, r) =>
                sum +
                (points
                    ? parseIntValue(r['value'])
                    : parseNumValue(r['value'])),
          );
          for (final fallback in [false, true]) {
            for (final reserved in [false, true]) {
              final page = select(
                rows,
                points: points,
                fallback: fallback,
                reserved: reserved,
              );
              final expected = filterRecordRows(
                matching,
                from: from,
                to: to,
                includeLatestFallback: fallback,
                includeReservedRecords: reserved,
              );
              expect(page.rows, expected, reason: '$batch/$fallback/$reserved');
              expect(page.total, total);
            }
          }
        }
      });
      test(
        'total includes hidden dates and reserved values, not other accounts',
        () {
          final page = select([
            row('old', '2020-01-01', value: 10),
            row('today', '2026-10-21', value: 20),
            row('future', '2027-01-01', value: -3),
            row('reserved', null, value: 4, category: 'reserved'),
            row('other', '2026-10-21', value: 999, account: 'other'),
          ], points: points);
          expect(page.total, 31);
          expect(page.rows.map((r) => r['id']).toSet(), {'today', 'reserved'});
        },
      );
      test(
        'no regular recent row retains reserved rows and latest fallback once',
        () {
          final page = select(
            [
              row('old', '2020-01-01'),
              row('latest', '2026-09-30'),
              row('reserved', '2020-01-01', category: 'reserved'),
            ],
            points: points,
            fallback: true,
          );
          expect(page.rows.map((r) => r['id']), ['latest', 'reserved']);
          expect(page.total, 3);
        },
      );
      test('single-pass source does not copy rows or read descriptions', () {
        var visits = 0;
        Iterable<RecordRow> rows() sync* {
          for (var i = 0; i < 1000; i++) {
            visits++;
            yield _LightRow(i == 0 ? '2026-10-21' : '2020-01-01');
          }
        }

        final page = select(rows(), points: points);
        expect(visits, 1000);
        expect(page.total, 1000);
        expect(page.rows.length, 1);
      });
    });
  }
  test(
    'point totals keep per-row integer parsing rather than rounding final sum',
    () {
      final rows = [
        row('a', '2026-10-21', value: 1.9),
        row('b', '2026-10-21', value: 1.9),
        row('c', '2026-10-21', value: '2.5'),
      ];
      expect(select(rows, points: true).total, 2);
      expect(select(rows).total, 6.3);
    },
  );
  test('date window includes final day but excludes next midnight', () {
    final page = select([
      row('start', from.toIso8601String()),
      row('last', DateTime(2026, 10, 30, 23, 59).toIso8601String()),
      row('next', DateTime(2026, 10, 31).toIso8601String()),
    ]);
    expect(page.rows.map((r) => r['id']), ['last', 'start']);
  });
  test(
    'type remains case-insensitive without introducing whitespace trimming',
    () {
      final page = select([
        row('case', '2026-10-21', type: 'BALANCE'),
        row('space', '2026-10-21', type: ' balance '),
      ]);
      expect(page.rows.single['id'], 'case');
      expect(page.total, 1);
    },
  );
  test(
    'read-only sources remain untouched and visible result is immutable',
    () {
      final a = Map<String, dynamic>.unmodifiable(row('a', '2026-10-20'));
      final b = Map<String, dynamic>.unmodifiable(row('b', '2026-10-21'));
      final rows = List<RecordRow>.unmodifiable([a, b]);
      final page = select(rows);
      expect(rows, [a, b]);
      expect(page.rows.first, same(b));
      expect(() => page.rows.clear(), throwsUnsupportedError);
    },
  );
  test('empty input returns no rows and zero total even with fallback', () {
    final page = select([], fallback: true);
    expect(page.rows, isEmpty);
    expect(page.total, 0);
  });
}
