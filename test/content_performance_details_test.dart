import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/event/model_content_performance.dart';
import 'package:life_pilot/event/page_content_performance.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'record_statistics_test.dart' show StatisticsTestAuth;
import 'content_performance_and_event_dates_test.dart'
    show PerformanceTestService;

void main() {
  test(
    'end display threshold does not change actual expiration or sorting',
    () {
      for (final year in [2099, 2100, 2101]) {
        final item = ContentPerformanceItem({
          'start_date': '2026-10-19T00:00:00',
          'end_date': '$year-01-01T00:00:00',
        });
        expect(item.starts, DateTime(2026, 10, 19));
        expect(item.ends, DateTime(year));
        expect(item.expires, DateTime(year));
        expect(item.visibleEndDate, year < 2100 ? DateTime(year) : null);
      }
      final noEnd = ContentPerformanceItem({'start_date': '2026-10-19'});
      expect(noEnd.expires, DateTime(2026, 10, 19));
      expect(
        noEnd.visibleEndDate,
        null,
      ); // Never invent an end date for display.
    },
  );
  for (final attractions in [false, true]) {
    for (final locale in ['zh', 'en', 'ja', 'ko']) {
      testWidgets(
        '$locale $attractions: dates and only nonzero overview/detail metrics',
        (tester) async {
          tester.view.physicalSize = const Size(600, 1500);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final auth = StatisticsTestAuth();
          addTearDown(auth.dispose);
          final service = PerformanceTestService();
          await tester.pumpWidget(
            ChangeNotifierProvider<ControllerAuth>.value(
              value: auth,
              child: MaterialApp(
                locale: Locale(locale),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: PageContentPerformance(
                  attractions: attractions,
                  service: service,
                ),
              ),
            ),
          );
          service.pending.single.complete(
            ModelContentPerformance([
              {
                'id': 'normal',
                'name': 'Normal',
                'city': 'A',
                'start_date': '2026-10-19',
                'end_date': '2026-10-20',
                'card_clicks': 2,
              },
              {
                'id': 'sentinel',
                'name': 'Sentinel',
                'city': 'B',
                'start_date': '2026-10-19',
                'end_date': '2100-01-01',
                'like_counts': 1,
              },
            ]),
          );
          await tester.pumpAndSettle();
          final loc = AppLocalizations.of(
            tester.element(find.byType(PageContentPerformance)),
          )!;
          final date = DateFormat.yMd(loc.localeName);
          expect(
            find.text(
              '${loc.startDate} · ${date.format(DateTime(2026, 10, 19))}',
            ),
            findsNWidgets(2),
          );
          expect(
            find.text(
              '${loc.endDate} · ${date.format(DateTime(2026, 10, 20))}',
            ),
            findsOneWidget,
          );
          expect(find.textContaining('2100'), findsNothing);
          for (final label in [
            loc.vendorAnalyticsPageViews,
            loc.vendorAnalyticsRegistrationClicks,
            loc.vendorAnalyticsSaves,
            loc.vendorAnalyticsDislikes,
          ]) {
            expect(find.text(label), findsNothing);
          }
          expect(find.text(loc.vendorAnalyticsCardClicks), findsOneWidget);
          expect(find.text(loc.vendorAnalyticsLikes), findsOneWidget);
          await tester.ensureVisible(find.text('Normal'));
          await tester.tap(find.text('Normal'));
          await tester.pumpAndSettle();
          expect(find.text(loc.vendorAnalyticsCardClicks), findsNWidgets(2));
          expect(
            find.text(loc.vendorAnalyticsLikes),
            findsOneWidget,
          ); // Not shown in Normal.
          await tester.ensureVisible(find.text('Sentinel'));
          await tester.tap(find.text('Sentinel'));
          await tester.pumpAndSettle();
          expect(find.text(loc.vendorAnalyticsLikes), findsNWidgets(2));
          expect(tester.takeException(), null);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
