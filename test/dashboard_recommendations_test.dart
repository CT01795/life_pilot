import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/pages/home/model/dashboard/model_dashboard_recommendations.dart';

Map<String, dynamic> _row(
  String id, {
  String? date = '2026-10-20',
  String? time = '09:00',
  String? city = 'A',
  String? location = 'A',
  String? name,
}) => {
  'id': id,
  'name': name ?? id,
  'start_date': date,
  'start_time': time,
  'city': city,
  'location': location,
};

void main() {
  List<String> ids(Iterable<Map<String, dynamic>> rows) =>
      ModelDashboardRecommendations.events(rows).map((e) => e.id).toList();

  test('events preserve date priority before time', () {
    expect(
      ids([
        _row('later', date: '2026-10-21', time: '00:00'),
        _row('early', time: '23:59'),
        _row('missing', date: null),
      ]),
      ['early', 'later', 'missing'],
    );
  });

  test('missing time sorts after all valid times on the same date', () {
    expect(
      ids([
        _row('missing', time: null),
        _row('late', time: '23:59'),
        _row('early', time: '00:00'),
      ]),
      ['early', 'late', 'missing'],
    );
  });

  test('equal dates and times sort by city then location then name', () {
    expect(
      ids([
        _row('city', city: 'B'),
        _row('location', location: 'B'),
        _row('name-b', name: 'B'),
        _row('name-a', name: 'A'),
      ]),
      ['name-a', 'name-b', 'location', 'city'],
    );
  });

  test('empty nullable labels remain sortable', () {
    expect(ids([_row('filled'), _row('empty', city: null, location: null)]), [
      'empty',
      'filled',
    ]);
  });

  test('places retain RPC order and neither decoder mutates input', () {
    final rows = List<Map<String, dynamic>>.unmodifiable([
      Map<String, dynamic>.unmodifiable(_row('z', city: 'Z')),
      Map<String, dynamic>.unmodifiable(_row('a')),
    ]);
    expect(ModelDashboardRecommendations.places(rows).map((e) => e.id), [
      'z',
      'a',
    ]);
    expect(ids(rows), ['a', 'z']);
    expect(rows.map((e) => e['id']), ['z', 'a']);
  });

  test('empty and single-record responses need no special UI handling', () {
    expect(ids([]), isEmpty);
    expect(ModelDashboardRecommendations.places([]), isEmpty);
    expect(ids([_row('one')]), ['one']);
    expect(ids([_row('same'), _row('same')]), ['same', 'same']);
  });
}
