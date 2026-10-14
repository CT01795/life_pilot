import 'package:flutter/material.dart';
import 'package:life_pilot/subscription/model_subscription_usage.dart';

List<SubscriptionEntitlement> activeSubscriptionEntitlements(
  Iterable<SubscriptionEntitlement> entitlements, {
  required String storagePlan,
  DateTime? now,
}) {
  final referenceTime = now ?? DateTime.now();
  return entitlements
      .where(
        (item) =>
            item.storagePlan == storagePlan &&
            item.endsAt.isAfter(referenceTime),
      )
      .toList(growable: false);
}

DateTime? latestEntitlementEnd(Iterable<SubscriptionEntitlement> entitlements) {
  DateTime? latest;
  for (final entitlement in entitlements) {
    if (latest == null || entitlement.endsAt.isAfter(latest)) {
      latest = entitlement.endsAt;
    }
  }
  return latest;
}

String? formatSubscriptionDate(
  MaterialLocalizations dates,
  DateTime? value, {
  DateTime? now,
}) {
  if (value == null) return null;
  final local = value.toLocal();
  final currentYear = (now ?? DateTime.now()).toLocal().year;
  return local.year == currentYear
      ? dates.formatShortMonthDay(local)
      : dates.formatCompactDate(local);
}
