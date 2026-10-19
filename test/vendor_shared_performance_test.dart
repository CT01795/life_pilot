import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/event/model_content_performance.dart';
import 'package:life_pilot/event/model_content_performance_period.dart';
import 'package:life_pilot/event/page_content_performance.dart';
import 'package:life_pilot/event/service_content_performance.dart';
import 'package:life_pilot/event/widgets_content_performance_link.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/vendor/service_vendor_account.dart';
import 'package:provider/provider.dart';
import 'record_statistics_test.dart' show StatisticsTestAuth;

class _Performance extends ServiceContentPerformance {
  final calls = <(String, bool, bool)>[];
  @override
  Future<ModelContentPerformance> read({
    required String owner,
    required bool attractions,
    bool includeSubmissionDetails = false,
    ContentPerformancePeriod? period,
    String keyword = '',
    bool statisticsOnly = false,
  }) async {
    calls.add((owner, attractions, includeSubmissionDetails));
    return ModelContentPerformance([
      {
        'id': attractions ? 'place' : 'event',
        'name': attractions ? 'My attraction' : 'My activity',
        'city': 'Taipei',
        'is_approved': attractions,
        'start_date': DateTime.now().toIso8601String(),
        'page_views': attractions ? 20 : 10,
        'card_clicks': attractions ? 3 : 2,
        'registration_clicks': 1,
        'saves': 2,
        'like_counts': 4,
        'dislike_counts': 1,
      },
    ]);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'vendor workspace derives overview and interaction totals from the shared owner-scoped source',
    () async {
      final performance = _Performance();
      final result = await ServiceVendorAccount(
        performance: performance,
      ).fetchMetrics('one@example.com');
      expect(performance.calls, [
        ('one@example.com', false, true),
        ('one@example.com', true, true),
      ]);
      expect(result.published, 1);
      expect(result.pending, 1);
      expect(result.activeEvents, 1);
      expect(result.activeAttractions, 1);
      expect(result.recentSubmissions.length, 2);
      expect(result.performance.totals, {
        'page_views': 30,
        'card_clicks': 5,
        'registration_clicks': 2,
        'saves': 4,
        'like_counts': 8,
        'dislike_counts': 2,
      });
    },
  );
  for (final language in ['zh', 'en', 'ja', 'ko']) {
    for (final attractions in [false, true]) {
      testWidgets(
        '$language vendor link opens correct shared performance page ($attractions)',
        (tester) async {
          tester.view.physicalSize = const Size(320, 700);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final auth = StatisticsTestAuth();
          addTearDown(auth.dispose);
          final performance = _Performance();
          await tester.pumpWidget(
            ChangeNotifierProvider<ControllerAuth>.value(
              value: auth,
              child: MaterialApp(
                locale: Locale(language),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: Wrap(
                    spacing: 12,
                    children: [
                      ContentPerformanceLink(
                        attractions: false,
                        service: performance,
                      ),
                      ContentPerformanceLink(
                        attractions: true,
                        service: performance,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final loc = AppLocalizations.of(
            tester.element(find.byType(Wrap).first),
          )!;
          expect(find.byTooltip(loc.viewPerformance), findsNWidgets(2));
          expect(
            performance.calls,
            isEmpty,
          ); // Statistics are lazy until tapped.
          await tester.tap(
            find.text(
              attractions ? loc.attractionPerformance : loc.activityPerformance,
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<PageContentPerformance>(
                  find.byType(PageContentPerformance),
                )
                .attractions,
            attractions,
          );
          await tester.scrollUntilVisible(
            find.text(attractions ? 'My attraction' : 'My activity'),
            180,
            scrollable: find.byType(Scrollable).first,
          );
          expect(
            find.text(attractions ? 'My attraction' : 'My activity'),
            findsOneWidget,
          );
          expect(performance.calls.single, (
            'one@example.com',
            attractions,
            false,
          ));
          expect(tester.takeException(), null);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
