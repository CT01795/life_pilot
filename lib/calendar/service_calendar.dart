import 'dart:ui';

import 'package:life_pilot/apps/config_app.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/utils/api.dart';
import 'package:life_pilot/utils/holidays.dart';
import 'package:uuid/uuid.dart';

import '../utils/logger.dart';

class _HolidayRecord {
  final DateTime date;
  final String summary;

  const _HolidayRecord({required this.date, required this.summary});
}

class ServiceCalendar {
  static final Uuid _uuid = const Uuid();
  static const Set<String> _supportedLanguages = {'zh', 'en', 'ja', 'ko'};
  static final Map<String, Future<List<_HolidayRecord>>> _yearCache = {};
  static DateTime? _cacheUtcDate;

  static Future<List<EventItem>> fetchHolidays(
      DateTime start, DateTime end, Locale locale) async {
    final List<EventItem> holidays = [];
    final accessToken = supabase.auth.currentSession?.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      logger.w('Skip holidays because the user session is unavailable');
      return holidays;
    }

    final requestedLanguage = locale.languageCode.toLowerCase();
    final languageCode = _supportedLanguages.contains(requestedLanguage)
        ? requestedLanguage
        : 'zh';

    try {
      _clearCacheAfterUtcDateChange();

      final startDate = DateTime(start.year, start.month, start.day);
      final endDate = DateTime(end.year, end.month, end.day);
      if (!endDate.isAfter(startDate)) return holidays;

      final lastIncludedDate = endDate.subtract(const Duration(days: 1));
      final records = <_HolidayRecord>[];
      for (int year = startDate.year; year <= lastIncludedDate.year; year++) {
        records.addAll(await _getHolidayYear(
          year: year,
          languageCode: languageCode,
          accessToken: accessToken,
        ));
      }
      records.sort((a, b) => a.date.compareTo(b.date));

      EventItem? lastMergedHoliday;

      for (final record in records) {
        if (record.date.isBefore(startDate) || !record.date.isBefore(endDate)) {
          continue;
        }

        lastMergedHoliday = _processHolidayItem(
            record.date, record.summary, lastMergedHoliday, holidays);
      }
      return holidays;
    } catch (e, stack) {
      logger.e('Fetch holidays failed', error: e, stackTrace: stack);
      return [];
    }
  }

  static void _clearCacheAfterUtcDateChange() {
    final now = DateTime.now().toUtc();
    final today = DateTime.utc(now.year, now.month, now.day);
    if (_cacheUtcDate != today) {
      _yearCache.clear();
      _cacheUtcDate = today;
    }
  }

  static Future<List<_HolidayRecord>> _getHolidayYear({
    required int year,
    required String languageCode,
    required String accessToken,
  }) async {
    final cacheKey = '$languageCode:$year';
    final request = _yearCache.putIfAbsent(
      cacheKey,
      () => _loadHolidayYear(
        year: year,
        languageCode: languageCode,
        accessToken: accessToken,
      ),
    );

    try {
      return await request;
    } catch (_) {
      if (identical(_yearCache[cacheKey], request)) {
        _yearCache.remove(cacheKey);
      }
      rethrow;
    }
  }

  static Future<List<_HolidayRecord>> _loadHolidayYear({
    required int year,
    required String languageCode,
    required String accessToken,
  }) async {
    final yearStart = DateTime.utc(year, 1, 1);
    final yearEnd = DateTime.utc(year + 1, 1, 1);
    final data = await apiSupabase.post(
      '/external/holidays',
      {
        'start': yearStart.toIso8601String(),
        'end': yearEnd.toIso8601String(),
        'language_code': languageCode,
      },
      bearerToken: accessToken,
    );
    final items = data is Map<String, dynamic> && data['items'] is List
        ? data['items'] as List
        : const [];
    final records = <_HolidayRecord>[];

    for (final item in items) {
      if (item is! Map<String, dynamic>) continue;
      final rawDate = item['date'];
      final rawSummary = item['summary'];
      if (rawDate is! String || rawSummary is! String) continue;

      final parsedDate = DateTime.tryParse(rawDate);
      if (parsedDate == null) continue;
      records.add(_HolidayRecord(
        date: DateTime(parsedDate.year, parsedDate.month, parsedDate.day),
        summary: rawSummary,
      ));
    }

    return records;
  }

  // 處理單筆假日，若需合併連假則更新 lastMergedHoliday
  static EventItem? _processHolidayItem(DateTime date, String summary,
      EventItem? lastMerged, List<EventItem> output) {
    final mappedSummary = CalendarConfig.taiwanHolidays.firstWhere(
      (holidayName) => summary.contains(holidayName) && !summary.contains("補假"),
      orElse: () => summary,
    );

    final bool isTaiwanHoliday = CalendarConfig.taiwanHolidays
        .any((name) => mappedSummary.contains(name));

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
