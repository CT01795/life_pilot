import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:life_pilot/models/event/model_event_weather.dart';

class ServiceWeather {
  final String apiKey;
  ServiceWeather({required this.apiKey});

  Future<EventWeather?> fetchCurrentWeather(String city) async {
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
  }
}