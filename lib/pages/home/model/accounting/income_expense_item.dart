import 'package:life_pilot/utils/const.dart';

class IncomeExpenseItem {
  final String description;
  final num value;
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
      value: (json['value'] as num?) ?? 0,
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

class AccountingDashboardSummary {
  final List<IncomeExpenseItem> records;
  final num total;
  final num todayTotal;
  final String currency;

  const AccountingDashboardSummary({
    required this.records,
    required this.total,
    this.todayTotal = 0,
    required this.currency,
  });

  const AccountingDashboardSummary.empty()
      : records = const [],
        total = 0,
        todayTotal = 0,
        currency = 'TWD';
}
