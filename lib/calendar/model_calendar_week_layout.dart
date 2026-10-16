import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/utils/date_time.dart';

typedef _EventRange = ({EventItem event, DateTime start, DateTime end});

/// Layout derived from one month's event snapshot. Event writes must invalidate
/// the month in ModelCalendar; loading/weather notifications can reuse it.
class ModelCalendarWeekLayout {
  ModelCalendarWeekLayout(this.source)
    : _ranges = [
        for (final event in source)
          (
            event: event,
            start: DateTimeFormatter.dateOnly(event.startDate!),
            end: DateTimeFormatter.dateOnly(event.endDate ?? event.startDate!),
          ),
      ];

  final List<EventItem> source;
  final List<_EventRange> _ranges;
  final Map<(DateTime, DateTime), List<EventWithRow>> _weeks = {};

  List<EventWithRow> forWeek(DateTime start, DateTime end) =>
      _weeks.putIfAbsent((start, end), () => _build(start, end));

  List<EventWithRow> _build(DateTime start, DateTime end) {
    final rows = <List<_EventRange>>[];
    for (final range in _ranges) {
      if (range.end.isBefore(start) || range.start.isAfter(end)) continue;
      final available = rows.indexWhere(
        (row) => !row.any(
          (other) =>
              !(range.end.isBefore(other.start) ||
                  range.start.isAfter(other.end)),
        ),
      );
      if (available >= 0) {
        rows[available].add(range);
      } else {
        rows.add([range]);
      }
    }
    return List<EventWithRow>.unmodifiable([
      for (var index = 0; index < rows.length; index++)
        for (final range in rows[index])
          EventWithRow(event: range.event, rowIndex: index),
    ]);
  }
}
