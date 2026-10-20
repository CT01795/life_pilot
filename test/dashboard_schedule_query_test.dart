import 'dart:collection';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/pages/home/model/dashboard/model_dashboard_schedule_query.dart';

final _today = DateTime(2026, 10, 20);
Map<String, dynamic> _row(
  String id, {
  DateTime? start,
  DateTime? end,
  bool completed = false,
  String? time = '09:00',
  String city = '',
  String location = '',
  String? name,
}) => {
  'id': id,
  'name': name ?? id,
  'start_date': (start ?? _today).toUtc().toIso8601String(),
  'end_date': end?.toUtc().toIso8601String(),
  'start_time': time,
  'city': city,
  'location': location,
  'is_completed': completed,
};

class _CountedRow extends MapBase<String, dynamic> {
  final Map<String, dynamic> data;
  int decodes = 0;
  _CountedRow(this.data);
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

void main() {
  final query = ModelDashboardScheduleQuery(
    _today.add(const Duration(hours: 14)),
  );
  test('window uses local midnight and excludes the third-day boundary', () {
    expect(query.today, _today);
    expect(query.rangeEnd, _today.add(const Duration(days: 3)));
    final rows = [
      _row('today'),
      _row('tomorrow', start: _today.add(const Duration(days: 1))),
      _row('last', start: _today.add(const Duration(days: 2, hours: 23))),
      _row('boundary', start: query.rangeEnd),
    ];
    expect(query.selectLocal(rows).map((event) => event.id), [
      'today',
      'tomorrow',
      'last',
    ]);
  });

  test('ongoing past-start event remains visible until its end date', () {
    final past = _today.subtract(const Duration(days: 10));
    final rows = [
      _row('ongoing', start: past, end: _today),
      _row('ended', start: past, end: _today.subtract(const Duration(days: 1))),
      _row('old-single-day', start: past),
    ];
    expect(query.selectLocal(rows).map((event) => event.id), ['ongoing']);
  });

  test('completed and invalid-start rows are excluded before decoding', () {
    final rows = [
      _CountedRow(_row('done', completed: true)),
      _CountedRow(_row('invalid')..['start_date'] = 'invalid'),
      _CountedRow(_row('missing')..remove('start_date')),
      _CountedRow(_row('valid')),
    ];
    expect(query.selectLocal(rows).single.id, 'valid');
    expect(rows.map((row) => row.decodes), [0, 0, 0, 1]);
  });

  test('malformed end date retains single-day fallback', () {
    final row = _row('single')..['end_date'] = 'invalid';
    expect(query.selectLocal([row]).single.id, 'single');
  });

  test('timezone-bearing timestamps are compared as instants', () {
    final midnight = _today.toUtc().toIso8601String();
    final justBefore = _today
        .subtract(const Duration(seconds: 1))
        .toUtc()
        .toIso8601String();
    final rows = [
      _row('included')..['start_date'] = midnight,
      _row('excluded')..['start_date'] = justBefore,
    ];
    expect(query.selectLocal(rows).single.id, 'included');
  });

  test('large historical source only decodes matching records', () {
    final old = List.generate(
      5000,
      (i) => _CountedRow(_row('old-$i', start: DateTime(2020, 1, 1))),
    );
    final recent = _CountedRow(_row('recent'));
    expect(query.selectLocal([...old, recent]).single.id, 'recent');
    expect(old.fold<int>(0, (sum, row) => sum + row.decodes), 0);
    expect(recent.decodes, 1);
  });

  test('ordering remains date, time, city, location, then name', () {
    final rows = [
      _row('city', city: 'B', location: 'A'),
      _row('name-b', city: 'A', location: 'A', name: 'B'),
      _row('last-time', time: null),
      _row('location', city: 'A', location: 'B'),
      _row('name-a', city: 'A', location: 'A', name: 'A'),
      _row('earlier', time: '08:00', city: 'Z'),
      _row(
        'later-day',
        start: _today.add(const Duration(days: 1)),
        time: '01:00',
      ),
    ];
    expect(query.selectLocal(rows).map((event) => event.id), [
      'earlier',
      'name-a',
      'name-b',
      'location',
      'city',
      'last-time',
      'later-day',
    ]);
  });

  test('read-only source and child data are not mutated', () {
    final child = Map<String, dynamic>.unmodifiable({'name': 'child'});
    final source = List<Map<String, dynamic>>.unmodifiable([
      Map<String, dynamic>.unmodifiable(
        _row('later', time: '10:00')..['sub_events'] = [child],
      ),
      Map<String, dynamic>.unmodifiable(_row('earlier', time: '08:00')),
    ]);
    final result = query.selectLocal(source);
    expect(result.map((event) => event.id), ['earlier', 'later']);
    expect(source.first['id'], 'later');
    expect(result.last.subEvents.single['name'], 'child');
    expect(child, {'name': 'child'});
  });

  test(
    'cloud decoding sorts server-filtered rows without local re-filtering',
    () {
      final result = query.decodeRows([
        _row('later', start: _today.add(const Duration(days: 10))),
        _row('earlier', start: _today.subtract(const Duration(days: 10))),
      ]);
      expect(result.map((event) => event.id), ['earlier', 'later']);
    },
  );
}
