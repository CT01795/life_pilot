import 'package:life_pilot/utils/value_parser.dart';

class SubscriptionCleanupPreview {
  const SubscriptionCleanupPreview({
    required this.email,
    required this.resource,
    required this.used,
    required this.quota,
    required this.excess,
    this.graceEndsAt,
  });
  final String email, resource;
  final int used, quota, excess;
  final DateTime? graceEndsAt;

  factory SubscriptionCleanupPreview.fromJson(Map<String, dynamic> json) =>
      SubscriptionCleanupPreview(
        email: parseStringValue(json['target_email']),
        resource: parseStringValue(json['resource']),
        used: parseIntValue(json['used']),
        quota: parseIntValue(json['quota']),
        excess: parseIntValue(json['excess']),
        graceEndsAt: tryParseDateTimeValue(json['grace_ends_at']),
      );
}
