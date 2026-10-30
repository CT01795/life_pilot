import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/pages/home/model/dashboard/model_dashboard_event_ordering.dart';
import 'package:life_pilot/pages/home/model/dashboard/model_dashboard_recommendations.dart';
import 'package:life_pilot/pages/home/model/dashboard/model_dashboard_schedule_query.dart';
import 'package:life_pilot/pages/home/model/event/calendar_event.dart';
import 'package:life_pilot/pages/home/model/event/recommended_event.dart';

class _CountingKey extends DashboardEventOrderKey {
  _CountingKey(int minutes, this.onCompare)
    : super(
        date: DateTime(2026),
        minutes: minutes,
        city: '',
        location: '',
        name: '',
      );
  final void Function() onCompare;
  @override
  int compareTo(DashboardEventOrderKey other) {
    onCompare();
    return super.compareTo(other);
  }
}

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
  test('strictly ordered dashboard rows need adjacent comparisons only', () {
    final source = List.generate(10000, (i) => i);
    var comparisons = 0, reads = 0;
    final result = ModelDashboardEventOrdering.sorted(
      source,
      keyOf: (value) {
        reads++;
        return _CountingKey(value, () => comparisons++);
      },
    );
    expect(result, orderedEquals(source));
    expect(reads, 10000);
    expect(comparisons, 9999);
    result.add(10000);
    expect(source, hasLength(10000));
  });

  test('equal dashboard keys retain the legacy full-sort path', () {
    final source = List.generate(150, (i) => i);
    var comparisons = 0, legacyComparisons = 0;
    final key = _CountingKey(0, () => legacyComparisons++);
    final expected = List.of(source)..sort((a, b) => key.compareTo(key));
    final result = ModelDashboardEventOrdering.sorted(
      source,
      keyOf: (_) => _CountingKey(0, () => comparisons++),
    );
    expect(result, expected);
    expect(comparisons, legacyComparisons + 1);
  });

  test(
    'late disorder in an otherwise sorted response still sorts all rows',
    () {
      final source = [...List.generate(100, (i) => i), -1];
      final expected = List.of(source)..sort();
      final result = ModelDashboardEventOrdering.sorted(
        source,
        keyOf: (value) => _CountingKey(value, () {}),
      );
      expect(result, expected);
      expect(source.last, -1);
    },
  );

  test(
    'fresh keys are captured on each call without a persistent row cache',
    () {
      final source = ['a', 'b'];
      final values = {'a': 1, 'b': 2};
      var reads = 0;
      DashboardEventOrderKey keyOf(String id) {
        reads++;
        return _CountingKey(values[id]!, () {});
      }

      expect(ModelDashboardEventOrdering.sorted(source, keyOf: keyOf), [
        'a',
        'b',
      ]);
      values['a'] = 3;
      expect(ModelDashboardEventOrdering.sorted(source, keyOf: keyOf), [
        'b',
        'a',
      ]);
      expect(reads, 4);
      expect(source, ['a', 'b']);
    },
  );

  test(
    'ordering preserves duplicate row identity rather than deduplicating',
    () {
      final row = Object();
      final result = ModelDashboardEventOrdering.sorted([
        row,
        row,
      ], keyOf: (_) => _CountingKey(0, () {}));
      expect(result, hasLength(2));
      expect(result.first, same(row));
      expect(result.last, same(row));
    },
  );

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
