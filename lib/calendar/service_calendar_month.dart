import 'dart:ui';
import 'package:life_pilot/calendar/model_calendar_month_query.dart';
import 'package:life_pilot/calendar/service_calendar.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/event/service_event.dart';
import 'package:life_pilot/utils/logger.dart';

typedef CalendarHolidayLoader =
    Future<List<EventItem>> Function(
      DateTime start,
      DateTime end,
      Locale locale,
    );

/// Reads event/holiday data without owning UI state or month caches.
class ServiceCalendarMonth {
  final ServiceEvent _events;
  final CalendarHolidayLoader _holidays;

  ServiceCalendarMonth({
    ServiceEvent? serviceEvent,
    CalendarHolidayLoader? holidays,
  }) : _events = serviceEvent ?? ServiceEvent(),
       _holidays = holidays ?? ServiceCalendar.fetchHolidays;

  Future<List<EventItem>> loadMonth(
    ModelCalendarMonthQuery query, {
    bool Function()? shouldContinue,
    void Function(List<EventItem>)? onEventsReady,
  }) async {
    if (shouldContinue?.call() == false) return [];
    var reading = true;
    bool isActive() => reading && shouldContinue?.call() != false;
    try {
      final results = await Future.wait<List<EventItem>?>([
        // Register both branches even if a service throws before returning a
        // Future, so a sibling's late error is always observed by Future.wait.
        Future<List<EventItem>?>.sync(() {
          if (!isActive()) return null;
          return _events.getEvents(
            tableName: query.tableName,
            dateS: query.start,
            dateE: query.end,
            inputUser: query.account,
            storageLocation: query.storage,
            shouldContinue: isActive,
          );
        }).then((events) {
          if (isActive()) {
            onEventsReady?.call(events ?? []);
          }
          return events;
        }),
        Future<List<EventItem>>.sync(() {
          if (!isActive()) return [];
          return _holidays(
            query.start.subtract(const Duration(days: 2)),
            query.end.add(const Duration(days: 2)),
            query.locale,
          );
        }),
      ], eagerError: true);
      if (shouldContinue?.call() == false) return [];
      return [...?results[0], ...?results[1]];
    } catch (error, stackTrace) {
      if (shouldContinue?.call() != false) {
        logger.e(
          'Calendar month load failed',
          error: error,
          stackTrace: stackTrace,
        );
      }
      rethrow;
    } finally {
      // Already-sent reads cannot be cancelled here. Close progressive
      // publication and service pagination after either completion or failure.
      reading = false;
    }
  }
}
