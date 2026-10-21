import 'package:life_pilot/event/model_event_item.dart';

/// Per-sort keys only: EventItem remains mutable, so never cache these across
/// reloads or edits. Return a private list without changing storage snapshots.
class ModelCalendarEventOrdering {
  static final _undated = DateTime(9999);

  static List<EventItem> ordered(Iterable<EventItem> events) {
    final source = events.toList();
    if (source.length < 2) return source;
    final keys = [for (final event in source) _CalendarOrderKey(event)];
    keys.sort((left, right) {
      var comparison = (left.date ?? _undated).compareTo(
        right.date ?? _undated,
      );
      if (comparison != 0) return comparison;
      comparison = left.time.compareTo(right.time);
      if (comparison != 0) return comparison;
      comparison = left.city.compareTo(right.city);
      if (comparison != 0) return comparison;
      comparison = left.location.compareTo(right.location);
      return comparison != 0 ? comparison : left.name.compareTo(right.name);
    });
    for (var i = 0; i < keys.length; i++) {
      source[i] = keys[i].event;
    }
    return source;
  }
}

class _CalendarOrderKey {
  final EventItem event;
  final DateTime? date;
  final int time;
  final String city;
  final String location;
  final String name;

  _CalendarOrderKey(this.event)
    : date = event.startDate,
      time = _minutes(event),
      city = event.city,
      location = event.location,
      name = event.name;

  static int _minutes(EventItem event) {
    final time = event.startTime;
    return time == null ? 24 * 60 : time.hour * 60 + time.minute;
  }
}
