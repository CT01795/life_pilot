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
}
