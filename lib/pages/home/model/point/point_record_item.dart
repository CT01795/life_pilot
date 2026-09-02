import 'package:life_pilot/utils/const.dart';

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
      createdAt: json[Fields.createdAt] != null
          ? DateTime.parse(
              json[Fields.createdAt],
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

class PointDashboardSummary {
  final List<PointRecordItem> records;
  final int total;
  final int todayTotal;

  const PointDashboardSummary({
    required this.records,
    required this.total,
    this.todayTotal = 0,
  });

  const PointDashboardSummary.empty()
      : records = const [],
        total = 0,
        todayTotal = 0;
}
