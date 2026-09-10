class NLP {
  static final regex = RegExp(
    r'([^，。,]*?)\s*(加|減|\+|-)\s*(\d+(?:\.\d{1,4})?|[一二三四五六七八九十兩]+)\s*(元|點|分)?',
  );

  static List<ParsedResult> parseMulti(String text) {
    final results = <ParsedResult>[];

    for (final match in regex.allMatches(text)) {
      var action = match.group(1)?.trim() ?? '';
      final operation = match.group(2)!;
      if (action.isEmpty) {
        action = operation == '加' || operation == '+' ? 'Save' : 'Spend';
      }

      final rawNumber = match.group(3)!;
      final num? value =
          num.tryParse(rawNumber) ?? ChineseNumber.parse(rawNumber);
      if (value == null) continue;

      final isAdd = operation == '加' || operation == '+';
      results.add(ParsedResult(action, isAdd ? value : -value));
    }

    return results;
  }
}

class ParsedResult {
  const ParsedResult(this.description, this.value);

  final String description;
  final num value;
}

class ChineseNumber {
  static const _map = {
    '零': 0,
    '一': 1,
    '二': 2,
    '三': 3,
    '四': 4,
    '五': 5,
    '六': 6,
    '七': 7,
    '八': 8,
    '九': 9,
    '十': 10,
    '兩': 2,
  };

  static int? parse(String text) {
    if (_map.containsKey(text)) return _map[text];
    if (text == '十') return 10;
    if (text.startsWith('十')) {
      return 10 + (_map[text.substring(1)] ?? 0);
    }
    if (text.endsWith('十')) {
      return (_map[text.substring(0, 1)] ?? 1) * 10;
    }
    if (text.contains('十')) {
      final parts = text.split('十');
      return (_map[parts[0]] ?? 1) * 10 + (_map[parts[1]] ?? 0);
    }
    return null;
  }
}
