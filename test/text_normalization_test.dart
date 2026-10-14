import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/utils/text_normalization.dart';

void main() {
  group('normalizeText', () {
    test('normalizes nullable and padded values', () {
      expect(normalizeText(null), isEmpty);
      expect(normalizeText('  User@Example.COM  '), 'user@example.com');
    });

    test('supports values returned from untyped database rows', () {
      expect(normalizeText(123), '123');
    });
  });

  test('normalizedTextEquals ignores case and surrounding whitespace', () {
    expect(normalizedTextEquals(' Activity ', 'activity'), isTrue);
    expect(normalizedTextEquals('activity', 'attraction'), isFalse);
  });
}
