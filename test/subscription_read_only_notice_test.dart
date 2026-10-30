import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/subscription/widgets_subscription_read_only.dart';

void main() {
  for (final language in ['zh', 'en', 'ja', 'ko']) {
    for (final height in [80.0, 600.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          '$language read-only notice fits 320 x $height at scale $scale',
          (tester) async {
            await tester.pumpWidget(
              MaterialApp(
                locale: Locale(language),
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                home: Scaffold(
                  body: Center(
                    child: SizedBox(
                      width: 320,
                      height: height,
                      child: Builder(
                        builder: (context) => MediaQuery(
                          data: MediaQuery.of(
                            context,
                          ).copyWith(textScaler: TextScaler.linear(scale)),
                          child: SubscriptionReadOnlyNotice(
                            message: AppLocalizations.of(
                              context,
                            )!.subscriptionConfigurationMissing,
                            child: const ColoredBox(
                              key: ValueKey('data-page'),
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(
              tester.getSize(find.byKey(const ValueKey('data-page'))).height,
              greaterThanOrEqualTo(height * .7),
            );
          },
        );
      }
    }
  }
}
