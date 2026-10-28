import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/utils/date_time.dart';

/// Calendar-day overlap policy, independent of widgets, storage and search text.
/// One instance is scoped to one filtering pass, not retained across edits.
class ModelEventDateRange {
  const ModelEventDateRange({this.start, this.end});

  final DateTime? start;
  final DateTime? end;

  bool matches(EventBase event) {
    if (start == null && end == null) return true;
    final rawStart = event.startDate;
    if (rawStart == null) return false;

    // Check the lower bound first; rejected rows need no start-day allocation.
    DateTime? startDay;
    if (start != null) {
      final rawEnd = event.endDate;
      final endDay = rawEnd == null || rawEnd == rawStart
          ? (startDay = DateTimeFormatter.dateOnly(rawStart))
          : DateTimeFormatter.dateOnly(rawEnd);
      if (endDay.isBefore(start!)) return false;
    }
    if (end == null) return true;
    startDay ??= DateTimeFormatter.dateOnly(rawStart);
    return !startDay.isAfter(end!);
  }
}
