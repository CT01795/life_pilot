class NLP {
  // ① 加 / 扣 + 數字（阿拉伯 or 中文）
  static final regex = RegExp(
    r'([^，。,]*?)\s*(加|扣|\+|-)\s*(\d+|[一二三四五六七八九十兩]+)\s*(分|點|元)?',
  );
  static List<ParsedResult> parseMulti(String text) {
    final results = <ParsedResult>[];

    for (final m in regex.allMatches(text)) {
      String action = m.group(1)?.trim() ?? '';
      final op = m.group(2)!;
      if (action.isEmpty) {
        action = op == "加" || op == "+" ? "Save" : "Spend";
      }

      final rawNumber = m.group(3)!;

      int? value = int.tryParse(rawNumber) ?? ChineseNumber.parse(rawNumber);

      if (value == null) continue;

      final isAdd = op == '加' || op == '+';

      results.add(
        ParsedResult(
          action,
          isAdd ? value : -value,
        ),
      );
    }

    return results;
  }
}

class ParsedResult {
  final String description;
  final int value;

  ParsedResult(this.description, this.value);
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