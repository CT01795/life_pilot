import 'package:life_pilot/subscription/service_subscription.dart';
import 'package:life_pilot/subscription/subscription_constants.dart';
import 'package:life_pilot/subscription/subscription_entitlement_quota.dart';
import 'package:life_pilot/subscription/subscription_quota_accumulator.dart';
import 'package:life_pilot/utils/value_parser.dart';

Map<String, int> cumulativeSubscriptionQuotas(
  Iterable<Map<String, dynamic>> entitlements,
  Iterable<SubscriptionPricingVersion> versions, {
  required String storagePlan,
}) {
  final versionsById = {for (final version in versions) version.id: version};
  final totals = <String, int>{};
  for (final entitlement in entitlements) {
    if (parseStringValue(entitlement['storage_plan']) != storagePlan) continue;
    final snapshot = Map<String, dynamic>.from(
      entitlement['entitlement_snapshot'] as Map? ?? const {},
    );
    final multiplier = parseIntValue(
      entitlement['quota_multiplier'],
      fallback: 1,
    ).clamp(1, 1000);
    if (snapshot.isNotEmpty) {
      for (final resource in SubscriptionResource.visibleQuotaResources) {
        final value = entitlementSnapshotQuota(
          snapshot,
          resource,
          multiplier: multiplier,
        );
        if (value == null) continue;
        addSubscriptionQuota(totals, resource, value);
      }
      continue;
    }

    final version =
        versionsById[parseStringValue(entitlement['pricing_version_id'])];
    if (version == null) continue;
    for (final entry in version.quotas.entries) {
      if (entry.key == SubscriptionResource.answerHistoryDays) continue;
      final value = entry.value * multiplier;
      addSubscriptionQuota(totals, entry.key, value);
    }
  }
  return {
    for (final resource in SubscriptionResource.visibleQuotaResources)
      if (totals.containsKey(resource)) resource: totals[resource]!,
  };
}
