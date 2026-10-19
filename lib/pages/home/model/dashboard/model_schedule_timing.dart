import 'package:life_pilot/pages/home/model/event/calendar_event.dart';

enum ScheduleTimingKind { needsReview, alreadyStarted, minutes, hours }

/// Time classification only. The view chooses localized wording; callers
/// supply the same clock snapshot used for the rest of the dashboard frame.
class ModelScheduleTiming {
  final ScheduleTimingKind kind;
  final int amount;

  const ModelScheduleTiming._(this.kind, [this.amount = 0]);

  static ModelScheduleTiming? forEvent(CalendarEvent event, DateTime now) {
    final startDate = event.startDate;
    final startTime = event.startTime;
    if (startDate == null || startTime == null) return null;
    final startsAt = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
      startTime.hour,
      startTime.minute,
    );
    // Preserve the existing whole-minute thresholds and countdown rounding.
    final minutes = startsAt.difference(now).inMinutes;
    if (minutes < 0) {
      final endDate = event.endDate ?? startDate;
      final endTime = event.endTime;
      final endsAt = endTime != null
          ? DateTime(
              endDate.year,
              endDate.month,
              endDate.day,
              endTime.hour,
              endTime.minute,
            )
          : startsAt.add(const Duration(hours: 1));
      return ModelScheduleTiming._(
        !endsAt.isAfter(now)
            ? ScheduleTimingKind.needsReview
            : ScheduleTimingKind.alreadyStarted,
      );
    }
    if (minutes < 60) {
      return ModelScheduleTiming._(ScheduleTimingKind.minutes, minutes + 1);
    }
    if (minutes < 24 * 60) {
      return ModelScheduleTiming._(
        ScheduleTimingKind.hours,
        (minutes / 60).ceil(),
      );
    }
    return null;
  }
}
