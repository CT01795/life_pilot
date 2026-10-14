import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/utils/value_parser.dart';

void main() {
  group('numeric database values', () {
    test('accepts native numbers and numeric text', () {
      expect(parseNumValue(' 23.5 '), 23.5);
      expect(parseIntValue(3.9), 3);
      expect(tryParseDoubleValue('1.25'), 1.25);
    });

    test('uses explicit fallbacks for invalid values', () {
      expect(parseNumValue('invalid', fallback: 8), 8);
      expect(parseIntValue(null, fallback: 4), 4);
      expect(parseDoubleValue('', fallback: 2.5), 2.5);
    });
  });

  test(
    'date parsing supports strings, DateTime values, and local conversion',
    () {
      final value = DateTime.utc(2026, 10, 14, 8, 30);
      expect(tryParseDateTimeValue(value), same(value));
      expect(
        tryParseDateTimeValue(value.toIso8601String(), toLocal: true),
        value.toLocal(),
      );
      expect(tryParseDateTimeValue('invalid'), isNull);
    },
  );

  test('boolean parsing supports PostgreSQL and JSON representations', () {
    expect(parseBoolValue(true), isTrue);
    expect(parseBoolValue('t'), isTrue);
    expect(parseBoolValue(1), isTrue);
    expect(parseBoolValue('false', fallback: true), isFalse);
    expect(parseBoolValue('unknown', fallback: true), isTrue);
  });
}
