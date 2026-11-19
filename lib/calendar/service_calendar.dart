import 'dart:async';
import 'dart:ui';

import 'package:life_pilot/calendar/model_calendar_holidays.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/utils/api.dart';
import 'package:life_pilot/utils/supabase.dart';
import 'package:life_pilot/utils/repository_external_cache.dart';
import 'package:uuid/uuid.dart';

import '../utils/logger.dart';

class ServiceCalendar {
  static final Uuid _uuid = const Uuid();
  static const Set<String> _supportedLanguages = {'zh', 'en', 'ja', 'ko'};
  static final Map<String, Future<List<CalendarHolidayRecord>>> _yearCache = {};
  static DateTime? _cacheUtcDate;

  static Future<List<EventItem>> fetchHolidays(
    DateTime start,
    DateTime end,
    Locale locale,
  ) async {
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

      final records = await _getHolidayYears(
        start: startDate,
        end: endDate,
        languageCode: languageCode,
        accessToken: accessToken,
      );
      return ModelCalendarHolidays.project(
        records: records,
        start: startDate,
        end: endDate,
        createId: () => 'holiday_${_uuid.v4()}',
      );
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

  static Future<List<CalendarHolidayRecord>> _getHolidayYears({
    required DateTime start,
    required DateTime end,
    required String languageCode,
    required String accessToken,
  }) async {
    final years = ModelCalendarHolidays.requiredYears(start, end);
    final missing = [
      for (final year in years)
        if (!_yearCache.containsKey('$languageCode:$year')) year,
    ];
    Future<Map<int, List<CalendarHolidayRecord>>>? batch;
    if (missing.isNotEmpty) {
      batch = _loadHolidayYearBatch(
        years: missing,
        languageCode: languageCode,
        accessToken: accessToken,
      );
      for (final year in missing) {
        _yearCache['$languageCode:$year'] = batch.then(
          (rows) => rows[year] ?? const [],
        );
      }
    }
    try {
      final rows = await Future.wait([
        for (final year in years) _yearCache['$languageCode:$year']!,
      ], eagerError: true);
      return [for (final row in rows) ...row];
    } catch (_) {
      if (batch != null) {
        for (final year in missing) {
          final key = '$languageCode:$year';
          final request = _yearCache[key];
          if (request != null) _yearCache.remove(key);
        }
      }
      rethrow;
    }
  }

  static Future<Map<int, List<CalendarHolidayRecord>>> _loadHolidayYearBatch({
    required List<int> years,
    required String languageCode,
    required String accessToken,
  }) async {
    final cacheDate = _cacheUtcDate;
    final cached = await RepositoryExternalCache().holidayYears(
      years: years,
      language: languageCode,
    );
    final rows = <int, List<CalendarHolidayRecord>>{
      for (final row in cached)
        row['year'] as int: ModelCalendarHolidays.parseRows(
          row['items'] as List,
        ),
    };
    final allCached = cached.every((row) => row['cached'] == true);
    final allFresh = cached.every((row) => row['fresh'] == true);
    if (allCached) {
      if (!allFresh) {
        unawaited(() async {
          try {
            final refreshed = await _refreshHolidayYears(
              years: years,
              languageCode: languageCode,
              accessToken: accessToken,
            );
            if (cacheDate != _cacheUtcDate) return;
            for (final year in years) {
              _yearCache['$languageCode:$year'] = Future.value(
                refreshed[year] ?? const [],
              );
            }
          } catch (error, stackTrace) {
            logger.w(
              'Holiday background refresh failed; keeping cached dates',
              error: error,
              stackTrace: stackTrace,
            );
          }
        }());
      }
      return rows;
    }
    return _refreshHolidayYears(
      years: years,
      languageCode: languageCode,
      accessToken: accessToken,
    );
  }

  static Future<Map<int, List<CalendarHolidayRecord>>> _refreshHolidayYears({
    required List<int> years,
    required String languageCode,
    required String accessToken,
  }) async {
    final orderedYears = years.toSet().toList()..sort();
    final start = DateTime.utc(orderedYears.first, 1, 1);
    final end = DateTime.utc(orderedYears.last + 1, 1, 1);
    final data = await apiCloud.post('/external/holidays', {
      'start': start.toIso8601String(),
      'end': end.toIso8601String(),
      'language_code': languageCode,
    }, bearerToken: accessToken);
    if (data is! Map || data['items'] is! List) {
      throw const FormatException('Invalid holiday refresh response');
    }
    final result = <int, List<CalendarHolidayRecord>>{
      for (final year in orderedYears) year: [],
    };
    for (final record in ModelCalendarHolidays.parseRows(
      data['items'] as List,
    )) {
      final year = record.date.year;
      result[year]?.add(record);
    }
    return result;
  }
}
