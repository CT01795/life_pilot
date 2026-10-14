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

  test('subscriptions ending on the same day expire as one group', () {
    final stages = buildSubscriptionQuotaExpiryStages(
      [
        _entitlement(endsAt: DateTime(2026, 10, 20, 8), calendarQuota: 100),
        _entitlement(endsAt: DateTime(2026, 10, 20, 23), calendarQuota: 300),
      ],
      fallbackQuotas: const {'calendar_events': 30},
    );
    expect(stages, hasLength(1));
    expect(stages.single.remainingQuotas, {'calendar_events': 30});
    expect(stages.single.hasRemainingPaidSubscription, isFalse);
  });

  test('unsorted subscriptions produce independent remaining quota stages', () {
    final fallback = {'calendar_events': 30};
    final stages = buildSubscriptionQuotaExpiryStages([
      _entitlement(endsAt: DateTime(2026, 12, 20), calendarQuota: 500),
      _entitlement(endsAt: DateTime(2026, 10, 20), calendarQuota: 100),
      _entitlement(endsAt: DateTime(2026, 11, 20), calendarQuota: 300),
    ], fallbackQuotas: fallback);
    expect(stages.map((stage) => stage.remainingQuotas['calendar_events']), [
      800,
      500,
      30,
    ]);
    expect(stages.map((stage) => stage.expiresAt.month), [10, 11, 12]);
    stages.first.remainingQuotas['calendar_events'] = 0;
    stages.last.remainingQuotas['calendar_events'] = 0;
    expect(stages[1].remainingQuotas['calendar_events'], 500);
    expect(fallback['calendar_events'], 30);
  });

  test('paid subscriptions with zero quota never receive free quotas', () {
    final stages = buildSubscriptionQuotaExpiryStages(
      [
        _entitlement(endsAt: DateTime(2026, 10, 20), calendarQuota: 100),
        _entitlement(endsAt: DateTime(2026, 11, 20), calendarQuota: 0),
      ],
      fallbackQuotas: const {'calendar_events': 30},
    );
    expect(stages.first.remainingQuotas['calendar_events'], 0);
    expect(stages.first.hasRemainingPaidSubscription, isTrue);
  });

  test('local expiry can fall back to no writable quota', () {
    final stages = buildSubscriptionQuotaExpiryStages(
      [_entitlement(endsAt: DateTime(2026, 10, 20), calendarQuota: 100)],
      fallbackQuotas: const {'calendar_events': 0},
    );
    expect(stages.single.remainingQuotas['calendar_events'], 0);
    expect(buildSubscriptionQuotaExpiryStages([]), isEmpty);
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
