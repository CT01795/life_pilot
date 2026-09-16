import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/utils/decimal_input_formatter.dart';

void main() {
  const formatter = DecimalInputFormatter();

  TextEditingValue format(String value) => formatter.formatEditUpdate(
    TextEditingValue.empty,
    TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    ),
  );

  test('allows one decimal point', () {
    expect(format('23.4').text, '23.4');
  });

  test('removes only additional decimal points', () {
    expect(format('23.4.4').text, '23.44');
  });

  test('keeps at most four fractional digits', () {
    expect(format('23.45678').text, '23.4567');
  });

  test('adds thousands separators without changing the decimal value', () {
    expect(format('12345.6789').text, '12,345.6789');
  });

  test('can delete the final digit and leave a valid empty selection', () {
    final value = formatter.formatEditUpdate(
      const TextEditingValue(
        text: '1',
        selection: TextSelection.collapsed(offset: 1),
      ),
      TextEditingValue.empty,
    );

    expect(value.text, isEmpty);
    expect(value.selection, const TextSelection.collapsed(offset: 0));
  });
}
