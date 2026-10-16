import 'package:life_pilot/pages/home/model/event/calendar_event.dart';

typedef _ScheduleInterval = ({DateTime start, DateTime end});
typedef _ScheduledEvent = ({
  CalendarEvent event,
  DateTime start,
  _ScheduleInterval? interval,
});

/// Home schedule analysis only; presentation and persistence stay outside.
class ModelScheduleOverview {
  const ModelScheduleOverview({
    required this.todayCount,
    required this.tomorrowCount,
    required this.overdueCount,
    required this.todayConflictCount,
    required this.tomorrowConflictCount,
    required this.nextEvent,
    required this.nextEventNeedsReview,
    required this.nextFreeAt,
  });

  factory ModelScheduleOverview.from(List<CalendarEvent> events, DateTime now) {
    final minuteKey = now.millisecondsSinceEpoch ~/ 60000;
    final cached = _cache[events];
    if (cached != null &&
        cached.matches(events, minuteKey, now.timeZoneOffset)) {
      return cached.overview;
    }
    final overview = ModelScheduleOverview._build(events, now);
    _cache[events] = _ScheduleOverviewCache(
      minuteKey: minuteKey,
      offset: now.timeZoneOffset,
      events: List<CalendarEvent>.of(events, growable: false),
      overview: overview,
    );
    return overview;
  }

  factory ModelScheduleOverview._build(
    List<CalendarEvent> events,
    DateTime now,
  ) {
    final today = _dateOnly(now);
    final tomorrow = today.add(const Duration(days: 1));
    final todayEvents = <_ScheduledEvent>[];
    final tomorrowEvents = <_ScheduledEvent>[];
    for (final event in events) {
      final date = event.startDate;
      if (event.isCompleted || date == null) continue;
      final target = _sameDay(date, today)
          ? todayEvents
          : _sameDay(date, tomorrow)
          ? tomorrowEvents
          : null;
      if (target == null) continue;
      target.add((
        event: event,
        start: _eventStart(event),
        interval: _interval(event),
      ));
    }
    todayEvents.sort((a, b) => a.start.compareTo(b.start));
    tomorrowEvents.sort((a, b) => a.start.compareTo(b.start));
    final next = todayEvents.firstOrNull;
    return ModelScheduleOverview(
      todayCount: todayEvents.length,
      tomorrowCount: tomorrowEvents.length,
      overdueCount: todayEvents.where((event) => _hasEnded(event, now)).length,
      todayConflictCount: _countConflicts(todayEvents),
      tomorrowConflictCount: _countConflicts(tomorrowEvents),
      nextEvent: next?.event,
      nextEventNeedsReview: next != null && _hasEnded(next, now),
      nextFreeAt: _findNextFreeHour(todayEvents, now),
    );
  }

  static final Expando<_ScheduleOverviewCache> _cache =
      Expando<_ScheduleOverviewCache>('scheduleOverview');

  final int todayCount;
  final int tomorrowCount;
  final int overdueCount;
  final int todayConflictCount;
  final int tomorrowConflictCount;
  final CalendarEvent? nextEvent;
  final bool nextEventNeedsReview;
  final DateTime? nextFreeAt;

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static DateTime? _findNextFreeHour(
    List<_ScheduledEvent> events,
    DateTime now,
  ) {
    final today = _dateOnly(now);
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
    // Entries are already sorted, and each interval is calculated once.
    for (final event in events) {
      final interval = event.interval;
      if (interval == null || !interval.end.isAfter(cursor)) continue;
      if (interval.start.difference(cursor) >= const Duration(hours: 1)) {
        return cursor;
      }
      if (interval.end.isAfter(cursor)) cursor = interval.end;
    }
    return dayEnd.difference(cursor) >= const Duration(hours: 1)
        ? cursor
        : null;
  }

  static int _countConflicts(List<_ScheduledEvent> events) {
    final intervals = events
        .map((event) => event.interval)
        .whereType<_ScheduleInterval>();
    final affected = <int>{};
    DateTime? furthestEnd;
    var furthestEndIndex = 0;
    var index = 0;
    for (final interval in intervals) {
      final end = furthestEnd;
      if (end != null && interval.start.isBefore(end)) {
        affected
          ..add(furthestEndIndex)
          ..add(index);
      }
      if (end == null ||
          !interval.start.isBefore(end) ||
          interval.end.isAfter(end)) {
        furthestEnd = interval.end;
        furthestEndIndex = index;
      }
      index++;
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

  static bool _hasEnded(_ScheduledEvent event, DateTime now) {
    final interval = event.interval;
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
        : _dateOnly(endDate).isAfter(_dateOnly(startDate))
        ? _dateOnly(endDate).add(const Duration(days: 1))
        : start.add(const Duration(hours: 1));
    return end.isAfter(start) ? (start: start, end: end) : null;
  }
}

class _ScheduleOverviewCache {
  const _ScheduleOverviewCache({
    required this.minuteKey,
    required this.offset,
    required this.events,
    required this.overview,
  });
  final int minuteKey;
  final Duration offset;
  final List<CalendarEvent> events;
  final ModelScheduleOverview overview;

  bool matches(
    List<CalendarEvent> current,
    int minute,
    Duration currentOffset,
  ) {
    if (minute != minuteKey ||
        currentOffset != offset ||
        current.length != events.length) {
      return false;
    }
    // CalendarEvent is immutable; identity detects replacements and reordering.
    for (var i = 0; i < current.length; i++) {
      if (!identical(current[i], events[i])) return false;
    }
    return true;
  }
}
