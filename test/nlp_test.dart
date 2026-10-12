import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/utils/nlp.dart';

void main() {
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
