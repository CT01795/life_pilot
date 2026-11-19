// ignore_for_file: deprecated_member_use

import 'dart:async';

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
      return _decodeWeatherResult(response);
    } catch (ex, stacktrace) {
      logger.e("getWeather error", error: ex, stackTrace: stacktrace);
      rethrow;
    }
  }

  WeatherLoadResult _decodeWeatherResult(Object? response) {
    if (response is! Map || response['items'] is! List) {
      throw const FormatException('Invalid weather response');
    }
    final rawExpiresAt = response['expires_at'];
    if (rawExpiresAt is! String) {
      throw const FormatException('Missing weather cache expiry');
    }
    final expiresAt = tryParseDateTimeValue(rawExpiresAt);
    if (expiresAt == null || !expiresAt.isAfter(DateTime.now())) {
      throw const FormatException('Invalid weather cache expiry');
    }
    final data = (response['items'] as List)
        .map((item) => EventWeather.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
    return (data: data, expiresAt: expiresAt);
  }

  /// Warms several different locations with one cache RPC and, when needed,
  /// one Edge invocation. Individual card reads still share [cacheStore.loading].
  Future<bool> preloadWeatherBatch(
    List<EventViewModel> events, {
    required String tableName,
    bool Function()? shouldContinue,
  }) async {
    if (_weatherLoader != null) {
      return preloadWeather(
        events,
        tableName: tableName,
        shouldContinue: shouldContinue,
      );
    }
    final window = ModelWeatherForecastWindow(DateTime.now());
    final attemptedLocations = <String>{};
    final candidates = <EventViewModel>[];
    for (final event in events) {
      if (shouldContinue?.call() == false) break;
      if (tableName != TableNames.recommendPlaces &&
          !window.includes(
            startDate: event.startDate,
            endDate: event.endDate,
          )) {
        continue;
      }
      if (!event.hasLocation || event.locationDisplay.isEmpty) continue;
      if (_getValidCache(event.locationDisplay) != null) continue;
      if (!attemptedLocations.add(event.locationDisplay)) continue;
      candidates.add(event);
    }
    if (candidates.isEmpty || shouldContinue?.call() == false) return false;

    final active = <Future<List<EventWeather>?>>[];
    final ownedEvents = <EventViewModel>[];
    final ownedCompleters = <Completer<List<EventWeather>?>>[];
    final ownedFutures = <Future<List<EventWeather>?>>[];
    for (final event in candidates) {
      final loading = cacheStore.loading[event.locationDisplay];
      if (loading != null) {
        active.add(loading);
        continue;
      }
      final completer = Completer<List<EventWeather>?>();
      ownedEvents.add(event);
      ownedCompleters.add(completer);
      ownedFutures.add(completer.future);
      cacheStore.loading[event.locationDisplay] = completer.future;
    }

    if (ownedEvents.isNotEmpty) {
      try {
        final results = await _getWeatherBatch(
          ownedEvents,
          shouldContinue: shouldContinue,
        );
        for (var index = 0; index < ownedEvents.length; index++) {
          final result = results[index];
          if (result != null) {
            cacheStore.cache[ownedEvents[index].locationDisplay] = WeatherCache(
              data: result.data,
              expiresAt: result.expiresAt,
            );
          }
          ownedCompleters[index].complete(result?.data);
        }
      } catch (error, stackTrace) {
        logger.w(
          'Batch weather preload failed',
          error: error,
          stackTrace: stackTrace,
        );
        for (final completer in ownedCompleters) {
          if (!completer.isCompleted) completer.complete(null);
        }
      } finally {
        for (var index = 0; index < ownedEvents.length; index++) {
          final location = ownedEvents[index].locationDisplay;
          if (identical(cacheStore.loading[location], ownedFutures[index])) {
            cacheStore.loading.remove(location);
          }
        }
      }
    }
    await Future.wait(active);
    return true;
  }

  Future<List<WeatherLoadResult?>> _getWeatherBatch(
    List<EventViewModel> events, {
    bool Function()? shouldContinue,
  }) async {
    final results = List<WeatherLoadResult?>.filled(events.length, null);
    final resolved =
        <({int index, EventViewModel event, double lat, double lng})>[];
    for (var offset = 0; offset < events.length; offset += preloadConcurrency) {
      if (shouldContinue?.call() == false) break;
      final end = (offset + preloadConcurrency).clamp(0, events.length);
      final chunk = await Future.wait([
        for (var index = offset; index < end; index++)
          ClusterItem.getLatLngFromAddressView(events[index])
              .then((event) => (index: index, event: event))
              .catchError((_) => (index: index, event: events[index])),
      ]);
      for (final item in chunk) {
        final lat = item.event.lat;
        final lng = item.event.lng;
        if (lat != null && lng != null) {
          resolved.add((
            index: item.index,
            event: item.event,
            lat: lat,
            lng: lng,
          ));
        }
      }
    }
    if (resolved.isEmpty || shouldContinue?.call() == false) return results;

    final repository = RepositoryExternalCache();
    final cached = await repository.weatherBatch(
      locations: [for (final item in resolved) (lat: item.lat, lng: item.lng)],
    );
    final missing = <int>[];
    for (var index = 0; index < resolved.length; index++) {
      final value = cached[index];
      if (value == null) {
        missing.add(index);
      } else {
        results[resolved[index].index] = _decodeWeatherResult(value);
      }
    }
    if (missing.isEmpty || shouldContinue?.call() == false) return results;

    final accessToken = supabase.auth.currentSession?.accessToken;
    if (accessToken == null || accessToken.isEmpty) return results;
    final response = await apiCloud.post('/external/weather-batch', {
      'locations': [
        for (final index in missing)
          {'lat': resolved[index].lat, 'lng': resolved[index].lng},
      ],
    }, bearerToken: accessToken);
    if (response is! Map || response['results'] is! List) {
      throw const FormatException('Invalid weather batch response');
    }
    final refreshed = response['results'] as List;
    if (refreshed.length != missing.length) {
      throw const FormatException('Invalid weather batch result count');
    }
    for (var index = 0; index < missing.length; index++) {
      final value = refreshed[index];
      if (value != null) {
        results[resolved[missing[index]].index] = _decodeWeatherResult(value);
      }
    }
    return results;
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
