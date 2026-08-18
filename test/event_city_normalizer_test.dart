import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/utils/event_city_normalizer.dart';

void main() {
  group('EventCityNormalizer', () {
    test('normalizes known English city names', () {
      expect(EventCityNormalizer.normalize('Hsinchu City'), '\u65B0\u7AF9');
      expect(EventCityNormalizer.normalize('New Taipei City'), '\u65B0\u5317');
      expect(EventCityNormalizer.normalize('Taipei City'), '\u53F0\u5317');
    });

    test('maps known districts to their parent city', () {
      expect(
          EventCityNormalizer.normalize('\u4E2D\u58E2\u5340'), '\u6843\u5712');
      expect(
          EventCityNormalizer.normalize('\u9F13\u5C71\u5340'), '\u9AD8\u96C4');
    });

    test('normalizes traditional variant, suffix, and zero-width spaces', () {
      expect(
          EventCityNormalizer.normalize('\u81FA\u5317\u5E02'), '\u53F0\u5317');
      expect(
          EventCityNormalizer.normalize('\u53F0\u4E2D\u200B'), '\u53F0\u4E2D');
      expect(EventCityNormalizer.normalize('  \u65B0\u7AF9\u7E23  '),
          '\u65B0\u7AF9');
    });

    test('keeps short and empty values safe', () {
      expect(EventCityNormalizer.normalize('\u91D1\u9580'), '\u91D1\u9580');
      expect(EventCityNormalizer.normalize(''), '');
    });
  });
}
