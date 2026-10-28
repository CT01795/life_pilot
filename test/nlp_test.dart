import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/utils/nlp.dart';

void main() {
  group('submission validation', () {
    for (final text in [
      '',
      '   ',
      '午餐120',
      '午餐-',
      '午餐-abc',
      '午餐-23.4.4',
      '午餐-23.45678',
      '午餐-0',
      '午餐-120；薪資30000',
      '午餐120；薪資+30000',
      '午餐-120；備註',
    ]) {
      test(
        'rejects invalid input without returning a partial batch: $text',
        () {
          expect(() => NLP.parseForSubmission(text), throwsFormatException);
        },
      );
    }

    test('accepts complete signed entries and four decimal places', () {
      final rows = NLP.parseForSubmission('午餐-23.4567；薪資+30,000');
      expect(rows.map((r) => r.value), [-23.4567, 30000]);
      expect(rows.map((r) => r.description), ['午餐', '薪資']);
    });

    test('accepts words used in Chinese speech', () {
      final rows = NLP.parseForSubmission('運動加分10點；遲到扣分2點', integersOnly: true);
      expect(rows.map((r) => r.value), [10, -2]);
    });

    test('points reject the whole batch if one entry has a fraction', () {
      expect(
        () => NLP.parseForSubmission('運動+10；遲到-2.5', integersOnly: true),
        throwsFormatException,
      );
    });

    test('correcting the original text allows a subsequent submission', () {
      expect(() => NLP.parseForSubmission('午餐120'), throwsFormatException);
      expect(NLP.parseForSubmission('午餐-120').single.value, -120);
    });
  });

  test('accounting parser preserves up to four decimal places', () {
    final result = NLP.parseMulti('午餐-23.4567');

    expect(result, hasLength(1));
    expect(result.single.description, '午餐');
    expect(result.single.value, -23.4567);
  });

  test('accounting parser does not consume a fifth decimal digit', () {
    final result = NLP.parseMulti('收入+1234.56789');

    expect(result, hasLength(1));
    expect(result.single.value, 1234.5678);
  });

  test('accounting parser recognizes income and expense words', () {
    final result = NLP.parseMulti('午餐支出 120；薪資收入 30,000');

    expect(result, hasLength(2));
    expect(result[0].description, '午餐');
    expect(result[0].value, -120);
    expect(result[1].description, '薪資');
    expect(result[1].value, 30000);
  });

  test('points parser recognizes add and deduct words', () {
    final result = NLP.parseMulti('運動加分 10；遲到扣分 2');

    expect(result, hasLength(2));
    expect(result[0].description, '運動');
    expect(result[0].value, 10);
    expect(result[1].description, '遲到');
    expect(result[1].value, -2);
  });
}
