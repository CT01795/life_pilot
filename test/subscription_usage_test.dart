import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/subscription/model_subscription_usage.dart';

void main() {
  group('SubscriptionUsage', () {
    test('treats the database bigint sentinel as unlimited', () {
      const usage = SubscriptionUsage(
        resource: 'calendar_events',
        used: 42,
        quota: 9223372036854775807,
      );

      expect(usage.isUnlimited, isTrue);
      expect(usage.isFull, isFalse);
    });

    test('keeps an ordinary quota finite', () {
      const usage = SubscriptionUsage(
        resource: 'calendar_events',
        used: 30,
        quota: 30,
      );

      expect(usage.isUnlimited, isFalse);
      expect(usage.isFull, isTrue);
    });
  });
}
