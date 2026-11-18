// ignore_for_file: deprecated_member_use

import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/utils/api.dart';
import 'package:life_pilot/utils/supabase.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/event_latln.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:life_pilot/utils/model_event_weather.dart';
import 'package:life_pilot/utils/model_weather_forecast_window.dart';
import 'package:life_pilot/utils/weather_cache_store.dart';
import 'package:life_pilot/utils/value_parser.dart';
import 'package:life_pilot/utils/repository_external_cache.dart';
import 'package:life_pilot/utils/repository_session_reads.dart';

typedef WeatherLoadResult = ({List<EventWeather> data, DateTime expiresAt});
typedef WeatherLoader = Future<WeatherLoadResult?> Function(EventViewModel);

class ServiceWeather {
  static const int preloadConcurrency = 3;
  ServiceWeather({WeatherLoader? weatherLoader})
    : _weatherLoader = weatherLoader;

  final WeatherLoader? _weatherLoader;
  final cacheStore = WeatherCacheStore.I;

  List<EventWeather>? getForecast({required String locationDisplay}) {
    return _getValidCache(locationDisplay)?.data;
  }

  WeatherCache? _getValidCache(String locationDisplay) {
    final cache = cacheStore.cache[locationDisplay];
    if (cache == null) return null;
    if (cache.isValid) return cache;
    cacheStore.cache.remove(locationDisplay);
    return null;
  }

  Future<List<EventWeather>?> loadWeather({
    required EventViewModel event,
    required bool hasLocation,
    required String locationDisplay,
    required DateTime? startDate,
    required DateTime? endDate,
    required String tableName,
  }) async {
    if (!hasLocation || locationDisplay.isEmpty) return null;
    if (tableName != TableNames.recommendPlaces &&
        !ModelWeatherForecastWindow(
          DateTime.now(),
        ).includes(startDate: startDate, endDate: endDate)) {
      return null;
    }

    final cache = _getValidCache(event.locationDisplay);
    if (cache != null) return cache.data;
    final active = cacheStore.loading[event.locationDisplay];
    if (active != null) return active;

    late Future<List<EventWeather>?> request;
    request = _loadAndCacheWeather(event).whenComplete(() {
      if (identical(cacheStore.loading[event.locationDisplay], request)) {
        cacheStore.loading.remove(event.locationDisplay);
      }
    });
    cacheStore.loading[event.locationDisplay] = request;
    return request;
  }

  Future<List<EventWeather>?> _loadAndCacheWeather(EventViewModel event) async {
    try {
      final result = await _getWeather(event: event);
      if (result == null) return null;
      cacheStore.cache[event.locationDisplay] = WeatherCache(
        data: result.data,
        expiresAt: result.expiresAt,
      );
      return result.data;
    } catch (e, st) {
      logger.e('loadWeather failed for ${event.id}: $e\n$st');
      cacheStore.cache.remove(event.locationDisplay);
      return null;
    }
  }

  Future<WeatherLoadResult?> _getWeather({
    required EventViewModel event,
  }) async {
    try {
      final injected = _weatherLoader;
      if (injected != null) return await injected(event);
      event = await ClusterItem.getLatLngFromAddressView(event);
      if (event.lat == null || event.lng == null) {
        return null;
      }

      final client = supabase;
      final accessToken = client.auth.currentSession?.accessToken;
      if (accessToken == null || accessToken.isEmpty) {
        logger.w('Skip weather because the user session is unavailable');
        return null;
      }

      final lat = event.lat!;
      final lng = event.lng!;
      final response = await RepositorySessionReads(client).read(
        'weather',
        (lat, lng),
        () => RepositoryExternalCache().weather(
          lat: lat,
          lng: lng,
          backend: () => apiCloud.post('/external/weather', {
            'lat': lat,
            'lng': lng,
          }, bearerToken: accessToken),
        ),
      );
      final items =
          response is Map<String, dynamic> && response['items'] is List
          ? response['items'] as List
          : const [];
      final rawExpiresAt = response is Map<String, dynamic>
          ? response['expires_at']
          : null;
      if (rawExpiresAt is! String) {
        throw const FormatException('Missing weather cache expiry');
      }
      final expiresAt = tryParseDateTimeValue(rawExpiresAt);
      if (expiresAt == null || !expiresAt.isAfter(DateTime.now())) {
        throw const FormatException('Invalid weather cache expiry');
      }
      final data = items
          .whereType<Map<String, dynamic>>()
          .map(EventWeather.fromJson)
          .toList();
      return (data: data, expiresAt: expiresAt);
    } catch (ex, stacktrace) {
      logger.e("getWeather error", error: ex, stackTrace: stacktrace);
      rethrow;
    }
  }

  Future<bool> preloadWeather(
    List<EventViewModel> events, {
    required String tableName,
    bool Function()? shouldContinue,
  }) async {
    var requested = false;
    final window = ModelWeatherForecastWindow(DateTime.now());
    final attemptedLocations = <String>{};
    final pending = <Future<List<EventWeather>?>>[];

    Future<void> flushPending() async {
      if (pending.isEmpty) return;
      await Future.wait(pending);
      pending.clear();
    }

    for (final e in events) {
      // In-flight HTTP work may finish, but a stale owner must not start the
      // remaining locations in its batch.
      if (shouldContinue?.call() == false) break;
      if (tableName != TableNames.recommendPlaces &&
          !window.includes(startDate: e.startDate, endDate: e.endDate)) {
        continue;
      }
      if (!e.hasLocation || e.locationDisplay.isEmpty) continue;
      if (_getValidCache(e.locationDisplay) != null) continue;
      // Cache keys already identify weather by location. Do not retry a failed
      // lookup for every card in this batch; a later batch may retry normally.
      if (!attemptedLocations.add(e.locationDisplay)) continue;

      pending.add(
        loadWeather(
          event: e,
          hasLocation: e.hasLocation,
          locationDisplay: e.locationDisplay,
          startDate: e.startDate,
          endDate: e.endDate,
          tableName: tableName,
        ),
      );
      requested = true;
      if (pending.length >= preloadConcurrency) await flushPending();
    }
    await flushPending();
    return requested;
  }
}
