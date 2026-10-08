import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/l10n/app_localizations_zh.dart';
import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:life_pilot/local_storage/widgets_data_storage_choice.dart';
import 'package:life_pilot/subscription/model_subscription_usage.dart';
import 'package:life_pilot/subscription/widgets_subscription_usage.dart';

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

    test('treats a negative local quota as not limited', () {
      const usage = SubscriptionUsage(
        resource: 'memory_trace',
        used: 1200,
        quota: -1,
      );

      expect(usage.isUnlimited, isTrue);
      expect(usage.isFull, isFalse);
    });

    test('explains that inactive local subscriptions are read only', () {
      final loc = AppLocalizationsZh();

      final message = subscriptionErrorMessage(
        loc,
        StateError('local_subscription_expired_read_only'),
      );

      expect(message, loc.localSubscriptionRequiredForChanges);
      expect(message, contains('僅可查看或刪除'));
    });
  });

  testWidgets('promotion-only local access clearly explains its limitation', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: DataStorageChoice(
            value: DataStorageLocation.local,
            onChanged: null,
            localSubscriptionActive: false,
            localPromotionAccess: true,
          ),
        ),
      ),
    );

    expect(find.textContaining('活動期間可暫時使用'), findsOneWidget);
    expect(find.textContaining('活動結束後僅可查詢或刪除'), findsOneWidget);
  });
}
