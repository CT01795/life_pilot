// ignore_for_file: deprecated_member_use

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/date_time.dart';
import 'package:life_pilot/utils/event_latln.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:life_pilot/utils/model_event_weather.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ServiceWeather {
  final supabase = Supabase.instance.client;
  String? _apiKey;

  final Set<String> _loadingIds = {};
  final Map<String, WeatherCache?> _forecastCache = {};

  List<EventWeather>? getForecast(String eventId) {
    return _forecastCache[eventId]?.data;
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
    //if (_forecastCache.containsKey(event.id)) return;
    if (_loadingIds.contains(event.id)) return null;
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

    WeatherCache? cache = _forecastCache[event.id];

    if (cache != null) {
      final diff = now.difference(cache.created);

      // 3小時內不重新抓
      if (diff.inMinutes < 180) {
        return cache.data;
      }
    }

    _loadingIds.add(event.id);

    try {
      final data = await getWeather(event: event, startDate: startDate);

      _forecastCache[event.id] = WeatherCache(data: data, created: now);
      return data;
    } catch (e, st) {
      logger.e('loadWeather failed for ${event.id}: $e\n$st');
      _forecastCache[event.id] = WeatherCache(data: [], created: now);
      return null;
    } finally {
      _loadingIds.remove(event.id);
    }
  }

  Future<List<EventWeather>> getWeather(
      {required EventViewModel event, required DateTime? startDate}) async {
    String tmpLocation = event.locationDisplay.split("．")[0];
    final today = DateTime.now();
    final resultStartDate =
        startDate == null || startDate.isBefore(today) ? today : startDate;
    final todayDate = DateTime(today.year, today.month, today.day, today.hour);

    await supabase
        .from('weather_forecast')
        .delete()
        .lte('date', today.subtract(Duration(days: 2)).toIso8601String());

    /// 1️⃣ 查 DB
    final dbRes = await supabase
        .from('weather_forecast')
        .select()
        .eq('location', tmpLocation)
        .gte('date', resultStartDate.add(Duration(hours: -3)).toIso8601String())
        .gte('created_at', todayDate.toIso8601String())
        .order('date', ascending: true);

    if (dbRes.isNotEmpty) {
      return dbRes
          .map<EventWeather>((e) => EventWeather.fromJson(e['weather']))
          .toList();
    }

    // 1️⃣ 用 OpenWeather Geocoding API 取得經緯度
    event = await ClusterItem.getLatLngFromAddressView(event);
    if (event.lat != null && event.lng != null) {
      final lat = event.lat;
      final lon = event.lng;
      final country =
          ClusterItem.detectCountryHint(tmpLocation).replaceAll(",", "");
      final name = tmpLocation;
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

      /// 3️⃣ 寫 DB
      for (final day in days) {
        await supabase.from('weather_forecast').upsert({
          'location': tmpLocation,
          'date': day.date.toIso8601String(),
          'weather': day.toJson(),
          'created_at': todayDate.toIso8601String(),
          'lat': lat,
          'lon': lon,
          'country': country,
          'name': name
        });
      }

      final dbRes = await supabase
          .from('weather_forecast')
          .select()
          .eq('location', tmpLocation)
          .gte('date',
              resultStartDate.add(Duration(hours: -3)).toIso8601String())
          .gte('created_at', todayDate.toIso8601String())
          .order('date', ascending: true);

      if (dbRes.isNotEmpty) {
        return dbRes
            .map<EventWeather>((e) => EventWeather.fromJson(e['weather']))
            .toList();
      }
    }
    return [];
  }
}
