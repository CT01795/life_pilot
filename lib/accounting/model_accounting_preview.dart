class AccountingPreview {
  String? id;
  String description;
  int value;
  String? currency;
  num? exchangeRate;
  DateTime? date;
  String primaryCategory;
  String? secondaryCategory;

  AccountingPreview({
    this.id,
    required this.description,
    required this.value,
    required this.currency,
    required this.exchangeRate,
    this.date,
    this.primaryCategory = 'uncategorized',
    this.secondaryCategory,
  });

  AccountingPreview copyWith({
    String? id,
    String? description,
    int? value,
    String? currency,
    num? exchangeRate,
    DateTime? date,
    String? primaryCategory,
    String? secondaryCategory,
  }) {
    return AccountingPreview(
      id: id ?? this.id,
      description: description ?? this.description,
      value: value ?? this.value,
      currency: currency ?? this.currency,
      exchangeRate: exchangeRate ?? this.exchangeRate,
      date: date ?? this.date,
      primaryCategory: primaryCategory ?? this.primaryCategory,
      secondaryCategory: secondaryCategory ?? this.secondaryCategory,
    );
  }
}
