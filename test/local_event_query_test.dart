import 'dart:collection';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/event/model_local_event_query.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/utils/date_time.dart';

class _Row extends MapBase<String, dynamic> {
  final Map<String, dynamic> data;
  int decodes = 0;
  _Row(String id, String? date)
    : data = {'id': id, 'name': id, 'start_date': date};
  @override
  dynamic operator [](Object? key) {
    if (key == 'sub_events') decodes++;
    return data[key];
  }

  @override
  void operator []=(String key, dynamic value) => data[key] = value;
  @override
  Iterable<String> get keys => data.keys;
  @override
  void clear() => data.clear();
  @override
  dynamic remove(Object? key) => data.remove(key);
}

class _StoredDate implements DateTime {
  final DateTime value;
  _StoredDate(this.value);
  @override
  bool isBefore(DateTime other) => value.isBefore(other);
  @override
  String toString() => throw StateError('Do not stringify stored DateTime');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final start = DateTime(2026, 10, 1), end = DateTime(2026, 10, 15);
  test('cancelled local iteration decodes no first event', () {
    final rows = [_Row('a', '2026-10-10')];
    expect(
      ModelLocalEventQuery.select(
        rows,
        start: start,
        end: end,
        shouldContinue: () => false,
      ),
      isEmpty,
    );
    expect(rows.single.decodes, 0);
  });
  test('cancellation after preview prevents decoding the next event', () {
    final rows = List.generate(20, (i) => _Row('$i', '2026-10-10'));
    var active = true;
    final iterator = ModelLocalEventQuery.iterate(
      rows,
      start: start,
      end: end,
      shouldContinue: () => active,
    ).iterator;
    expect(iterator.moveNext(), isTrue);
    expect(iterator.current.id, '0');
    active = false;
    expect(iterator.moveNext(), isFalse);
    expect(rows.fold<int>(0, (sum, row) => sum + row.decodes), 1);
  });
  test('cancellation while skipping offset never decodes skipped rows', () {
    final rows = List.generate(20, (i) => _Row('$i', '2026-10-10'));
    var checks = 0;
    expect(
      ModelLocalEventQuery.select(
        rows,
        start: start,
        end: end,
        offset: 10,
        shouldContinue: () => ++checks <= 3,
      ),
      isEmpty,
    );
    expect(rows.every((row) => row.decodes == 0), isTrue);
  });
  test('a cancelled query can be traversed again for a fresh active scope', () {
    final rows = [_Row('old', '2020-01-01'), _Row('wanted', '2026-10-10')];
    var active = false;
    final query = ModelLocalEventQuery.iterate(
      rows,
      start: start,
      end: end,
      id: 'old',
      shouldContinue: () => active,
    );
    expect(query, isEmpty);
    active = true;
    expect(query.single.id, 'old');
    expect(rows.map((row) => row.decodes), [1, 0]);
  });
  test('repeated date runs preserve filtering order and pagination', () {
    final rows = [
      for (var i = 0; i < 100; i++) _Row('old-$i', '2020-01-01'),
      for (var i = 0; i < 100; i++) _Row('visible-$i', '2026-10-10'),
      for (var i = 0; i < 100; i++) _Row('future-$i', '2027-01-01'),
    ];
    final result = ModelLocalEventQuery.select(
      rows,
      start: start,
      end: end,
      offset: 2,
      limit: 3,
    );
    expect(result.map((event) => event.id), [
      'visible-2',
      'visible-3',
      'visible-4',
    ]);
    expect(rows.fold<int>(0, (sum, row) => sum + row.decodes), 3);
  });
  test('each traversal resets date memo after a row is edited', () {
    final row = _Row('a', '2026-10-10');
    final query = ModelLocalEventQuery.iterate([row], start: start, end: end);
    expect(query.single.id, 'a');
    row.data['start_date'] = '2020-01-01';
    expect(query, isEmpty);
    row.data['start_date'] = '2026-10-10';
    expect(query.single.id, 'a');
  });
  test('different iterators cannot share a previous date decision', () {
    final rows = [_Row('a', '2026-10-10'), _Row('b', '2020-01-01')];
    final visible = ModelLocalEventQuery.iterate(
      rows,
      start: start,
      end: end,
    ).iterator;
    final old = ModelLocalEventQuery.iterate(
      rows,
      start: DateTime(2020),
      end: DateTime(2020, 1, 2),
    ).iterator;
    expect(visible.moveNext(), isTrue);
    expect(visible.current.id, 'a');
    expect(old.moveNext(), isTrue);
    expect(old.current.id, 'b');
    expect(visible.moveNext(), isFalse);
    expect(old.moveNext(), isFalse);
  });
  test('runs of missing and invalid dates stay included', () {
    final rows = [
      _Row('n1', null),
      _Row('n2', null),
      _Row('b1', 'bad'),
      _Row('b2', 'bad'),
      _Row('old', '2020-01-01'),
      _Row('visible', '2026-10-10'),
    ];
    expect(
      ModelLocalEventQuery.select(
        rows,
        start: start,
        end: end,
      ).map((event) => event.id),
      ['n1', 'n2', 'b1', 'b2', 'visible'],
    );
  });
  test('history metadata directly compares stored DateTime values', () {
    final row = _Row('stored', null);
    row.data['start_date'] = _StoredDate(DateTime(2026, 9, 30));
    expect(ModelLocalEventQuery.hasRowsBefore([row], start), isTrue);
    expect(ModelLocalEventQuery.latestRowBefore([row], start), same(row));
    expect(row.decodes, 0);
  });
  test('history availability stops after the first matching row', () {
    Iterable<Map<String, dynamic>> rows() sync* {
      yield _Row('match', '2026-09-30');
      throw StateError('Do not continue scanning after a match');
    }

    expect(ModelLocalEventQuery.hasRowsBefore(rows(), start), isTrue);
  });
  test('history metadata excludes equal, future and malformed dates', () {
    final rows = [
      _Row('equal', '2026-10-01'),
      _Row('future', '2026-10-02'),
      _Row('invalid', 'invalid'),
      _Row('missing', null),
    ];
    expect(ModelLocalEventQuery.hasRowsBefore(rows, start), isFalse);
    expect(ModelLocalEventQuery.latestRowBefore(rows, start), isNull);
    expect(ModelLocalEventQuery.hasRowsBefore([], start), isFalse);
    expect(rows.every((row) => row.decodes == 0), isTrue);
  });
  test('history existence compares instants rather than date text', () {
    final row = _Row('offset', '2026-09-30T23:00:00-02:00');
    expect(
      ModelLocalEventQuery.hasRowsBefore([row], DateTime.utc(2026, 10, 1)),
      isFalse,
    );
    expect(
      ModelLocalEventQuery.hasRowsBefore([row], DateTime.utc(2026, 10, 1, 2)),
      isTrue,
    );
  });
  test('latest equal-date ties keep the original first row', () {
    final first = _Row('first', '2026-09-30');
    final second = _Row('second', '2026-09-30');
    expect(
      ModelLocalEventQuery.latestRowBefore([first, second], start),
      same(first),
    );
  });
  test('latest fallback accepts legacy DateTime fields as well as text', () {
    final row = _Row('legacy', null);
    row.data['start_date'] = DateTime.utc(2026, 9, 30);
    expect(ModelLocalEventQuery.latestRowBefore([row], start)?['id'], 'legacy');
  });
  test(
    'latest fallback finds the newest older row without decoding history',
    () {
      final rows = [
        ...List.generate(5000, (i) => _Row('$i', '2020-01-01')),
        _Row('latest', '2026-09-30T23:59:00'),
        _Row('excluded', '2026-10-01'),
        _Row('invalid', 'bad'),
      ];
      final result = ModelLocalEventQuery.latestRowBefore(rows, start);
      expect(result!['id'], 'latest');
      expect(rows.fold<int>(0, (sum, row) => sum + row.decodes), 0);
    },
  );

  test(
    'latest fallback compares timezone instants and returns null if none',
    () {
      final rows = [
        _Row('earlier', '2026-09-30T23:00:00Z'),
        _Row('later', '2026-09-30T20:00:00-04:00'),
      ];
      expect(
        ModelLocalEventQuery.latestRowBefore(
          rows,
          DateTime.utc(2026, 10, 2),
        )!['id'],
        'later',
      );
      expect(
        ModelLocalEventQuery.latestRowBefore(rows, DateTime.utc(2020)),
        null,
      );
      expect(ModelLocalEventQuery.latestRowBefore([], start), null);
    },
  );
  test('local iterator decodes only the consumed preview', () {
    final rows = List.generate(1000, (i) => _Row('$i', '2026-10-10'));
    final iterator = ModelLocalEventQuery.iterate(
      rows,
      start: start,
      end: end,
    ).iterator;
    for (var i = 0; i < 12; i++) {
      expect(iterator.moveNext(), true);
      expect(iterator.current.id, '$i');
    }
    expect(rows.fold<int>(0, (sum, row) => sum + row.decodes), 12);
    var remaining = 0;
    while (iterator.moveNext()) {
      remaining++;
    }
    expect(remaining, 988);
  });
  test('date bounds are inclusive and normalized once', () {
    final rows = [
      _Row('before', '2026-09-30'),
      _Row('start', '2026-10-01'),
      _Row('end', '2026-10-15'),
      _Row('after', '2026-10-16'),
    ];
    final result = ModelLocalEventQuery.select(
      rows,
      start: start.add(const Duration(hours: 10)),
      end: end,
    );
    expect(result.map((event) => event.id), ['start', 'end']);
    expect(rows.map((row) => row.decodes), [0, 1, 1, 0]);
  });
  test('offset and limit are applied before full record decoding', () {
    final rows = List.generate(10, (i) => _Row('$i', '2026-10-10'));
    final result = ModelLocalEventQuery.select(
      rows,
      start: start,
      end: end,
      offset: 3,
      limit: 2,
    );
    expect(result.map((event) => event.id), ['3', '4']);
    expect(rows.fold<int>(0, (sum, row) => sum + row.decodes), 2);
  });
  test('id lookup ignores date window and only decodes matching record', () {
    final rows = [_Row('old', '2020-01-01'), _Row('new', '2026-10-10')];
    expect(
      ModelLocalEventQuery.select(
        rows,
        start: start,
        end: end,
        id: 'old',
      ).single.id,
      'old',
    );
    expect(rows.map((row) => row.decodes), [1, 0]);
  });
  test('undated and malformed dates preserve existing inclusion behavior', () {
    final rows = [_Row('null', null), _Row('bad', 'not a date')];
    expect(ModelLocalEventQuery.select(rows, start: start, end: end).length, 2);
  });
  test('large old history does not decode out-of-window sub-events', () {
    final rows = [
      ...List.generate(5000, (i) => _Row('$i', '2020-01-01')),
      _Row('visible', '2026-10-10'),
    ];
    expect(
      ModelLocalEventQuery.select(rows, start: start, end: end).single.id,
      'visible',
    );
    expect(rows.fold<int>(0, (sum, row) => sum + row.decodes), 1);
  });
  test(
    'selection matches original parsed-event filtering including timezone dates',
    () {
      final rows = [
        _Row('utc', '2026-10-01T00:00:00Z'),
        _Row('offset', '2026-10-15T23:00:00-08:00'),
        _Row('none', null),
        _Row('old', '2020-01-01'),
      ];
      final expected = rows
          .map((row) => EventItem.fromJson(json: row))
          .where((event) {
            if (event.startDate == null) return true;
            final day = DateTimeFormatter.dateOnly(event.startDate!.toLocal());
            return !day.isBefore(start) && !day.isAfter(end);
          })
          .map((event) => event.id);
      expect(
        ModelLocalEventQuery.select(
          rows,
          start: start,
          end: end,
        ).map((event) => event.id),
        expected,
      );
    },
  );
}
