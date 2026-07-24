class PointRecordItem {
  final String description;
  final String type;
  final int value;
  final DateTime? createdAt;
  final DateTime? date;
  final String? group;

  PointRecordItem({
    required this.description,
    required this.type,
    required this.value,
    this.createdAt,
    this.date,
    this.group,
  });

  factory PointRecordItem.fromJson(
    Map<String, dynamic> json,
  ) {
    return PointRecordItem(
      description: json['description'] ?? '',
      type: json['type'] ?? '',
      value: (json['value'] ?? 0) as int,
      createdAt: json['created_at'] != null
          ? DateTime.parse(
              json['created_at'],
            )
          : null,
      date: json['date'] != null
          ? DateTime.parse(
              json['date'],
            )
          : null,
      group: json['group'] ?? '',
    );
  }
}
