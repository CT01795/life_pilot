class PointRecordPreview {
  String? id;
  String? eventId;
  String description;
  int value;
  DateTime? date;
  String primaryCategory;
  String? secondaryCategory;

  PointRecordPreview({
    this.id,
    this.eventId,
    required this.description,
    required this.value,
    this.date,
    this.primaryCategory = 'uncategorized',
    this.secondaryCategory,
  });

  PointRecordPreview copyWith({
    String? id,
    String? eventId,
    String? description,
    int? value,
    DateTime? date,
    String? primaryCategory,
    String? secondaryCategory,
  }) {
    return PointRecordPreview(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      description: description ?? this.description,
      value: value ?? this.value,
      date: date ?? this.date,
      primaryCategory: primaryCategory ?? this.primaryCategory,
      secondaryCategory: secondaryCategory ?? this.secondaryCategory,
    );
  }
}
