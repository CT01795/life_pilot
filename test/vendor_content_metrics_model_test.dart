import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/event/model_content_performance.dart';
import 'package:life_pilot/vendor/model_vendor_account.dart';
import 'package:life_pilot/utils/value_parser.dart';

final _today = DateTime(2026, 10, 29);
VendorContentMetrics _project(
  List<Map<String, dynamic>> events, [
  List<Map<String, dynamic>> attractions = const [],
]) => VendorContentMetrics.fromPerformance(
  events: ModelContentPerformance(events),
  attractions: ModelContentPerformance(attractions),
  now: _today,
);

// Previous service rules are deliberately retained as a reference comparator.
List<VendorRecentSubmission> _legacyRecent(
  List<Map<String, dynamic>> events,
  List<Map<String, dynamic>> attractions,
) {
  VendorRecentSubmission read(Map<String, dynamic> row, bool activity) =>
      VendorRecentSubmission(
        id: parseStringValue(row['id']),
        name: parseStringValue(row['name']),
        city: parseStringValue(row['city']),
        isActivity: activity,
        isApproved: row['is_approved'] == true,
        startDate: tryParseDateTimeValue(
          parseStringValue(row['start_date']),
          toLocal: true,
        ),
        endDate: tryParseDateTimeValue(
          parseStringValue(row['end_date']),
          toLocal: true,
        ),
      );
  final rows = [
    ...events.map((row) => read(row, true)),
    ...attractions.map((row) => read(row, false)),
  ];
  rows.sort((left, right) {
    if (left.isApproved != right.isApproved) return left.isApproved ? 1 : -1;
    final a = left.startDate ?? left.endDate,
        b = right.startDate ?? right.endDate;
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    final upcomingA = !a.isBefore(_today), upcomingB = !b.isBefore(_today);
    if (upcomingA != upcomingB) return upcomingA ? -1 : 1;
    return upcomingA ? a.compareTo(b) : b.compareTo(a);
  });
  return rows.take(5).toList();
}

void main() {
  test('empty content produces no submissions or usage', () {
    final result = _project([]);
    expect(result.published, 0);
    expect(result.pending, 0);
    expect(result.activeEvents, 0);
    expect(result.activeAttractions, 0);
    expect(result.recentSubmissions, isEmpty);
  });
  test(
    'active counts preserve absent, empty, malformed and inclusive end rules',
    () {
      final result = _project(
        [
          {'id': 'past', 'start_date': '2026-10-28'},
          {'id': 'today', 'end_date': '2026-10-29', 'is_approved': true},
          {'id': 'empty', 'start_date': '2026-10-28', 'end_date': ''},
          {'id': 'invalid', 'start_date': '2026-10-28', 'end_date': 'invalid'},
          {'id': 'undated'},
        ],
        [
          {'id': 'place', 'end_date': '2026-10-30', 'is_approved': true},
        ],
      );
      expect(result.activeEvents, 4);
      expect(result.activeAttractions, 1);
      expect(result.published, 2);
      expect(result.pending, 4);
      expect(() => result.recentSubmissions.clear(), throwsUnsupportedError);
    },
  );
  test(
    'pending/upcoming/date ordering and five-row limit match previous service',
    () {
      final random = Random(2910);
      for (var batch = 0; batch < 100; batch++) {
        List<Map<String, dynamic>> rows(String prefix) => [
          for (var i = 0; i < 100; i++)
            {
              'id': '$prefix-$i',
              'name': '$i',
              'city': 'City',
              'is_approved': random.nextBool(),
              'start_date': random.nextBool()
                  ? DateTime(
                      2026,
                      10,
                      20 + random.nextInt(20),
                    ).toIso8601String()
                  : null,
              'end_date': random.nextBool()
                  ? DateTime(2026, 11, 1 + random.nextInt(10)).toIso8601String()
                  : null,
              'page_views': random.nextInt(20),
            },
        ];
        final events = rows('event'), attractions = rows('place');
        final result = _project(events, attractions);
        final expected = _legacyRecent(events, attractions);
        expect(
          result.recentSubmissions.map((r) => (r.id, r.isActivity)),
          expected.map((r) => (r.id, r.isActivity)),
        );
        expect(
          result.performance.totals,
          ModelContentPerformance([...events, ...attractions]).totals,
        );
      }
    },
  );
  test(
    'projection reuses original performance snapshots without changing rows',
    () {
      final events = ModelContentPerformance([
        {'id': 'a', 'page_views': 2},
      ]);
      final places = ModelContentPerformance([
        {'id': 'b', 'like_counts': 3},
      ]);
      final result = VendorContentMetrics.fromPerformance(
        events: events,
        attractions: places,
        now: _today,
      );
      expect(result.performance.items[0], same(events.items.single));
      expect(result.performance.items[1], same(places.items.single));
      expect(events.rows.single['id'], 'a');
    },
  );
}
