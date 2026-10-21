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
  late final bool _canUseRowTail = _hasChronologicalRanges();
  late final List<DateTime> _latestEnds = _buildLatestEnds();

  List<DateTime> _buildLatestEnds() {
    final ends = <DateTime>[];
    DateTime? latest;
    for (final range in _ranges) {
      latest = latest == null || range.end.isAfter(latest) ? range.end : latest;
      ends.add(latest);
    }
    return ends;
  }

  // Prefix maxima retain early-starting, long-running events. Searching only
  // start dates would incorrectly omit those events from later weeks.
  int _firstPossibleOverlap(DateTime start) {
    var low = 0;
    var high = _ranges.length;
    while (low < high) {
      final middle = low + (high - low) ~/ 2;
      if (_latestEnds[middle].isBefore(start)) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    return low;
  }

  int _afterLastPossibleOverlap(DateTime end) {
    var low = 0;
    var high = _ranges.length;
    while (low < high) {
      final middle = low + (high - low) ~/ 2;
      if (_ranges[middle].start.isAfter(end)) {
        high = middle;
      } else {
        low = middle + 1;
      }
    }
    return low;
  }

  bool _hasChronologicalRanges() {
    DateTime? previous;
    for (final range in _ranges) {
      if (range.end.isBefore(range.start) ||
          (previous != null && range.start.isBefore(previous))) {
        return false;
      }
      previous = range.start;
    }
    return true;
  }

  List<EventWithRow> forWeek(DateTime start, DateTime end) =>
      _weeks.putIfAbsent((start, end), () => _build(start, end));

  List<EventWithRow> _build(DateTime start, DateTime end) {
    final rows = <List<_EventRange>>[];
    final useRowTail = _canUseRowTail;
    final first = useRowTail ? _firstPossibleOverlap(start) : 0;
    final afterLast = useRowTail
        ? _afterLastPossibleOverlap(end)
        : _ranges.length;
    for (var index = first; index < afterLast; index++) {
      final range = _ranges[index];
      if (range.end.isBefore(start) || range.start.isAfter(end)) continue;
      final available = rows.indexWhere(
        // Ordered valid ranges placed in a row cannot overlap. Its last range
        // therefore has the latest end; keep the original first-free-row rule.
        // Unordered or reversed ranges retain the previous full overlap check.
        (row) => useRowTail
            ? row.last.end.isBefore(range.start)
            : !row.any(
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
