// ignore_for_file: deprecated_member_use

import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/utils/api.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/date_time.dart';
import 'package:life_pilot/utils/event_latln.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:life_pilot/utils/model_event_weather.dart';
import 'package:life_pilot/utils/weather_cache_store.dart';

class ServiceWeather {
  final cacheStore = WeatherCacheStore.I;
  List<EventWeather>? getForecast({required String locationDisplay}) {
    return cacheStore.cache[locationDisplay]?.data;
  }

  Future<List<EventWeather>?> loadWeather({
    required EventViewModel event,
    required bool hasLocation,
    required String locationDisplay,
    required DateTime? startDate,
    required DateTime? endDate,
    required String tableName,
  }) async {
    if (!hasLocation) return null;
    //if (cacheStore.cache.containsKey(event.locationDisplay)) return;
    if (cacheStore.loading.contains(event.locationDisplay)) {
      return cacheStore.cache[event.locationDisplay]?.data;
    }
    final now = DateTime.now();
    final today = DateTimeFormatter.dateOnly(now);
    if (tableName == TableNames.recommendPlaces) {
    } else if (locationDisplay.isEmpty ||
        (startDate != null &&
            ((today.add(Duration(days: 7))).isBefore(startDate) ||
                (endDate != null && today.isAfter(endDate)) ||
                (endDate == null && today.isAfter(startDate))))) {
      return null;
    }

    final cache = cacheStore.cache[event.locationDisplay];

    if (cache != null) {
      final diff = now.difference(cache.created);

      // 8小時內不重新抓
      if (diff.inMinutes < 480) {
        return cache.data;
      }
    }

    cacheStore.loading.add(event.locationDisplay);

    try {
      final data = await getWeather(event: event);

      cacheStore.cache[event.locationDisplay] =
          WeatherCache(data: data, created: now);
      return data;
    } catch (e, st) {
      logger.e('loadWeather failed for ${event.id}: $e\n$st');
      cacheStore.cache[event.locationDisplay] =
          WeatherCache(data: [], created: now);
      return null;
    } finally {
      cacheStore.loading.remove(event.locationDisplay);
    }
  }

  Future<List<EventWeather>> getWeather({required EventViewModel event}) async {
    try {
      event = await ClusterItem.getLatLngFromAddressView(event);
      if (event.lat == null || event.lng == null) {
        return [];
      }

      final accessToken = supabase.auth.currentSession?.accessToken;
      if (accessToken == null || accessToken.isEmpty) {
        logger.w('Skip weather because the user session is unavailable');
        return [];
      }

      final response = await apiSupabase.post(
        '/external/weather',
        {
          'lat': event.lat,
          'lng': event.lng,
        },
        bearerToken: accessToken,
      );
      final items =
          response is Map<String, dynamic> && response['items'] is List
              ? response['items'] as List
              : const [];
      return items
          .whereType<Map<String, dynamic>>()
          .map(EventWeather.fromJson)
          .toList();
    } catch (ex, stacktrace) {
      logger.e("getWeather error", error: ex, stackTrace: stacktrace);
      rethrow;
    }
  }

  Future<void> preloadWeather(List<EventViewModel> events) async {
    final DateTime today = DateTimeFormatter.dateOnly(DateTime.now());
    final DateTime yesterday = today.add(Duration(days: -1));
    final DateTime thisWeek = today.add(Duration(days: 6));
    for (final e in events) {
      if (e.endDate == null) {
        if (!(thisWeek.compareTo(e.startDate!) == 1 &&
            yesterday.compareTo(e.startDate!) == -1)) {
          continue;
        }
      } else {
        if (!(thisWeek.compareTo(e.startDate!) == 1 &&
            yesterday.compareTo(e.endDate!) == -1)) {
          continue;
        }
      } //當只有start date, 日期必須是今日或一周內才要看天氣
      //strat date 必須在一周內開始, 且結束日必須至少今天開始才要看天氣
      if (!e.hasLocation) continue;
      if (WeatherCacheStore.I.cache.containsKey(e.locationDisplay)) continue;

      await loadWeather(
        event: e,
        hasLocation: e.hasLocation,
        locationDisplay: e.locationDisplay,
        startDate: null,
        endDate: null,
        tableName: '',
      );
    }
  }
}
