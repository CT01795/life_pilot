import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/subscription/model_subscription_usage.dart';
import 'package:life_pilot/subscription/service_subscription.dart';
import 'package:life_pilot/subscription/subscription_constants.dart';
import 'package:life_pilot/subscription/subscription_entitlement_utils.dart';
import 'package:life_pilot/subscription/subscription_quota_summary.dart';

void main() {
  group('subscription resource visibility', () {
    test('respects optional module access', () {
      expect(
        shouldShowSubscriptionResource(
          SubscriptionResource.pointRecordDetail,
          canUsePoints: false,
          canUseGame: true,
        ),
        isFalse,
      );
      expect(
        shouldShowSubscriptionResource(
          SubscriptionResource.gameQuestions,
          canUsePoints: true,
          canUseGame: false,
        ),
        isFalse,
      );
      expect(
        shouldShowSubscriptionResource(
          SubscriptionResource.calendarEvents,
          canUsePoints: false,
          canUseGame: false,
        ),
        isTrue,
      );
    });
  });

  group('subscription entitlement utilities', () {
    final now = DateTime.utc(2026, 10, 13);
    final entitlements = [
      _entitlement(
        storagePlan: SubscriptionStoragePlan.cloud,
        endsAt: DateTime.utc(2026, 10, 20),
      ),
      _entitlement(
        storagePlan: SubscriptionStoragePlan.cloud,
        endsAt: DateTime.utc(2026, 11, 20),
      ),
      _entitlement(
        storagePlan: SubscriptionStoragePlan.local,
        endsAt: DateTime.utc(2026, 12, 20),
      ),
      _entitlement(
        storagePlan: SubscriptionStoragePlan.cloud,
        endsAt: DateTime.utc(2026, 10, 1),
      ),
    ];

    test('filters by storage plan and expiry', () {
      final active = activeSubscriptionEntitlements(
        entitlements,
        storagePlan: SubscriptionStoragePlan.cloud,
        now: now,
      );

      expect(active, hasLength(2));
      expect(latestEntitlementEnd(active), DateTime.utc(2026, 11, 20));
    });
  });

  group('cumulative subscription quotas', () {
    final cloudVersion = SubscriptionPricingVersion(
      id: 'cloud-v1',
      name: 'Cloud V1',
      storagePlan: SubscriptionStoragePlan.cloud,
      effectiveAt: DateTime.utc(2026),
      quarterlyPriceTwd: 129,
      quotas: const {
        SubscriptionResource.calendarEvents: 30,
        SubscriptionResource.answerHistoryDays: 30,
      },
    );

    test('adds canonical snapshots without applying multiplier twice', () {
      final result = cumulativeSubscriptionQuotas(
        [
          {
            'storage_plan': SubscriptionStoragePlan.cloud,
            'quota_multiplier': 2,
            'entitlement_snapshot': {SubscriptionResource.calendarEvents: 60},
          },
          {
            'storage_plan': SubscriptionStoragePlan.cloud,
            'quota_multiplier': 1,
            'entitlement_snapshot': {SubscriptionResource.calendarEvents: 30},
          },
        ],
        [cloudVersion],
        storagePlan: SubscriptionStoragePlan.cloud,
      );

      expect(result[SubscriptionResource.calendarEvents], 90);
    });

    test('falls back to pricing version for old rows without snapshots', () {
      final result = cumulativeSubscriptionQuotas(
        [
          {
            'storage_plan': SubscriptionStoragePlan.cloud,
            'quota_multiplier': 3,
            'pricing_version_id': cloudVersion.id,
          },
        ],
        [cloudVersion],
        storagePlan: SubscriptionStoragePlan.cloud,
      );

      expect(result[SubscriptionResource.calendarEvents], 90);
      expect(result, isNot(contains(SubscriptionResource.answerHistoryDays)));
    });
  });
}

SubscriptionEntitlement _entitlement({
  required String storagePlan,
  required DateTime endsAt,
}) => SubscriptionEntitlement(
  versionName: 'test',
  effectiveAt: DateTime.utc(2026),
  storagePlan: storagePlan,
  multiplier: 1,
  pricePaidTwd: 129,
  endsAt: endsAt,
  quotas: const {},
);
