import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/pages/home/model/dashboard/model_schedule_overview.dart';
import 'package:life_pilot/pages/home/model/event/calendar_event.dart';

final day = DateTime(2026, 10, 15);

class _ObservedEvent extends CalendarEvent {
  _ObservedEvent()
    : super(
        id: 'observed',
        name: 'observed',
        startDate: day,
        startTime: const TimeOfDay(hour: 8, minute: 0),
        endTime: const TimeOfDay(hour: 9, minute: 0),
      );
  int timeReads = 0;
  @override
  TimeOfDay? get startTime {
    timeReads++;
    return super.startTime;
  }
}

CalendarEvent event(
  String id, {
  int offset = 0,
  int? start = 9,
  int? end = 10,
  int? endOffset,
  bool completed = false,
}) => CalendarEvent(
  id: id,
  name: id,
  startDate: day.add(Duration(days: offset)),
  startTime: start == null
      ? null
      : TimeOfDay(hour: start ~/ 60, minute: start % 60),
  endDate: endOffset == null ? null : day.add(Duration(days: endOffset)),
  endTime: end == null ? null : TimeOfDay(hour: end ~/ 60, minute: end % 60),
  isCompleted: completed,
);

void compareLegacy(List<CalendarEvent> events, DateTime now) {
  final actual = ModelScheduleOverview.from(events, now);
  final expected = _LegacyOverview.from(events, now);
  expect(actual.todayCount, expected.todayCount);
  expect(actual.tomorrowCount, expected.tomorrowCount);
  expect(actual.overdueCount, expected.overdueCount);
  expect(actual.todayConflictCount, expected.todayConflictCount);
  expect(actual.tomorrowConflictCount, expected.tomorrowConflictCount);
  expect(actual.nextEvent?.id, expected.nextEvent?.id);
  expect(actual.nextEventNeedsReview, expected.nextEventNeedsReview);
  expect(actual.nextFreeAt, expected.nextFreeAt);
}

void main() {
  test(
    'conflict counts persist while overdue state changes across minutes',
    () {
      final events = [
        event('first', start: 480, end: 540),
        event('overlap', start: 510, end: 570),
        event('tomorrow1', offset: 1, start: 600, end: 660),
        event('tomorrow2', offset: 1, start: 630, end: 690),
      ];
      final before = ModelScheduleOverview.from(
        events,
        DateTime(2026, 10, 15, 8),
      );
      final after = ModelScheduleOverview.from(
        events,
        DateTime(2026, 10, 15, 10),
      );
      expect(before.overdueCount, 0);
      expect(after.overdueCount, 2);
      expect(after.todayConflictCount, 2);
      expect(after.tomorrowConflictCount, 2);
      compareLegacy(events, DateTime(2026, 10, 15, 10, 1));
    },
  );
  test('marking one overlapping event complete refreshes cached counts', () {
    final events = [
      event('first', start: 480, end: 600),
      event('second', start: 540, end: 660),
    ];
    expect(ModelScheduleOverview.from(events, day).todayConflictCount, 2);
    events[1] = event('second', start: 540, end: 660, completed: true);
    expect(ModelScheduleOverview.from(events, day).todayConflictCount, 0);
  });
  test('midnight shifts cached tomorrow conflicts to today', () {
    final events = [
      event('today1', start: 480, end: 600),
      event('today2', start: 540, end: 660),
      event('tomorrow1', offset: 1, start: 600, end: 660),
      event('tomorrow2', offset: 1, start: 630, end: 690),
      event('tomorrow3', offset: 1, start: 640, end: 700),
    ];
    final before = ModelScheduleOverview.from(
      events,
      DateTime(2026, 10, 15, 23, 59),
    );
    expect(before.todayConflictCount, 2);
    expect(before.tomorrowConflictCount, 3);
    final after = ModelScheduleOverview.from(events, DateTime(2026, 10, 16));
    expect(after.todayConflictCount, 3);
    expect(after.tomorrowConflictCount, 0);
  });
  test(
    'new minutes reuse prepared intervals but refresh time-based results',
    () {
      final observed = _ObservedEvent();
      final events = [observed];
      final first = ModelScheduleOverview.from(
        events,
        DateTime(2026, 10, 15, 8, 59),
      );
      final reads = observed.timeReads;
      expect(first.overdueCount, 0);
      expect(reads, greaterThan(0));
      final next = ModelScheduleOverview.from(
        events,
        DateTime(2026, 10, 15, 9),
      );
      expect(next, isNot(same(first)));
      expect(next.overdueCount, 1);
      expect(next.nextEventNeedsReview, isTrue);
      expect(next.nextFreeAt, DateTime(2026, 10, 15, 9));
      expect(observed.timeReads, reads);
    },
  );
  test('midnight rebuilds today and tomorrow membership', () {
    final events = [event('today'), event('tomorrow', offset: 1)];
    ModelScheduleOverview.from(events, DateTime(2026, 10, 15, 23, 59));
    compareLegacy(events, DateTime(2026, 10, 16));
    expect(
      ModelScheduleOverview.from(events, DateTime(2026, 10, 16)).nextEvent?.id,
      'tomorrow',
    );
  });
  test('changed membership between minutes cannot reuse old intervals', () {
    final events = [event('old', start: 480, end: 540)];
    ModelScheduleOverview.from(events, DateTime(2026, 10, 15, 8));
    events[0] = event('replacement', start: 600, end: 660);
    compareLegacy(events, DateTime(2026, 10, 15, 8, 1));
    events.add(event('added', start: 540, end: 660));
    compareLegacy(events, DateTime(2026, 10, 15, 8, 2));
    events.clear();
    compareLegacy(events, DateTime(2026, 10, 15, 8, 3));
  });
  test('reused schedules match original rules across a whole day', () {
    final events = [
      event('early', start: 480, end: 540),
      event('long', start: 600, end: 900),
      event('nested', start: 660, end: 720),
      event('done', start: 480, end: 1320, completed: true),
      event('tomorrow', offset: 1, start: 600, end: 660),
    ];
    for (var minute = 0; minute < 1440; minute += 7) {
      compareLegacy(events, day.add(Duration(minutes: minute)));
    }
  });
  test('empty schedule starts free hour at eight', () {
    final result = ModelScheduleOverview.from([], DateTime(2026, 10, 15, 7));
    expect(result.todayCount, 0);
    expect(result.nextEvent, null);
    expect(result.nextFreeAt, DateTime(2026, 10, 15, 8));
  });
  test('completed and missing dates do not affect the overview', () {
    final result = ModelScheduleOverview.from([
      event('done', completed: true, start: 540, end: 660),
      CalendarEvent(id: 'missing', name: 'missing'),
    ], DateTime(2026, 10, 15, 9));
    expect(result.todayCount, 0);
    expect(result.todayConflictCount, 0);
    expect(result.overdueCount, 0);
  });
  test('counts only today and tomorrow start dates', () {
    final result = ModelScheduleOverview.from([
      event('yesterday', offset: -1),
      event('today'),
      event('tomorrow', offset: 1),
      event('later', offset: 2),
    ], day);
    expect(result.todayCount, 1);
    expect(result.tomorrowCount, 1);
    expect(result.nextEvent?.id, 'today');
  });
  test('earliest ended unfinished event remains next and needs review', () {
    final result = ModelScheduleOverview.from([
      event('later', start: 660, end: 720),
      event('earlier', start: 480, end: 540),
    ], DateTime(2026, 10, 15, 10));
    expect(result.nextEvent?.id, 'earlier');
    expect(result.nextEventNeedsReview, true);
    expect(result.overdueCount, 1);
  });
  test('counts affected events not pairs and separates tomorrow conflicts', () {
    final result = ModelScheduleOverview.from([
      event('outer', start: 480, end: 720),
      event('nested', start: 540, end: 600),
      event('nested2', start: 600, end: 660),
      event('touch', start: 720, end: 780),
      event('tomorrow1', offset: 1, start: 480, end: 600),
      event('tomorrow2', offset: 1, start: 540, end: 660),
      event('done', completed: true, start: 480, end: 800),
    ], day);
    expect(result.todayConflictCount, 3);
    expect(result.tomorrowConflictCount, 2);
  });
  test('missing start time still counts but cannot conflict or be overdue', () {
    final result = ModelScheduleOverview.from([
      event('untimed', start: null, end: null),
      event('timed', start: 540, end: 600),
    ], DateTime(2026, 10, 15, 11));
    expect(result.todayCount, 2);
    expect(result.nextEvent?.id, 'untimed');
    expect(result.nextEventNeedsReview, false);
    expect(result.overdueCount, 1);
    expect(result.todayConflictCount, 0);
  });
  test('missing end time uses one hour on same day', () {
    final result = ModelScheduleOverview.from([
      event('onehour', start: 540, end: null),
    ], DateTime(2026, 10, 15, 10));
    expect(result.overdueCount, 1);
    expect(result.nextFreeAt, DateTime(2026, 10, 15, 10));
  });
  test('multi-day missing end time ends after the final day', () {
    final result = ModelScheduleOverview.from([
      event('trip', start: 480, end: null, endOffset: 1),
    ], DateTime(2026, 10, 15, 9));
    expect(result.overdueCount, 0);
    expect(result.nextFreeAt, null);
  });
  test('invalid interval does not create conflicts or overdue counts', () {
    final result = ModelScheduleOverview.from([
      event('invalid', start: 600, end: 540),
    ], DateTime(2026, 10, 15, 11));
    expect(result.overdueCount, 0);
    expect(result.todayConflictCount, 0);
    expect(result.nextFreeAt, DateTime(2026, 10, 15, 11));
  });
  test('free hour rounds cursor to next quarter hour', () {
    expect(
      ModelScheduleOverview.from([], DateTime(2026, 10, 15, 8, 7)).nextFreeAt,
      DateTime(2026, 10, 15, 8, 15),
    );
  });
  test('free hour stops at twenty-two', () {
    expect(
      ModelScheduleOverview.from([], DateTime(2026, 10, 15, 22)).nextFreeAt,
      null,
    );
    expect(
      ModelScheduleOverview.from([], DateTime(2026, 10, 15, 21, 15)).nextFreeAt,
      null,
    );
  });
  test('exact one-hour gap is available', () {
    expect(
      ModelScheduleOverview.from([
        event('later', start: 540, end: 600),
      ], DateTime(2026, 10, 15, 8)).nextFreeAt,
      DateTime(2026, 10, 15, 8),
    );
  });
  test('nested occupied intervals do not shorten blocked time', () {
    expect(
      ModelScheduleOverview.from([
        event('outer', start: 480, end: 660),
        event('inner', start: 540, end: 600),
      ], DateTime(2026, 10, 15, 8)).nextFreeAt,
      DateTime(2026, 10, 15, 11),
    );
  });
  test('same list and minute reuse analysis', () {
    final events = [event('a')];
    final first = ModelScheduleOverview.from(events, day);
    expect(
      ModelScheduleOverview.from(events, day.add(const Duration(seconds: 10))),
      same(first),
    );
  });
  test('same-length replacement invalidates cache in same minute', () {
    final events = [event('a', start: 540, end: 600)];
    final first = ModelScheduleOverview.from(events, day);
    events[0] = event('done', completed: true);
    final second = ModelScheduleOverview.from(events, day);
    expect(second, isNot(same(first)));
    expect(second.todayCount, 0);
    expect(second.nextEvent, null);
  });
  test('same list reordering invalidates cached next event', () {
    final events = [event('a'), event('b')];
    expect(ModelScheduleOverview.from(events, day).nextEvent?.id, 'a');
    events.setAll(0, [events[1], events[0]]);
    expect(ModelScheduleOverview.from(events, day).nextEvent?.id, 'b');
  });
  test('minute changes refresh overdue status', () {
    final events = [event('a', start: 480, end: 540)];
    expect(
      ModelScheduleOverview.from(
        events,
        DateTime(2026, 10, 15, 8, 59),
      ).overdueCount,
      0,
    );
    expect(
      ModelScheduleOverview.from(
        events,
        DateTime(2026, 10, 15, 9),
      ).overdueCount,
      1,
    );
  });
  test('randomized schedule analysis matches original rules', () {
    final random = Random(42);
    for (var sample = 0; sample < 200; sample++) {
      final events = List.generate(30, (index) {
        final start = index * 41;
        return event(
          '$index',
          offset: random.nextInt(5) - 1,
          start: start,
          end: random.nextBool() ? null : (start + random.nextInt(200)) % 1440,
          endOffset: random.nextBool() ? null : random.nextInt(4),
          completed: random.nextInt(4) == 0,
        );
      })..shuffle(random);
      compareLegacy(
        events,
        DateTime(2026, 10, 15, random.nextInt(24), random.nextInt(60)),
      );
    }
  });
}

// Frozen original widget analysis for behavior-preservation checks.
class _LegacyOverview {
  const _LegacyOverview({
    required this.todayCount,
    required this.tomorrowCount,
    required this.overdueCount,
    required this.todayConflictCount,
    required this.tomorrowConflictCount,
    required this.nextEvent,
    required this.nextEventNeedsReview,
    required this.nextFreeAt,
  });

  factory _LegacyOverview.from(List<CalendarEvent> events, DateTime now) {
    final minuteKey = now.millisecondsSinceEpoch ~/ 60000;
    final cached = _cache[events];
    if (cached != null &&
        cached.minuteKey == minuteKey &&
        cached.eventCount == events.length) {
      return cached.overview;
    }

    final overview = _LegacyOverview._build(events, now);
    _cache[events] = _LegacyOverviewCache(
      minuteKey: minuteKey,
      eventCount: events.length,
      overview: overview,
    );
    return overview;
  }

  factory _LegacyOverview._build(List<CalendarEvent> events, DateTime now) {
    final today = DateUtils.dateOnly(now);
    final tomorrow = today.add(const Duration(days: 1));
    final activeEvents =
        events
            .where((event) => !event.isCompleted && event.startDate != null)
            .toList(growable: false)
          ..sort((a, b) => _eventStart(a).compareTo(_eventStart(b)));
    final todayEvents = activeEvents
        .where((event) => DateUtils.isSameDay(event.startDate, today))
        .toList(growable: false);
    final tomorrowEvents = activeEvents
        .where((event) => DateUtils.isSameDay(event.startDate, tomorrow))
        .toList(growable: false);
    final overdueCount = todayEvents
        .where((event) => _hasEnded(event, now))
        .length;
    final nextEvent = todayEvents.firstOrNull;

    return _LegacyOverview(
      todayCount: todayEvents.length,
      tomorrowCount: tomorrowEvents.length,
      overdueCount: overdueCount,
      todayConflictCount: _countConflicts(todayEvents),
      tomorrowConflictCount: _countConflicts(tomorrowEvents),
      nextEvent: nextEvent,
      nextEventNeedsReview: nextEvent != null && _hasEnded(nextEvent, now),
      nextFreeAt: _findNextFreeHour(todayEvents, now),
    );
  }

  static final Expando<_LegacyOverviewCache> _cache =
      Expando<_LegacyOverviewCache>('scheduleOverview');

  final int todayCount;
  final int tomorrowCount;
  final int overdueCount;
  final int todayConflictCount;
  final int tomorrowConflictCount;
  final CalendarEvent? nextEvent;
  final bool nextEventNeedsReview;
  final DateTime? nextFreeAt;

  static DateTime? _findNextFreeHour(List<CalendarEvent> events, DateTime now) {
    final today = DateUtils.dateOnly(now);
    final dayStart = DateTime(today.year, today.month, today.day, 8);
    final dayEnd = DateTime(today.year, today.month, today.day, 22);
    if (!now.isBefore(dayEnd)) return null;
    var cursor = now.isAfter(dayStart) ? now : dayStart;
    if (cursor.minute % 15 != 0 || cursor.second != 0) {
      cursor = DateTime(
        cursor.year,
        cursor.month,
        cursor.day,
        cursor.hour,
        ((cursor.minute ~/ 15) + 1) * 15,
      );
    }
    final intervals =
        events
            .map(_interval)
            .whereType<({DateTime start, DateTime end})>()
            .toList(growable: false)
          ..sort((a, b) => a.start.compareTo(b.start));
    for (final interval in intervals) {
      if (!interval.end.isAfter(cursor)) continue;
      if (interval.start.difference(cursor) >= const Duration(hours: 1)) {
        return cursor;
      }
      if (interval.end.isAfter(cursor)) cursor = interval.end;
    }
    return dayEnd.difference(cursor) >= const Duration(hours: 1)
        ? cursor
        : null;
  }

  static int _countConflicts(List<CalendarEvent> events) {
    final intervals = events
        .map(_interval)
        .whereType<({DateTime start, DateTime end})>()
        .toList(growable: false);
    intervals.sort((a, b) => a.start.compareTo(b.start));
    if (intervals.length < 2) return 0;
    final affected = <int>{};
    var furthestEnd = intervals.first.end;
    var furthestEndIndex = 0;
    for (var i = 1; i < intervals.length; i++) {
      final interval = intervals[i];
      if (interval.start.isBefore(furthestEnd)) {
        affected
          ..add(furthestEndIndex)
          ..add(i);
      } else {
        furthestEnd = interval.end;
        furthestEndIndex = i;
        continue;
      }
      if (interval.end.isAfter(furthestEnd)) {
        furthestEnd = interval.end;
        furthestEndIndex = i;
      }
    }
    return affected.length;
  }

  static DateTime _eventStart(CalendarEvent event) {
    final date = event.startDate!;
    final time = event.startTime;
    return DateTime(
      date.year,
      date.month,
      date.day,
      time?.hour ?? 0,
      time?.minute ?? 0,
    );
  }

  static bool _hasEnded(CalendarEvent event, DateTime now) {
    final interval = _interval(event);
    return interval != null && !interval.end.isAfter(now);
  }

  static ({DateTime start, DateTime end})? _interval(CalendarEvent event) {
    final startDate = event.startDate;
    final startTime = event.startTime;
    if (startDate == null || startTime == null) return null;
    final endDate = event.endDate ?? startDate;
    final start = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
      startTime.hour,
      startTime.minute,
    );
    final endTime = event.endTime;
    final end = endTime != null
        ? DateTime(
            endDate.year,
            endDate.month,
            endDate.day,
            endTime.hour,
            endTime.minute,
          )
        : DateUtils.dateOnly(endDate).isAfter(DateUtils.dateOnly(startDate))
        ? DateUtils.dateOnly(endDate).add(const Duration(days: 1))
        : start.add(const Duration(hours: 1));
    return end.isAfter(start) ? (start: start, end: end) : null;
  }
}

class _LegacyOverviewCache {
  const _LegacyOverviewCache({
    required this.minuteKey,
    required this.eventCount,
    required this.overview,
  });

  final int minuteKey;
  final int eventCount;
  final _LegacyOverview overview;
}
