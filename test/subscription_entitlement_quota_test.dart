import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/subscription/subscription_entitlement_quota.dart';

void main() {
  test(
    'canonical snapshot values already include the purchased multiplier',
    () {
      expect(
        entitlementSnapshotQuota(
          const {'recommended_events': 40},
          'recommended_events',
          multiplier: 2,
        ),
        40,
      );
    },
  );

  test('legacy recommendation quota applies the entitlement multiplier', () {
    expect(
      entitlementSnapshotQuota(
        const {'recommended_event_quota': 20},
        'recommended_events',
        multiplier: 3,
      ),
      60,
    );
  });

  test('legacy image quota converts multiplied megabytes to bytes', () {
    expect(
      entitlementSnapshotQuota(
        const {'image_megabytes': 10},
        'image_bytes',
        multiplier: 2,
      ),
      20 * 1024 * 1024,
    );
  });

  test('legacy record quota applies multiplier but retention days do not', () {
    expect(
      entitlementSnapshotQuota(
        const {'accounting_quota': 300},
        'accounting_detail',
        multiplier: 2,
      ),
      600,
    );
    expect(
      entitlementSnapshotQuota(
        const {'answer_history_days': 365},
        'answer_history_days',
        multiplier: 2,
      ),
      365,
    );
  });
}
