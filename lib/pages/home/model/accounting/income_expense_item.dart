import 'package:life_pilot/utils/const.dart';

class IncomeExpenseItem {
  final String description;
  final int value;
  final String? currency;
  final DateTime? createdAt;
  final DateTime? date;
  final String? group;

  IncomeExpenseItem({
    required this.description,
    required this.value,
    this.currency,
    this.createdAt,
    this.date,
    this.group,
  });

  factory IncomeExpenseItem.fromJson(
    Map<String, dynamic> json,
  ) {
    return IncomeExpenseItem(
      description: json['description'] ?? '',
      value: (json['value'] ?? 0) as int,
      currency: json['currency'],
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
