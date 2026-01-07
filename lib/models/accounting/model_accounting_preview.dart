class AccountingPreview {
  String? id;
  String description;
  int value;
  String? currency;
  double? exchangeRate;

  AccountingPreview({
    this.id,
    required this.description,
    required this.value,
    required this.currency,
    required this.exchangeRate,
  });

  AccountingPreview copyWith({
    String? id,
    String? description,
    int? value,
    String? currency,
    double? exchangeRate,
  }) {
    return AccountingPreview(
      id: id ?? this.id,
      description: description ?? this.description,
      value: value ?? this.value,
      currency: currency ?? this.currency,
      exchangeRate: exchangeRate ?? this.exchangeRate,
    );
  }
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
