import 'dart:convert';
import 'dart:ui';
import 'package:http/http.dart' as http;
import 'package:life_pilot/models/model_event.dart';
import 'package:life_pilot/utils/core/utils_const.dart';
import 'package:life_pilot/utils/core/utils_timezone_helper.dart';

class HolidayService {
  static const String _apiKey =
      'AIzaSyAMnaz88TnK9p4hJ31hGZuOlu43gxVx8Ik'; // <-- 金鑰

  static final Set<String> _mergeHolidayKeywords = {
    "春節",
    "兒童節",
    "清明節",
    "除夕",
    "New Year",
    "Children",
    "Tomb Sweeping",
    "New Year's Eve",
  };

  static Future<List<Event>> fetchHolidays(
      DateTime start, DateTime end, Locale locale) async {
    final String calendarId = getCalendarIdByTimezone(constTzLocation, locale);
    final url = Uri.parse(
      'https://www.googleapis.com/calendar/v3/calendars/$calendarId/events?'
      'key=$_apiKey&'
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
      List<Event> events = [];

      DateTime? tmpStart;
      DateTime? tmpEnd;
      String currentSummary = constEmpty;

      for (final item in items) {
        final DateTime date = DateTime.parse(item['start']['date']);
        String summary = item['summary'];
        // 如果是台灣假日，使用你定義的 const summary 名稱
        final mappedSummary = constRealHolidaysTaiwan.firstWhere(
          (holidayName) =>
              summary.contains(holidayName) && !summary.contains("補假"),
          orElse: () => summary,
        );

        final bool isTaiwanHoliday = constRealHolidaysTaiwan
            .any((name) => mappedSummary.contains(name)); // 🟡 判斷是否為放假日

        if (_mergeHolidayKeywords
            .any((keyword) => mappedSummary.contains(keyword))) {
          if (currentSummary == mappedSummary || currentSummary.isEmpty) {
            tmpStart ??= date;
            tmpEnd = date;
            currentSummary = mappedSummary;
            continue;
          } else {
            // 先儲存前一個連假
            events
                .add(_createMergedHoliday(start: tmpStart!, end: tmpEnd!, summary: currentSummary));
            // 開始新的合併區間
            tmpStart = date;
            tmpEnd = date;
            currentSummary = mappedSummary;
            continue;
          }
        }

        // 若之前有合併中的假期，先結束它
        if (tmpStart != null && tmpEnd != null && currentSummary.isNotEmpty) {
          events.add(_createMergedHoliday(start: tmpStart, end: tmpEnd, summary: currentSummary));
          tmpStart = null;
          tmpEnd = null;
          currentSummary = constEmpty;
        }

        final holidayEvent = Event(
          id: 'holiday_${start.toIso8601String()}',
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
        events.add(_createMergedHoliday(start: tmpStart, end: tmpEnd, summary: currentSummary));
      }

      return events; // ✅ 回傳假日清單
    } catch (e) {
      rethrow;
    }
  }

  static Event _createMergedHoliday(
      {required DateTime start, required DateTime end, required String summary}) {
    return Event(
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
