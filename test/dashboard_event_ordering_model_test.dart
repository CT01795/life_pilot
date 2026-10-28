import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/pages/home/model/dashboard/model_dashboard_event_ordering.dart';
import 'package:life_pilot/pages/home/model/dashboard/model_dashboard_recommendations.dart';
import 'package:life_pilot/pages/home/model/dashboard/model_dashboard_schedule_query.dart';
import 'package:life_pilot/pages/home/model/event/calendar_event.dart';
import 'package:life_pilot/pages/home/model/event/recommended_event.dart';

// Frozen previous ordering, independent of the new shared key/comparator.
int originalOrder({
  required DateTime? leftDate,
  required DateTime? rightDate,
  required int? leftMinutes,
  required int? rightMinutes,
  required String? leftCity,
  required String? rightCity,
  required String? leftLocation,
  required String? rightLocation,
  required String leftName,
  required String rightName,
}) {
  var result = (leftDate ?? DateTime(9999)).compareTo(
    rightDate ?? DateTime(9999),
  );
  if (result != 0) return result;
  result = (leftMinutes ?? 1440).compareTo(rightMinutes ?? 1440);
  if (result != 0) return result;
  result = (leftCity ?? '').compareTo(rightCity ?? '');
  if (result != 0) return result;
  result = (leftLocation ?? '').compareTo(rightLocation ?? '');
  return result != 0 ? result : leftName.compareTo(rightName);
}

void main() {
  test(
    'sort builds each key once, consumes input once, and preserves input',
    () {
      final source = List.generate(1000, (i) => 999 - i);
      final calls = <int, int>{};
      final sorted = ModelDashboardEventOrdering.sorted(
        source.map((value) {
          calls[value] = (calls[value] ?? 0) + 1;
          return value;
        }),
        keyOf: (value) {
          calls[value] = calls[value]! + 1;
          return DashboardEventOrderKey(
            date: DateTime(2026),
            minutes: value,
            city: null,
            location: null,
            name: '$value',
          );
        },
      );
      expect(calls.values, everyElement(2));
      expect(sorted, List.generate(1000, (i) => i));
      expect(source.first, 999);
      sorted.add(1000); // Previous decoding APIs return growable lists.
      expect(sorted.last, 1000);
    },
  );

  for (final schedule in [false, true]) {
    test(
      '$schedule randomized dashboard ordering matches previous implementation including ties',
      () {
        final random = Random(20261028);
        for (var batch = 0; batch < 100; batch++) {
          final rows = List<Map<String, dynamic>>.generate(
            80,
            (i) => {
              'id': '$i',
              'name': 'Name ${random.nextInt(3)}',
              'start_date': random.nextBool()
                  ? null
                  : '2026-10-${random.nextInt(3) + 10}',
              'start_time': random.nextBool()
                  ? null
                  : '0${random.nextInt(3) + 7}:00',
              'city': random.nextBool() ? null : 'City ${random.nextInt(3)}',
              'location': random.nextBool()
                  ? null
                  : 'Place ${random.nextInt(3)}',
            },
          );
          if (schedule) {
            final expected = rows.map(CalendarEvent.fromJson).toList()
              ..sort(
                (a, b) => originalOrder(
                  leftDate: a.startDate,
                  rightDate: b.startDate,
                  leftMinutes: a.startTime == null
                      ? null
                      : a.startTime!.hour * 60 + a.startTime!.minute,
                  rightMinutes: b.startTime == null
                      ? null
                      : b.startTime!.hour * 60 + b.startTime!.minute,
                  leftCity: a.city,
                  rightCity: b.city,
                  leftLocation: a.location,
                  rightLocation: b.location,
                  leftName: a.name,
                  rightName: b.name,
                ),
              );
            final actual = ModelDashboardScheduleQuery(
              DateTime(2026, 10, 28),
            ).decodeRows(rows);
            expect(
              actual.map((e) => e.id),
              expected.map((e) => e.id),
              reason: 'batch $batch',
            );
          } else {
            final expected = rows.map(RecommendedEvent.fromJson).toList()
              ..sort(
                (a, b) => originalOrder(
                  leftDate: a.startDate,
                  rightDate: b.startDate,
                  leftMinutes: a.startTime == null
                      ? null
                      : a.startTime!.hour * 60 + a.startTime!.minute,
                  rightMinutes: b.startTime == null
                      ? null
                      : b.startTime!.hour * 60 + b.startTime!.minute,
                  leftCity: a.city,
                  rightCity: b.city,
                  leftLocation: a.location,
                  rightLocation: b.location,
                  leftName: a.name,
                  rightName: b.name,
                ),
              );
            final actual = ModelDashboardRecommendations.events(rows);
            expect(
              actual.map((e) => e.id),
              expected.map((e) => e.id),
              reason: 'batch $batch',
            );
          }
          expect(rows.first['id'], '0');
        }
      },
    );
  }

  test('recommendation places retain authoritative source order', () {
    final rows = [
      {'id': 'z', 'name': 'Zulu', 'city': 'Z'},
      {'id': 'a', 'name': 'Alpha', 'city': 'A'},
    ];
    expect(ModelDashboardRecommendations.places(rows).map((e) => e.id), [
      'z',
      'a',
    ]);
  });

  test('empty and single event responses preserve decoding behavior', () {
    expect(ModelDashboardRecommendations.events([]), isEmpty);
    final query = ModelDashboardScheduleQuery(DateTime(2026, 10, 28));
    expect(query.decodeRows([]), isEmpty);
    expect(
      query
          .decodeRows([
            {'id': 'one', 'name': 'One'},
          ])
          .single
          .id,
      'one',
    );
    expect(
      ModelDashboardRecommendations.events([
        {'id': 'one', 'name': 'One'},
      ]).single.id,
      'one',
    );
  });
}
