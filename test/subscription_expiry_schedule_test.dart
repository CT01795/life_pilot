import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/subscription/model_subscription_usage.dart';
import 'package:life_pilot/subscription/subscription_expiry_schedule.dart';

void main() {
  final now = DateTime(2026, 10, 13, 10);

  test('partial expiry reports quota left by later subscriptions', () {
    final reminder = buildSubscriptionExpiryReminder(
      [
        _entitlement(endsAt: DateTime(2026, 10, 20), calendarQuota: 100),
        _entitlement(endsAt: DateTime(2026, 12, 20), calendarQuota: 300),
      ],
      now: now,
      fallbackQuotas: const {'calendar_events': 30},
    );

    expect(reminder?.kind, SubscriptionExpiryReminderKind.partial);
    expect(reminder?.days, 7);
    expect(reminder?.stage.remainingQuotas['calendar_events'], 300);
    expect(reminder?.stage.hasRemainingPaidSubscription, isTrue);
  });

  test('all expiry warning uses the last active subscription date', () {
    final reminder = buildSubscriptionExpiryReminder(
      [
        _entitlement(endsAt: DateTime(2026, 10, 20), calendarQuota: 100),
        _entitlement(endsAt: DateTime(2026, 10, 25), calendarQuota: 300),
      ],
      now: now,
      fallbackQuotas: const {'calendar_events': 30},
    );

    expect(reminder?.kind, SubscriptionExpiryReminderKind.all);
    expect(reminder?.days, 12);
    expect(reminder?.stage.remainingQuotas['calendar_events'], 30);
    expect(reminder?.stage.hasRemainingPaidSubscription, isFalse);
  });

  test('does not warn when the first expiry is more than 15 days away', () {
    final reminder = buildSubscriptionExpiryReminder(
      [_entitlement(endsAt: DateTime(2026, 11, 1), calendarQuota: 100)],
      now: now,
      fallbackQuotas: const {'calendar_events': 30},
    );

    expect(reminder, isNull);
  });
}

SubscriptionEntitlement _entitlement({
  required DateTime endsAt,
  required int calendarQuota,
}) => SubscriptionEntitlement(
  versionName: 'test',
  effectiveAt: DateTime(2026, 10, 1),
  storagePlan: 'cloud',
  multiplier: 1,
  pricePaidTwd: 129,
  endsAt: endsAt,
  quotas: {'calendar_events': calendarQuota},
);
