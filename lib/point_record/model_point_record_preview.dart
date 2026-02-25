class PointRecordPreview {
  String? id;
  String description;
  int value;

  PointRecordPreview({
    this.id,
    required this.description,
    required this.value,
  });

  PointRecordPreview copyWith({
    String? id,
    String? description,
    int? value,
  }) {
    return PointRecordPreview(
      id: id ?? this.id,
      description: description ?? this.description,
      value: value ?? this.value,
    );
  }
}