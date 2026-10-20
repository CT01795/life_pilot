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
  }) async {
    if (shouldContinue?.call() == false) return [];
    try {
      final results = await Future.wait<List<EventItem>?>([
        _events.getEvents(
          tableName: query.tableName,
          dateS: query.start,
          dateE: query.end,
          inputUser: query.account,
          storageLocation: query.storage,
          shouldContinue: shouldContinue,
        ),
        _holidays(
          query.start.subtract(const Duration(days: 2)),
          query.end.add(const Duration(days: 2)),
          query.locale,
        ),
      ]);
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
    }
  }
}
