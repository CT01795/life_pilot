import 'dart:convert';
import 'dart:ui';
import 'package:http/http.dart' as http;
import 'package:life_pilot/app/config_app.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/utils/holidays.dart';
import 'package:uuid/uuid.dart';

import '../utils/logger.dart';

class ServiceCalendar {
  
  static Future<List<EventItem>> fetchHolidays(
      DateTime start, DateTime end, Locale locale, String googleApiKey) async {
    final String calendarId = Holidays.getCalendarIdByLocale(CalendarConfig.tzLocation, locale);
    final url = Uri.parse(
      'https://www.googleapis.com/calendar/v3/calendars/$calendarId/events?'
      'key=$googleApiKey&'
      'timeMin=${start.toUtc().toIso8601String()}&'
      'timeMax=${end.toUtc().toIso8601String()}&'
      'orderBy=startTime&singleEvents=true',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode != 200) {
        throw Exception('Failed to load holidays: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      final List items = data['items'];

      List<EventItem> events = [];

      DateTime? tmpStart;
      DateTime? tmpEnd;
      String currentSummary = '';

      for (final item in items) {
        final DateTime date = DateTime.parse(item['start']['date']).toLocal();
        String summary = item['summary'];
        // 如果是台灣假日，使用你定義的 const summary 名稱
        final mappedSummary = CalendarConfig.taiwanHolidays.firstWhere(
          (holidayName) =>
              summary.contains(holidayName) && !summary.contains("補假"),
          orElse: () => summary,
        );

        final bool isTaiwanHoliday = CalendarConfig.taiwanHolidays
            .any((name) => mappedSummary.contains(name)); // 🟡 判斷是否為放假日

        if (Holidays.shouldMergeHoliday(mappedSummary)) {
          if (currentSummary == mappedSummary || currentSummary.isEmpty) {
            tmpStart ??= date;
            tmpEnd = date;
            currentSummary = mappedSummary;
            continue;
          } else {
            // 先儲存前一個連假
            events.add(_createMergedHoliday(
                start: tmpStart!, end: tmpEnd!, summary: currentSummary));
            // 開始新的合併區間
            tmpStart = date;
            tmpEnd = date;
            currentSummary = mappedSummary;
            continue;
          }
        }

        // 若之前有合併中的假期，先結束它
        if (tmpStart != null && tmpEnd != null && currentSummary.isNotEmpty) {
          events.add(_createMergedHoliday(
              start: tmpStart, end: tmpEnd, summary: currentSummary));
          tmpStart = null;
          tmpEnd = null;
          currentSummary = '';
        }

        final holidayEvent = EventItem(
          id: 'holiday_${Uuid().v4()}',
        )
          ..startDate = date
          ..endDate = date
          ..startTime = null
          ..endTime = null
          ..name = mappedSummary
          ..isTaiwanHoliday = isTaiwanHoliday
          ..isHoliday = true;
        events.add(holidayEvent);
      }

      // 收尾，加入最後一組合併假期
      if (tmpStart != null && tmpEnd != null && currentSummary.isNotEmpty) {
        events.add(_createMergedHoliday(
            start: tmpStart, end: tmpEnd, summary: currentSummary));
      }

      return events; // ✅ 回傳假日清單
    } catch (e, stack) {
      logger.e('Fetch holidays failed', error: e, stackTrace: stack);
      return [];
    }
  }

  static EventItem _createMergedHoliday(
      {required DateTime start,
      required DateTime end,
      required String summary}) {
    return EventItem(
      id: 'holiday_${start.toIso8601String()}',
    )
      ..startDate = start
      ..endDate = end
      ..startTime = null
      ..endTime = null
      ..name = summary
      ..isTaiwanHoliday = true
      ..isHoliday = true;
  }
}
