import 'package:flutter/services.dart';

class GroupedIntegerInputFormatter extends TextInputFormatter {
  const GroupedIntegerInputFormatter();

  static final _allowed = RegExp(r'^[0-9,]*$');

  static int? tryParse(String? text) =>
      int.tryParse((text ?? '').replaceAll(',', '').trim());

  static String format(String digits) => const GroupedIntegerInputFormatter()
      .formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: digits))
      .text;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => _allowed.hasMatch(newValue.text)
      ? const DecimalInputFormatter(
          decimalPlaces: 0,
        ).formatEditUpdate(oldValue, newValue)
      : oldValue;
}

/// Keeps an optional leading minus sign, one decimal point, and at most four
/// fractional digits. Extra characters are removed without clearing the rest.
class DecimalInputFormatter extends TextInputFormatter {
  const DecimalInputFormatter({
    this.decimalPlaces = 4,
    this.allowNegative = false,
  });

  final int decimalPlaces;
  final bool allowNegative;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final rawOutput = StringBuffer();
    final rawBeforeCursor = StringBuffer();
    var hasDecimalPoint = false;
    var fractionDigits = 0;

    for (var index = 0; index < newValue.text.length; index++) {
      final character = newValue.text[index];
      var accepted = false;

      if (character == '-' &&
          allowNegative &&
          index == 0 &&
          rawOutput.isEmpty) {
        accepted = true;
      } else if (character == '.' && !hasDecimalPoint) {
        hasDecimalPoint = true;
        accepted = true;
      } else if (RegExp(r'\d').hasMatch(character)) {
        if (!hasDecimalPoint || fractionDigits < decimalPlaces) {
          accepted = true;
          if (hasDecimalPoint) fractionDigits++;
        }
      }

      if (accepted) {
        rawOutput.write(character);
        if (index < newValue.selection.end) rawBeforeCursor.write(character);
      }
    }

    final text = _withThousandsSeparators(rawOutput.toString());
    final cursorOffset = _withThousandsSeparators(
      rawBeforeCursor.toString(),
    ).length;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(
        offset: cursorOffset.clamp(0, text.length),
      ),
    );
  }

  String _withThousandsSeparators(String raw) {
    if (raw.isEmpty || raw == '-') return raw;
    final negative = raw.startsWith('-');
    final unsigned = negative ? raw.substring(1) : raw;
    final decimalIndex = unsigned.indexOf('.');
    final integerPart = decimalIndex < 0
        ? unsigned
        : unsigned.substring(0, decimalIndex);
    final fractionPart = decimalIndex < 0
        ? null
        : unsigned.substring(decimalIndex + 1);

    final grouped = StringBuffer();
    for (var index = 0; index < integerPart.length; index++) {
      if (index > 0 && (integerPart.length - index) % 3 == 0) {
        grouped.write(',');
      }
      grouped.write(integerPart[index]);
    }

    return '${negative ? '-' : ''}$grouped'
        '${fractionPart == null ? '' : '.$fractionPart'}';
  }
}
