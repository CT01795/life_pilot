import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/utils/value_parser.dart';

class _TextValue {
  _TextValue(this.text);
  final String text;
  int reads = 0;
  @override
  String toString() {
    reads++;
    return text;
  }
}

void main() {
  for (final value in <Object?>[null, '', ' \t\r\n ']) {
    test('absent numeric and date fields return null ($value)', () {
      expect(tryParseNumValue(value), isNull);
      expect(tryParseIntValue(value), isNull);
      expect(tryParseDoubleValue(value), isNull);
      expect(tryParseDateTimeValue(value), isNull);
      expect(tryParseDateTimeValue(value, toLocal: true), isNull);
    });
  }

  for (final kind in ['num', 'int', 'double', 'date']) {
    test('$kind stringifies non-native values exactly once', () {
      final valid = _TextValue(
        kind == 'date' ? ' 2026-10-30T08:00:00Z ' : ' 23 ',
      );
      final Object? result = switch (kind) {
        'num' => tryParseNumValue(valid),
        'int' => tryParseIntValue(valid),
        'double' => tryParseDoubleValue(valid),
        _ => tryParseDateTimeValue(valid),
      };
      expect(result, kind == 'date' ? DateTime.utc(2026, 10, 30, 8) : 23);
      expect(valid.reads, 1);
      final blank = _TextValue(' \t ');
      final Object? missing = switch (kind) {
        'num' => tryParseNumValue(blank),
        'int' => tryParseIntValue(blank),
        'double' => tryParseDoubleValue(blank),
        _ => tryParseDateTimeValue(blank),
      };
      expect(missing, isNull);
      expect(blank.reads, 1);
    });
  }

  test(
    'numeric text retains signs, exponent forms and invalid-value behavior',
    () {
      for (final text in [
        '0',
        '-23',
        '+23',
        '23.4000',
        '1e3',
        '0x10',
        'invalid',
        '23.4.4',
        'true',
        'NaN',
        'Infinity',
      ]) {
        final numValue = num.tryParse(text);
        final doubleValue = double.tryParse(text);
        if (numValue?.isNaN ?? false) {
          expect(tryParseNumValue(text)!.isNaN, isTrue);
        } else {
          expect(tryParseNumValue(text), numValue);
        }
        if (doubleValue?.isNaN ?? false) {
          expect(tryParseDoubleValue(text)!.isNaN, isTrue);
        } else {
          expect(tryParseDoubleValue(text), doubleValue);
        }
        expect(tryParseIntValue(text), int.tryParse(text));
      }
    },
  );

  test('native values keep their previous conversions and date identity', () {
    expect(tryParseNumValue(23.4), 23.4);
    expect(tryParseDoubleValue(23), 23.0);
    expect(tryParseIntValue(-23.9), -23);
    expect(tryParseNumValue(double.nan)!.isNaN, isTrue);
    expect(tryParseDoubleValue(double.infinity), double.infinity);
    final date = DateTime.utc(2026, 10, 30, 8);
    expect(tryParseDateTimeValue(date), same(date));
    expect(tryParseDateTimeValue(date, toLocal: true), date.toLocal());
  });

  test(
    'date strings preserve timezone conversion and permissive date parsing',
    () {
      for (final text in [
        '2026-10-30',
        '2026-10-30T23:59:59+08:00',
        '2024-02-29T00:00:00Z',
        '2026-02-30',
        'invalid',
        '23.4',
      ]) {
        final expected = DateTime.tryParse(text);
        expect(tryParseDateTimeValue(' $text '), expected);
        expect(
          tryParseDateTimeValue(' $text ', toLocal: true),
          expected?.toLocal(),
        );
      }
    },
  );

  test('empty values still use each caller supplied fallback', () {
    for (final value in <Object?>[null, '', '   ']) {
      expect(parseNumValue(value, fallback: -1.25), -1.25);
      expect(parseIntValue(value, fallback: -2), -2);
      expect(parseDoubleValue(value, fallback: 3.5), 3.5);
    }
  });

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
