import 'package:life_pilot/utils/model_event_weather.dart';

class WeatherCacheStore {
  static final WeatherCacheStore I = WeatherCacheStore._();
  WeatherCacheStore._();

  final Map<String, WeatherCache> cache = {};
  final Set<String> loading = {};
}