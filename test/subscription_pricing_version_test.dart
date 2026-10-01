import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/subscription/service_subscription.dart';

void main() {
  group('SubscriptionPricingVersion', () {
    test('cloud plan includes recommendation submission quotas', () {
      final version = SubscriptionPricingVersion.fromJson({
        'id': 'cloud-plan',
        'version_name': 'Cloud 2026-Q4',
        'storage_plan': 'cloud',
        'effective_at': '2026-10-01T00:00:00Z',
        'quarterly_price_twd': 129,
        'calendar_quota': 300,
        'accounting_quota': 300,
        'point_quota': 300,
        'memory_quota': 300,
        'game_question_quota': 500,
        'calendar_share_quota': 5,
        'recommended_event_quota': 42,
        'recommended_attraction_quota': 13,
        'image_megabytes': 17,
        'answer_history_days': 365,
      });

      expect(version.quotas['recommended_events'], 42);
      expect(version.quotas['recommended_attractions'], 13);
      expect(version.quotas['image_bytes'], 17 * 1024 * 1024);
    });

    test('local plan does not display cloud recommendation quotas', () {
      final version = SubscriptionPricingVersion.fromJson({
        'id': 'local-plan',
        'version_name': 'Local 2026-Q4',
        'storage_plan': 'local',
        'effective_at': '2026-10-01T00:00:00Z',
        'quarterly_price_twd': 129,
      });

      expect(version.quotas.containsKey('recommended_events'), isFalse);
      expect(version.quotas.containsKey('recommended_attractions'), isFalse);
    });

    test('free cloud plan reads recommendation quotas from its version', () {
      final version = SubscriptionPricingVersion.fromJson({
        'id': 'free-cloud-plan',
        'version_name': 'Cloud Free',
        'storage_plan': 'cloud',
        'effective_at': '2026-10-01T00:00:00Z',
        'quarterly_price_twd': 0,
        'recommended_event_quota': 7,
        'recommended_attraction_quota': 3,
      });

      expect(version.quotas['recommended_events'], 7);
      expect(version.quotas['recommended_attractions'], 3);
    });
  });
}
