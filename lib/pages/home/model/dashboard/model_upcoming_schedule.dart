import 'package:life_pilot/pages/home/model/event/calendar_event.dart';

/// Projects a newly created itinerary into the existing dashboard window.
/// No account state, notification or persistence belongs in this model.
class ModelUpcomingSchedule {
  /// Null means the event is ineligible, so callers keep their current state.
  static List<CalendarEvent>? withEvent({
    required List<CalendarEvent> events,
    required CalendarEvent event,
    required DateTime now,
  }) {
    final startDate = event.startDate;
    if (startDate == null || event.isCompleted) return null;
    final today = DateTime(now.year, now.month, now.day);
    final visibleUntil = today.add(const Duration(days: 3));
    final eventDate = DateTime(startDate.year, startDate.month, startDate.day);
    if (eventDate.isBefore(today) || !eventDate.isBefore(visibleUntil)) {
      return null;
    }
    final keys = [
      for (final existing in events)
        if (existing.id != event.id) _UpcomingOrderKey(existing),
      _UpcomingOrderKey(event, startDate: startDate),
    ];
    if (!_insertIntoStrictOrder(keys)) keys.sort(_compare);
    return List<CalendarEvent>.generate(
      keys.length,
      (i) => keys[i].event,
      growable: false,
    );
  }

  static int _compare(_UpcomingOrderKey left, _UpcomingOrderKey right) {
    final leftDate = left.date, rightDate = right.date;
    // Preserve malformed existing rows instead of failing the entire local
    // projection. New events still require a date; existing undated rows sort last.
    if (leftDate == null && rightDate != null) return 1;
    if (leftDate != null && rightDate == null) return -1;
    final date = leftDate == null ? 0 : leftDate.compareTo(rightDate!);
    return date != 0 ? date : left.minutes.compareTo(right.minutes);
  }

  /// The last key is the new event. Use linear validation plus insertion only
  /// for unique sort keys; ties/unordered input retain the original full sort.
  static bool _insertIntoStrictOrder(List<_UpcomingOrderKey> keys) {
    final existingCount = keys.length - 1;
    for (var i = 1; i < existingCount; i++) {
      if (_compare(keys[i - 1], keys[i]) >= 0) return false;
    }
    final added = keys.last;
    var low = 0, high = existingCount;
    while (low < high) {
      final middle = low + ((high - low) ~/ 2);
      if (_compare(keys[middle], added) < 0) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    if (low < existingCount && _compare(keys[low], added) == 0) return false;
    keys.removeLast();
    keys.insert(low, added);
    return true;
  }
}

class _UpcomingOrderKey {
  final CalendarEvent event;
  final DateTime? date;
  final int minutes;

  _UpcomingOrderKey(this.event, {DateTime? startDate})
    : date = startDate ?? event.startDate,
      minutes = _minutes(event);

  // Untimed entries retain the dashboard's existing midnight ordering.
  static int _minutes(CalendarEvent event) {
    final time = event.startTime;
    return (time?.hour ?? 0) * 60 + (time?.minute ?? 0);
  }
}
