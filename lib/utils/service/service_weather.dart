// ignore_for_file: deprecated_member_use

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/date_time.dart';
import 'package:life_pilot/utils/event_latln.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:life_pilot/utils/model_event_weather.dart';
import 'package:life_pilot/utils/weather_cache_store.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ServiceWeather {
  final supabase = Supabase.instance.client;
  String? _apiKey;

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
    if (tableName == TableNames.recommendedAttractions) {
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
      final data = await getWeather(event: event, startDate: startDate);

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

  Future<List<EventWeather>> getWeather(
      {required EventViewModel event, required DateTime? startDate}) async {
    final tmpLocationDisplay = event.locationDisplay.split("．");
    final today = DateTime.now();
    final resultStartDate =
        startDate == null || startDate.isBefore(today) ? today : startDate;
    final todayDate = DateTime(today.year, today.month, today.day, today.hour);

    if (today.weekday == 3) {
      await supabase
          .from('weather_forecast')
          .delete()
          .lte('date', today.subtract(Duration(days: 1)).toIso8601String());
    }

    /// 1️⃣ 查 DB
    final dbRes = await supabase
        .from('weather_forecast')
        .select()
        .eq('location', event.locationDisplay)
        .gte('date', resultStartDate.add(Duration(hours: -3)).toIso8601String())
        .gte('created_at', todayDate.toIso8601String())
        .order('date', ascending: true);

    if (dbRes.isNotEmpty) {
      return dbRes
          .map<EventWeather>((e) => EventWeather.fromJson(e['weather']))
          .toList();
    }

    String country = ClusterItem.detectCountryHint(tmpLocationDisplay[0])
        .replaceAll(",", "");
    event = await ClusterItem.getLatLngFromAddressView(event);

    if (event.lat != null && event.lng != null) {
      final lat = event.lat;
      final lon = event.lng;
      _apiKey = await ClusterItem.getKey();
      // 2️⃣ 再呼叫 OpenWeather Weather API
      final url =
          'https://api.openweathermap.org/data/2.5/forecast?lat=$lat&lon=$lon&appid=$_apiKey&units=metric';

      final res = await http.get(Uri.parse(url));
      final data = json.decode(res.body);

      final List<EventWeather> days = [];

      for (var item in data['list']) {
        days.add(
          EventWeather(
            date: DateTime.parse(item['dt_txt']).toLocal(),
            main: item['weather'][0]['main'],
            description: item['weather'][0]['description'],
            icon: item['weather'][0]['icon'],
            temp: (item['main']['temp'] as num).toDouble(),
            feelsLike: (item['main']['feels_like'] as num).toDouble(),
            tempMin: (item['main']['temp_min'] as num).toDouble(),
            tempMax: (item['main']['temp_max'] as num).toDouble(),
            pressure: (item['main']['pressure'] as num).toDouble(),
            seaLevel: (item['main']['sea_level'] as num).toDouble(),
            grndLevel: (item['main']['grnd_level'] as num).toDouble(),
          ),
        );
      }

      await supabase.from('weather_forecast').insert(
            days
                .map((day) => {
                      'location': event.locationDisplay,
                      'date': day.date.toIso8601String(),
                      'weather': day.toJson(),
                      'created_at': todayDate.toIso8601String(),
                      'lat': lat,
                      'lon': lon,
                      'country': country,
                      'name': event.locationDisplay
                    })
                .toList(),
          );

      return days;
    }
    return [];
  }

  Future<void> preloadWeather(List<EventViewModel> events) async {
    final DateTime today = DateTimeFormatter.dateOnly(DateTime.now());
    final DateTime yesterday = today.add(Duration(days: -1));
    final DateTime thisWeek = today.add(Duration(days: 8));
    for (final e in events) {
      if (!(e.endDate == null && thisWeek.compareTo(e.startDate!) == 1 &&
          yesterday.compareTo(e.startDate!) == -1)) {
        continue;
      } //當只有start date, 日期必須是今日或一周內才要看天氣
     if (!(e.endDate != null && thisWeek.compareTo(e.startDate!) == 1 &&
          yesterday.compareTo(e.endDate!) == 1)) {
        continue;
      } //strat date 必須在一周內開始, 且結束日必須至少今天開始才要看天氣
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
