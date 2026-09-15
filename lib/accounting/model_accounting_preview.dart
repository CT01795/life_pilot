class AccountingPreview {
  String? id;
  String description;
  num value;
  String? currency;
  num? exchangeRate;
  String? eventId;
  DateTime? date;
  String primaryCategory;
  String? secondaryCategory;

  AccountingPreview({
    this.id,
    required this.description,
    required this.value,
    required this.currency,
    required this.exchangeRate,
    this.eventId,
    this.date,
    this.primaryCategory = 'uncategorized',
    this.secondaryCategory,
  });

  AccountingPreview copyWith({
    String? id,
    String? description,
    num? value,
    String? currency,
    num? exchangeRate,
    String? eventId,
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
      eventId: eventId ?? this.eventId,
      date: date ?? this.date,
      primaryCategory: primaryCategory ?? this.primaryCategory,
      secondaryCategory: secondaryCategory ?? this.secondaryCategory,
    );
  }
}
