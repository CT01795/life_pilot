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

      final records = await loadHolidayYears(
        start: startDate,
        end: endDate,
        loadYear: (year) => _getHolidayYear(
          year: year,
          languageCode: languageCode,
          accessToken: accessToken,
        ),
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

  /// Independent years load concurrently. Future.wait retains year order even
  /// when responses arrive out of order; the existing yearly cache stays owner.
  /// Fail promptly if one year fails instead of waiting for unrelated years.
  /// Future.wait continues to observe late errors from every started read.
  static Future<List<CalendarHolidayRecord>> loadHolidayYears({
    required DateTime start,
    required DateTime end,
    required Future<List<CalendarHolidayRecord>> Function(int year) loadYear,
  }) async {
    final batches = await Future.wait([
      for (final year in ModelCalendarHolidays.requiredYears(start, end))
        Future<List<CalendarHolidayRecord>>.sync(() => loadYear(year)),
    ], eagerError: true);
    return [for (final batch in batches) ...batch];
  }

  static void _clearCacheAfterUtcDateChange() {
    final now = DateTime.now().toUtc();
    final today = DateTime.utc(now.year, now.month, now.day);
    if (_cacheUtcDate != today) {
      _yearCache.clear();
      _cacheUtcDate = today;
    }
  }

  static Future<List<CalendarHolidayRecord>> _getHolidayYear({
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

  static Future<List<CalendarHolidayRecord>> _loadHolidayYear({
    required int year,
    required String languageCode,
    required String accessToken,
  }) async {
    final yearStart = DateTime.utc(year, 1, 1);
    final yearEnd = DateTime.utc(year + 1, 1, 1);
    final cacheDate = _cacheUtcDate;
    final data = await RepositoryExternalCache().holidays(
      year: year,
      language: languageCode,
      backend: () => apiSupabase.post('/external/holidays', {
        'start': yearStart.toIso8601String(),
        'end': yearEnd.toIso8601String(),
        'language_code': languageCode,
      }, bearerToken: accessToken),
      onRefreshed: (data) {
        if (cacheDate != _cacheUtcDate ||
            data is! Map ||
            data['items'] is! List) {
          return;
        }
        _yearCache['$languageCode:$year'] = Future.value(
          ModelCalendarHolidays.parseRows(data['items'] as List),
        );
      },
    );
    final items = data is Map<String, dynamic> && data['items'] is List
        ? data['items'] as List
        : const [];
    return ModelCalendarHolidays.parseRows(items);
  }
}
