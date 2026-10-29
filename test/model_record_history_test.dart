import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/utils/model_record_history.dart';

class _Row {
  _Row(this.id, this.date, [this.category = 'food']);
  final String id, category;
  final DateTime date;
}

/// Instrument the two ordering operations without measuring wall-clock time.
class _TrackedDate implements DateTime {
  _TrackedDate(int day) : value = DateTime(2026, 1, day);
  final DateTime value;
  int comparisons = 0, orderChecks = 0;
  static DateTime unwrap(DateTime other) =>
      other is _TrackedDate ? other.value : other;
  @override
  int compareTo(DateTime other) {
    comparisons++;
    return value.compareTo(unwrap(other));
  }

  @override
  bool isAfter(DateTime other) {
    orderChecks++;
    return value.isAfter(unwrap(other));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final start = DateTime(2026, 10);
  test(
    'strictly newest-first history validates once and performs no sort comparisons',
    () {
      final rows = [
        for (var i = 10000; i > 0; i--) _Row('$i', _TrackedDate(i)),
      ];
      final result = ModelRecordHistory.ordered(
        rows,
        idOf: (r) => r.id,
        dateOf: (r) => r.date,
      );
      expect(result, orderedEquals(rows));
      expect(
        rows.fold<int>(
          0,
          (sum, row) => sum + (row.date as _TrackedDate).comparisons,
        ),
        0,
      );
      expect(
        rows.fold<int>(
          0,
          (sum, row) => sum + (row.date as _TrackedDate).orderChecks,
        ),
        rows.length - 1,
      );
      expect(result, isNot(same(rows)));
    },
  );
  for (final ties in [true, false]) {
    test(
      '${ties ? 'equal dates' : 'late disorder'} retains the original sort path',
      () {
        final rows = [
          for (var i = 100; i > 0; i--) _Row('$i', _TrackedDate(ties ? 1 : i)),
        ];
        if (!ties) rows.add(_Row('newest', _TrackedDate(101)));
        final expected = List<_Row>.of(rows)
          ..sort((a, b) => b.date.compareTo(a.date));
        for (final row in rows) {
          (row.date as _TrackedDate).comparisons = 0;
        }
        final result = ModelRecordHistory.ordered(
          rows,
          idOf: (r) => r.id,
          dateOf: (r) => r.date,
        );
        expect(result, orderedEquals(expected));
        expect(
          rows.any((row) => (row.date as _TrackedDate).comparisons > 0),
          isTrue,
        );
      },
    );
  }
  test(
    'a duplicate replacement is checked before considering order reusable',
    () {
      final old = _Row('a', _TrackedDate(10));
      final keep = _Row('b', _TrackedDate(9));
      final replacement = _Row('a', _TrackedDate(1));
      var dates = 0;
      final result = ModelRecordHistory.ordered(
        [old, keep, replacement],
        idOf: (r) => r.id,
        dateOf: (r) {
          dates++;
          return r.date;
        },
      );
      expect(result, [keep, replacement]);
      expect(dates, 2);
      expect((old.date as _TrackedDate).comparisons, 0);
    },
  );
  test(
    'last duplicate wins; source stays unchanged and equal-date order is preserved',
    () {
      final a = _Row('a', start), b = _Row('b', start);
      final replacement = _Row('a', start.add(const Duration(days: 1)));
      final source = [a, b, replacement];
      final result = ModelRecordHistory.ordered(
        source,
        idOf: (r) => r.id,
        dateOf: (r) => r.date,
      );
      expect(result, [replacement, b]);
      expect(source, [a, b, replacement]);
    },
  );
  test(
    'ordering matches prior map-and-sort rules across random duplicate lists',
    () {
      final random = Random(3010);
      for (var batch = 0; batch < 100; batch++) {
        final rows = [
          for (var i = 0; i < 300; i++)
            _Row(
              '${random.nextInt(100)}',
              DateTime(2026, 10, 1 + random.nextInt(10)),
            ),
        ];
        final unique = <String, _Row>{};
        for (final row in rows) {
          unique[row.id] = row;
        }
        final expected = unique.values.toList()
          ..sort((a, b) => b.date.compareTo(a.date));
        expect(
          ModelRecordHistory.ordered(
            rows,
            idOf: (r) => r.id,
            dateOf: (r) => r.date,
          ),
          expected,
        );
      }
    },
  );
  test('sort computes dates once per unique row, not per comparison', () {
    var ids = 0, dates = 0;
    final rows = [
      for (var i = 0; i < 10000; i++) _Row('$i', DateTime(2026, 1, i + 1)),
    ];
    final result = ModelRecordHistory.ordered(
      rows,
      idOf: (r) {
        ids++;
        return r.id;
      },
      dateOf: (r) {
        dates++;
        return r.date;
      },
    );
    expect(result.length, rows.length);
    expect(ids, 10000);
    expect(dates, 10000);
  });
  test(
    'fallback ignores reserved rows and retains latest older regular date',
    () {
      final rows = [
        _Row('reserved', DateTime(2027), 'reserved'),
        _Row('old', DateTime(2026, 4, 1)),
        _Row('latest', DateTime(2026, 4, 15)),
      ];
      expect(
        ModelRecordHistory.fallbackStart(
          rows,
          start: start,
          categoryOf: (r) => r.category,
          dateOf: (r) => r.date,
        ),
        DateTime(2026, 4, 15),
      );
      expect(
        ModelRecordHistory.fallbackStart(
          rows.take(1),
          start: start,
          categoryOf: (r) => r.category,
          dateOf: (r) => r.date,
        ),
        start,
      );
    },
  );
  test(
    'current-window regular row stops fallback scan without reading later dates',
    () {
      var reads = 0;
      final rows = [_Row('today', start), _Row('later', DateTime(2026, 4))];
      expect(
        ModelRecordHistory.fallbackStart(
          rows,
          start: start,
          categoryOf: (r) => r.category,
          dateOf: (r) {
            reads++;
            return r.date;
          },
        ),
        start,
      );
      expect(reads, 1);
    },
  );
  test(
    'empty input retains the original cursor and has no ordering output',
    () {
      expect(
        ModelRecordHistory.ordered<_Row>(
          [],
          idOf: (r) => r.id,
          dateOf: (r) => r.date,
        ),
        isEmpty,
      );
      expect(
        ModelRecordHistory.fallbackStart<_Row>(
          [],
          start: start,
          categoryOf: (r) => r.category,
          dateOf: (r) => r.date,
        ),
        start,
      );
    },
  );
}
