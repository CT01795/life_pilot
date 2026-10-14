import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/value_parser.dart';

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

  factory IncomeExpenseItem.fromJson(Map<String, dynamic> json) {
    return IncomeExpenseItem(
      description: json['description'] ?? '',
      value: parseNumValue(json['value']),
      currency: json['currency'],
      createdAt: json[Fields.createdAt] != null
          ? tryParseDateTimeValue(json[Fields.createdAt])
          : null,
      date: json['date'] != null ? tryParseDateTimeValue(json['date']) : null,
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
