import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/utils/model_event_weather.dart';

void main() {
  test('converts forecast timestamp from UTC to device local time', () {
    const utcTimestamp = '2026-08-14T12:00:00Z';

    final weather = EventWeather.fromJson({
      'date': utcTimestamp,
      'main': 'Clear',
      'description': 'clear sky',
      'icon': '01d',
      'temp': 28.5,
      'feels_like': 30.0,
      'temp_min': 27.0,
      'temp_max': 29.0,
      'pressure': 1008,
      'sea_level': 1008,
      'grnd_level': 1005,
    });

    expect(weather.date, DateTime.parse(utcTimestamp).toLocal());
    expect(weather.date.isUtc, isFalse);
  });
}
