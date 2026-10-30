import 'package:life_pilot/utils/text_normalization.dart';
import 'package:life_pilot/utils/value_parser.dart';

class QuotaFreePeriod {
  const QuotaFreePeriod({
    required this.id,
    required this.name,
    required this.startsAt,
    required this.endsAt,
    required this.enabled,
    required this.isActive,
    this.reminderDays,
    this.targetAccounts = const [],
  });
  final String id, name;
  final DateTime startsAt, endsAt;
  final bool enabled, isActive;
  final int? reminderDays;
  final List<String> targetAccounts;
  factory QuotaFreePeriod.fromJson(Map<String, dynamic> json) =>
      QuotaFreePeriod(
        id: parseStringValue(json['period_id']),
        name: parseStringValue(json['period_name']),
        startsAt:
            tryParseDateTimeValue(json['starts_at'], toLocal: true) ??
            DateTime.now(),
        endsAt:
            tryParseDateTimeValue(json['ends_at'], toLocal: true) ??
            DateTime.now(),
        enabled: json['enabled'] == true,
        isActive: json['is_active'] == true,
        reminderDays: tryParseIntValue(json['reminder_days']),
        targetAccounts: List.unmodifiable(
          (json['target_accounts'] as List? ?? const [])
              .map(normalizeText)
              .where((value) => value.isNotEmpty),
        ),
      );
}
