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
      _UpcomingOrderKey(event),
    ];
    keys.sort((left, right) {
      final date = left.date.compareTo(right.date);
      return date != 0 ? date : left.minutes.compareTo(right.minutes);
    });
    return List<CalendarEvent>.generate(
      keys.length,
      (i) => keys[i].event,
      growable: false,
    );
  }
}

class _UpcomingOrderKey {
  final CalendarEvent event;
  final DateTime date;
  final int minutes;

  _UpcomingOrderKey(this.event)
    : date = event.startDate!,
      minutes = _minutes(event);

  // Untimed entries retain the dashboard's existing midnight ordering.
  static int _minutes(CalendarEvent event) {
    final time = event.startTime;
    return (time?.hour ?? 0) * 60 + (time?.minute ?? 0);
  }
}
