import 'package:flutter/material.dart';
import 'package:life_pilot/subscription/model_subscription_usage.dart';

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
  final expiries =
      entitlements
          .map((item) => DateUtils.dateOnly(item.endsAt.toLocal()))
          .toSet()
          .toList()
        ..sort();
  return expiries
      .map((expiresAt) {
        final remainingEntitlements = entitlements
            .where(
              (item) =>
                  DateUtils.dateOnly(item.endsAt.toLocal()).isAfter(expiresAt),
            )
            .toList(growable: false);

        // Free and paid quotas are not additive. Use free quotas only after
        // every paid entitlement for the selected storage location expires.
        final remaining = remainingEntitlements.isEmpty
            ? <String, int>{...?fallbackQuotas}
            : <String, int>{};
        for (final entitlement in remainingEntitlements) {
          for (final entry in entitlement.quotas.entries) {
            remaining.update(
              entry.key,
              (value) => value + entry.value,
              ifAbsent: () => entry.value,
            );
          }
        }
        return SubscriptionQuotaExpiryStage(
          expiresAt: expiresAt,
          remainingQuotas: remaining,
          hasRemainingPaidSubscription: remainingEntitlements.isNotEmpty,
        );
      })
      .toList(growable: false);
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
