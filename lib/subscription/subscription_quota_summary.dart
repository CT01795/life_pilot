import 'package:life_pilot/subscription/subscription_constants.dart';
import 'package:life_pilot/subscription/subscription_entitlement_quota.dart';
import 'package:life_pilot/subscription/subscription_quota_accumulator.dart';
import 'package:life_pilot/utils/value_parser.dart';

Map<String, int> cumulativeSubscriptionQuotas(
  Iterable<Map<String, dynamic>> entitlements, {
  required String storagePlan,
}) {
  final totals = <String, int>{};
  for (final entitlement in entitlements) {
    if (parseStringValue(entitlement['storage_plan']) != storagePlan) continue;
    final snapshot = Map<String, dynamic>.from(
      entitlement['entitlement_snapshot'] as Map? ?? const {},
    );
    for (final resource in SubscriptionResource.visibleQuotaResources) {
      final value = entitlementSnapshotQuota(snapshot, resource);
      if (value == null) continue;
      addSubscriptionQuota(totals, resource, value);
    }
  }
  return {
    for (final resource in SubscriptionResource.visibleQuotaResources)
      if (totals.containsKey(resource)) resource: totals[resource]!,
  };
}
