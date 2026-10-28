import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/event/model_event_date_range.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/utils/date_time.dart';

class _TrackedEvent extends EventItem {
  _TrackedEvent() : super(id: 'tracked', name: 'tracked');
  int endReads = 0;
  @override
  DateTime? get endDate {
    endReads++;
    return super.endDate;
  }
}

void main() {
  test('no date bounds include undated rows without reading the end', () {
    final event = _TrackedEvent();
    expect(const ModelEventDateRange().matches(event), isTrue);
    expect(event.endReads, 0);
  });

  test('upper-only bound does not read the event end date', () {
    final event = _TrackedEvent()..startDate = DateTime(2026, 10, 28, 23);
    expect(
      ModelEventDateRange(end: DateTime(2026, 10, 28)).matches(event),
      isTrue,
    );
    expect(event.endReads, 0);
  });

  test('cross-day overlap includes both boundaries', () {
    final event = EventItem(
      id: 'cross',
      name: 'cross',
      startDate: DateTime(2026, 10, 25, 23),
      endDate: DateTime(2026, 10, 28, 1),
    );
    for (var day = 25; day <= 28; day++) {
      expect(
        ModelEventDateRange(
          start: DateTime(2026, 10, day),
          end: DateTime(2026, 10, day),
        ).matches(event),
        isTrue,
      );
    }
    expect(
      ModelEventDateRange(start: DateTime(2026, 10, 29)).matches(event),
      isFalse,
    );
    expect(
      ModelEventDateRange(end: DateTime(2026, 10, 24)).matches(event),
      isFalse,
    );
  });

  test('date edits are observed without retaining event projections', () {
    final range = ModelEventDateRange(start: DateTime(2026, 10, 28));
    final event = EventItem(
      id: 'edit',
      name: 'edit',
      startDate: DateTime(2026, 10, 27),
    );
    expect(range.matches(event), isFalse);
    event.endDate = DateTime(2026, 10, 29);
    expect(range.matches(event), isTrue);
  });

  test('randomized bounds preserve the original calendar-day policy', () {
    final random = Random(28);
    DateTime? date() {
      if (random.nextInt(5) == 0) return null;
      final day = random.nextInt(60);
      final hour = random.nextInt(24);
      return random.nextBool()
          ? DateTime(2026, 10, day, hour)
          : DateTime.utc(2026, 10, day, hour);
    }

    for (var i = 0; i < 5000; i++) {
      final event = EventItem(
        id: '$i',
        name: '',
        startDate: date(),
        endDate: date(),
      );
      final start = date(), end = date();
      bool original() {
        if (start == null && end == null) return true;
        final rawStart = event.startDate;
        if (rawStart == null) return false;
        final startDay = DateTimeFormatter.dateOnly(rawStart);
        final endDay = DateTimeFormatter.dateOnly(event.endDate ?? rawStart);
        return (start == null || !endDay.isBefore(start)) &&
            (end == null || !startDay.isAfter(end));
      }

      expect(
        ModelEventDateRange(start: start, end: end).matches(event),
        original(),
        reason: 'case $i',
      );
    }
  });
}
