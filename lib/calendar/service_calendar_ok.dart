import 'dart:convert';
import 'dart:ui';
import 'package:http/http.dart' as http;
import 'package:life_pilot/app/config_app.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/utils/holidays.dart';
import 'package:uuid/uuid.dart';

import '../utils/logger.dart';

class ServiceCalendar {
  static final Uuid _uuid = const Uuid();
  static Future<List<EventItem>> fetchHolidays(
      DateTime start, DateTime end, Locale locale, String googleApiKey, {http.Client? client}) async {
    final httpClient = client ?? http.Client();
    final List<EventItem> holidays = [];
    final String calendarId = Holidays.getCalendarIdByLocale(CalendarConfig.tzLocation, locale);
    final url = Uri.parse(
      'https://www.googleapis.com/calendar/v3/calendars/$calendarId/events?'
      'key=$googleApiKey&'
      'timeMin=${start.toUtc().toIso8601String()}&'
      'timeMax=${end.toUtc().toIso8601String()}&'
      'orderBy=startTime&singleEvents=true',
    );

    try {
      final response = await httpClient.get(url);
      if (response.statusCode != 200) {
        throw Exception('Failed to load holidays: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      final List items = data['items'] ?? [];

      EventItem? lastMergedHoliday;

      for (final item in items) {
        final DateTime date =
            DateTime.parse(item['start']['date']).toLocal();
        final String summary = item['summary'];

        lastMergedHoliday =
            _processHolidayItem(date, summary, lastMergedHoliday, holidays);
      }
      return holidays;
    } catch (e, stack) {
      logger.e('Fetch holidays failed', error: e, stackTrace: stack);
      return [];
    }
  }

  // 處理單筆假日，若需合併連假則更新 lastMergedHoliday
  static EventItem? _processHolidayItem(
      DateTime date,
      String summary,
      EventItem? lastMerged,
      List<EventItem> output) {
    final mappedSummary = CalendarConfig.taiwanHolidays.firstWhere(
      (holidayName) =>
          summary.contains(holidayName) && !summary.contains("補假"),
      orElse: () => summary,
    );

    final bool isTaiwanHoliday =
        CalendarConfig.taiwanHolidays.any((name) => mappedSummary.contains(name));

    // 若需要合併連假，且 lastMerged 同名，延長結束日期
    if (lastMerged != null &&
        Holidays.shouldMergeHoliday(mappedSummary) &&
        lastMerged.name == mappedSummary) {
      lastMerged.endDate = date;
      return lastMerged;
    } else {
      final newHoliday = EventItem(
        id: 'holiday_${_uuid.v4()}',
        startDate: date,
        endDate: date,
        startTime: null,
        endTime: null,
        name: mappedSummary,
        isTaiwanHoliday: isTaiwanHoliday,
        isHoliday: true,
      );
      output.add(newHoliday);
      return Holidays.shouldMergeHoliday(mappedSummary) ? newHoliday : null;
    }
  }
}
