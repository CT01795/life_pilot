import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/subscription/subscription_entitlement_quota.dart';

void main() {
  test(
    'canonical snapshot values already include the purchased multiplier',
    () {
      expect(
        entitlementSnapshotQuota(const {
          'recommended_events': 40,
        }, 'recommended_events'),
        40,
      );
    },
  );

  test('missing canonical quota is not inferred from retired keys', () {
    expect(
      entitlementSnapshotQuota(const {
        'recommended_event_quota': 20,
      }, 'recommended_events'),
      isNull,
    );
  });

  test('canonical image quota is already stored in bytes', () {
    expect(
      entitlementSnapshotQuota(const {
        'image_bytes': 10 * 1024 * 1024,
      }, 'image_bytes'),
      10 * 1024 * 1024,
    );
  });

  test('canonical record and retention values are read directly', () {
    expect(
      entitlementSnapshotQuota(const {
        'accounting_detail': 600,
      }, 'accounting_detail'),
      600,
    );
    expect(
      entitlementSnapshotQuota(const {
        'answer_history_days': 365,
      }, 'answer_history_days'),
      365,
    );
  });
}
