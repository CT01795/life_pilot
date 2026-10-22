import 'package:life_pilot/event/model_event_item.dart';

/// Sorting policy only: no UI, storage, or network side effects.
/// Keys are scoped to one sort because EventItem remains mutable.
class ModelEventOrdering {
  static void sortRecommended(
    List<EventItem> events, {
    required bool isEvent,
    DateTime? now,
  }) {
    if (events.length < 2) return;
    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);
    final keys = <_EventOrderKey>[];
    for (var i = 0; i < events.length; i++) {
      final event = events[i];
      DateTime? effectiveDate;
      var end = 0;
      if (isEvent) {
        final start = event.startDate ?? today;
        final date = DateTime(start.year, start.month, start.day);
        effectiveDate = date.isBefore(today) ? today : date;
        end =
            (event.endDate ?? event.startDate)?.millisecondsSinceEpoch ??
            8640000000000000;
      }
      keys.add(
        _EventOrderKey(
          event,
          i,
          preference: event.isLike == true
              ? 0
              : event.isDislike == true
              ? 2
              : 1,
          date: effectiveDate,
          end: end,
        ),
      );
    }
    _sortIfNeeded(events, keys, (left, right) {
      var comparison = left.preference.compareTo(right.preference);
      if (comparison != 0) return comparison;
      if (isEvent) {
        comparison = left.date!.compareTo(right.date!);
        if (comparison != 0) return comparison;
        comparison = left.time.compareTo(right.time);
        if (comparison != 0) return comparison;
        comparison = left.end.compareTo(right.end);
        if (comparison != 0) return comparison;
        comparison = left.country.compareTo(right.country);
        if (comparison != 0) return comparison;
      }
      return _comparePlace(left, right);
    });
  }

  static void sortMemory(List<EventItem> events) {
    if (events.length < 2) return;
    final keys = <_EventOrderKey>[
      for (var i = 0; i < events.length; i++)
        _EventOrderKey(
          events[i],
          i,
          date: events[i].startDate ?? DateTime.fromMillisecondsSinceEpoch(0),
        ),
    ];
    _sortIfNeeded(events, keys, (left, right) {
      var comparison = right.date!.compareTo(left.date!);
      if (comparison != 0) return comparison;
      comparison = right.time.compareTo(left.time);
      return comparison != 0 ? comparison : _comparePlace(left, right);
    });
  }

  static int _comparePlace(_EventOrderKey left, _EventOrderKey right) {
    var comparison = left.city.compareTo(right.city);
    if (comparison != 0) return comparison;
    comparison = left.location.compareTo(right.location);
    if (comparison != 0) return comparison;
    comparison = left.name.compareTo(right.name);
    return comparison != 0 ? comparison : left.index.compareTo(right.index);
  }

  static void _sortIfNeeded(
    List<EventItem> events,
    List<_EventOrderKey> keys,
    int Function(_EventOrderKey, _EventOrderKey) compare,
  ) {
    // Keys are fresh for this call: edits and effective dates still participate.
    // Already ordered progressive batches need neither a sort nor list writes.
    var needsSort = false;
    for (var i = 1; i < keys.length; i++) {
      if (compare(keys[i - 1], keys[i]) <= 0) continue;
      needsSort = true;
      break;
    }
    if (!needsSort) return;
    keys.sort(compare);
    for (var i = 0; i < keys.length; i++) {
      events[i] = keys[i].event;
    }
  }
}

class _EventOrderKey {
  final EventItem event;
  final int index;
  final int preference;
  final DateTime? date;
  final int end;
  final int time;
  final String country;
  final String city;
  final String location;
  final String name;

  _EventOrderKey(
    this.event,
    this.index, {
    this.preference = 0,
    this.date,
    this.end = 0,
  }) : time = event.startTime == null
           ? 24 * 60
           : event.startTime!.hour * 60 + event.startTime!.minute,
       country = event.country,
       city = event.city,
       location = event.location,
       name = event.name;
}
