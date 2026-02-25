class AccountingPreview {
  String? id;
  String description;
  int value;
  String? currency;
  num? exchangeRate;

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
    num? exchangeRate,
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