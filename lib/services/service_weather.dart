import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:life_pilot/models/event/model_event_weather.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ServiceWeather {
  final supabase = Supabase.instance.client;
  final String? apiKey;
  ServiceWeather({required this.apiKey});

  Future<List<EventWeather>> get3DayWeather({
    required String locationDisplay,
  }) async {
    String tmpLocation = locationDisplay.split("．")[0];
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    /// 1️⃣ 查 DB
    final dbRes = await supabase
        .from('weather_forecast')
        .select()
        .eq('location', tmpLocation)
        .gte('date', today.add(Duration(hours:-3)).toIso8601String())
        .gte('created_at', todayDate.toIso8601String())
        .lt('created_at', todayDate.add(const Duration(days: 1)).toIso8601String());

    if (dbRes.isNotEmpty) {
      return dbRes
          .map<EventWeather>((e) => EventWeather.fromJson(e['weather']))
          .toList();
    }

    // 1️⃣ 用 OpenWeather Geocoding API 取得經緯度
    final address = Uri.encodeComponent(tmpLocation);
    final geoUrl = Uri.parse(
      'https://api.openweathermap.org/geo/1.0/direct?q=$address&limit=1&appid=$apiKey',
    );

    final geoRes = await http.get(geoUrl);
    if (geoRes.statusCode == 200) {
      final geoData = json.decode(geoRes.body);
      if (geoData is List && geoData.isNotEmpty) {
        final loc = geoData[0];
        final lat = loc['lat'];
        final lon = loc['lon'];

        // 2️⃣ 再呼叫 OpenWeather Weather API
        final url =
            'https://api.openweathermap.org/data/2.5/forecast?lat=$lat&lon=$lon&appid=$apiKey&units=metric';

        final res = await http.get(Uri.parse(url));
        final data = json.decode(res.body);

        final List<EventWeather> days = [];

        for (var item in data['list']) {
          days.add(
            EventWeather(
              date: DateTime.parse(item['dt_txt']),
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
          });
        }

        final dbRes = await supabase
          .from('weather_forecast')
          .select()
          .eq('location', tmpLocation)
          .gte('date', today.add(Duration(hours:-3)).toIso8601String())
          .gte('created_at', todayDate.toIso8601String())
          .lt('created_at', todayDate.add(const Duration(days: 1)).toIso8601String());

        if (dbRes.isNotEmpty) {
          return dbRes
            .map<EventWeather>((e) => EventWeather.fromJson(e['weather']))
            .toList();
        }
      }
    }
    return [];
  }
}
  /*Future<EventWeather?> fetchCurrentWeather(String city) async {
    final url = Uri.parse(
      'https://api.openweathermap.org/data/2.5/weather?q=$city&appid=$apiKey&units=metric'
    );

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);
      return EventWeather.fromJson(jsonData);
    } else {
      return null;
    }
  }*/