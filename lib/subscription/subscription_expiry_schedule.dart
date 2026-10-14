import 'package:flutter/material.dart';
import 'package:life_pilot/subscription/model_subscription_usage.dart';
import 'package:life_pilot/subscription/subscription_quota_accumulator.dart';

enum SubscriptionExpiryReminderKind { partial, all }

class SubscriptionQuotaExpiryStage {
  const SubscriptionQuotaExpiryStage({
    required this.expiresAt,
    required this.remainingQuotas,
    required this.hasRemainingPaidSubscription,
  });

  final DateTime expiresAt;
  final Map<String, int> remainingQuotas;
  final bool hasRemainingPaidSubscription;
}

class SubscriptionExpiryReminder {
  const SubscriptionExpiryReminder({
    required this.kind,
    required this.days,
    required this.stage,
  });

  final SubscriptionExpiryReminderKind kind;
  final int days;
  final SubscriptionQuotaExpiryStage stage;
}

List<SubscriptionQuotaExpiryStage> buildSubscriptionQuotaExpiryStages(
  List<SubscriptionEntitlement> entitlements, {
  Map<String, int>? fallbackQuotas,
}) {
  final byExpiry = <DateTime, List<SubscriptionEntitlement>>{};
  for (final entitlement in entitlements) {
    final day = DateUtils.dateOnly(entitlement.endsAt.toLocal());
    byExpiry.putIfAbsent(day, () => []).add(entitlement);
  }
  final expiries = byExpiry.keys.toList()..sort();
  final remaining = <String, int>{};
  final stages = <SubscriptionQuotaExpiryStage>[];
  var hasRemainingPaidSubscription = false;
  // Accumulate later groups only after capturing the current group's stage.
  // All subscriptions ending on the same local day expire together.
  for (final expiresAt in expiries.reversed) {
    stages.add(
      SubscriptionQuotaExpiryStage(
        expiresAt: expiresAt,
        remainingQuotas: hasRemainingPaidSubscription
            ? Map<String, int>.from(remaining)
            : <String, int>{...?fallbackQuotas},
        hasRemainingPaidSubscription: hasRemainingPaidSubscription,
      ),
    );
    for (final entitlement in byExpiry[expiresAt]!) {
      addSubscriptionQuotas(remaining, entitlement.quotas);
    }
    hasRemainingPaidSubscription = true;
  }
  return stages.reversed.toList(growable: false);
}

SubscriptionExpiryReminder? buildSubscriptionExpiryReminder(
  List<SubscriptionEntitlement> entitlements, {
  required DateTime now,
  required Map<String, int> fallbackQuotas,
  int reminderDays = 15,
}) {
  final active = entitlements
      .where((item) => item.endsAt.isAfter(now))
      .toList(growable: false);
  if (active.isEmpty) return null;

  final stages = buildSubscriptionQuotaExpiryStages(
    active,
    fallbackQuotas: fallbackQuotas,
  );
  if (stages.isEmpty) return null;

  final today = DateUtils.dateOnly(now.toLocal());
  int daysUntil(DateTime date) => date.difference(today).inDays;
  final firstStage = stages.first;
  final firstDays = daysUntil(firstStage.expiresAt);
  if (firstDays < 0 || firstDays > reminderDays) return null;

  final lastStage = stages.last;
  final lastDays = daysUntil(lastStage.expiresAt);
  if (lastDays <= reminderDays) {
    return SubscriptionExpiryReminder(
      kind: SubscriptionExpiryReminderKind.all,
      days: lastDays,
      stage: lastStage,
    );
  }

  return SubscriptionExpiryReminder(
    kind: SubscriptionExpiryReminderKind.partial,
    days: firstDays,
    stage: firstStage,
  );
}
