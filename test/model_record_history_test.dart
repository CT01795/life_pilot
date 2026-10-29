import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/utils/model_record_history.dart';

class _Row {
  _Row(this.id, this.date, [this.category = 'food']);
  final String id, category;
  final DateTime date;
}

void main() {
  final start = DateTime(2026, 10);
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
