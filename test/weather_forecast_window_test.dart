import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/utils/model_weather_forecast_window.dart';

void main() {
  final today = DateTime(2026, 10, 19);
  final window = ModelWeatherForecastWindow(DateTime(2026, 10, 19, 18, 40));
  for (final offset in [-1, 0, 1, 6, 7, 30]) {
    test('single-day offset $offset retains seven-day eligibility', () {
      expect(
        window.includes(
          startDate: today.add(Duration(days: offset)),
          endDate: null,
        ),
        offset >= 0 && offset < 7,
      );
    });
  }
  test('missing start date is ineligible even with an end date', () {
    expect(window.includes(startDate: null, endDate: today), isFalse);
  });
  test('an ongoing multi-day event remains eligible', () {
    expect(
      window.includes(
        startDate: today.subtract(const Duration(days: 30)),
        endDate: today,
      ),
      isTrue,
    );
  });
  test('an event ending before today is ineligible', () {
    expect(
      window.includes(
        startDate: today.subtract(const Duration(days: 30)),
        endDate: today.subtract(const Duration(days: 1)),
      ),
      isFalse,
    );
  });
  test(
    'missing end date uses start date instead of keeping old events alive',
    () {
      expect(
        window.includes(
          startDate: today.subtract(const Duration(days: 1)),
          endDate: null,
        ),
        isFalse,
      );
    },
  );
  test('time of day does not change calendar-date eligibility', () {
    expect(
      window.includes(
        startDate: DateTime(2026, 10, 19, 23, 59),
        endDate: DateTime(2026, 10, 19, 0, 1),
      ),
      isTrue,
    );
  });
  test('window boundaries work across year changes', () {
    final yearEnd = ModelWeatherForecastWindow(DateTime(2026, 12, 30));
    expect(
      yearEnd.includes(startDate: DateTime(2027, 1, 5), endDate: null),
      isTrue,
    );
    expect(
      yearEnd.includes(startDate: DateTime(2027, 1, 6), endDate: null),
      isFalse,
    );
  });
  test('generated dates match the previous direct-load date policy', () {
    final random = Random(1919);
    for (var i = 0; i < 300; i++) {
      final start = today.add(
        Duration(days: random.nextInt(100) - 50, hours: random.nextInt(24)),
      );
      final end = random.nextBool()
          ? null
          : start.add(Duration(days: random.nextInt(20)));
      final normalizedStart = DateTime(start.year, start.month, start.day);
      final rawEnd = end ?? start;
      final normalizedEnd = DateTime(rawEnd.year, rawEnd.month, rawEnd.day);
      final expected =
          normalizedStart.isBefore(today.add(const Duration(days: 7))) &&
          !normalizedEnd.isBefore(today);
      expect(window.includes(startDate: start, endDate: end), expected);
    }
  });
}
