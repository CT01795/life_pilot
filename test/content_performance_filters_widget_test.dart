import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/event/model_content_performance.dart';
import 'package:life_pilot/event/page_content_performance.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'record_statistics_test.dart' show StatisticsTestAuth;
import 'content_performance_and_event_dates_test.dart'
    show PerformanceTestService;

void main() {
  for (final locale in ['zh', 'en', 'ja', 'ko']) {
    testWidgets(
      '$locale: expiry month and title/city search work together and remain usable with empty results',
      (tester) async {
        tester.view.physicalSize = const Size(320, 700);
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
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.5)),
                child: child!,
              ),
              home: PageContentPerformance(
                attractions: false,
                service: service,
              ),
            ),
          ),
        );
        service.pending[0].complete(ModelContentPerformance([]));
        await tester.pumpAndSettle();
        final loc = AppLocalizations.of(
          tester.element(find.byType(PageContentPerformance)),
        )!;
        final emptyBeforeTyping = tester.widget<Text>(
          find.text(loc.statisticsNoData),
        );
        expect(service.periods.single!.month, null);
        expect(find.text(loc.performanceHideZeroHint), findsOneWidget);
        await tester.enterText(find.byType(TextField), '新北');
        await tester.pump();
        expect(
          identical(
            emptyBeforeTyping,
            tester.widget<Text>(find.text(loc.statisticsNoData)),
          ),
          true,
        );
        expect(
          service.pending.length,
          1,
        ); // Typing alone does not spam requests.
        await tester.tap(find.text(loc.performanceExpiryMonth));
        await tester.pumpAndSettle();
        final now = DateTime.now();
        final target = DateTime(now.year, now.month - 3);
        if (target.year != now.year) {
          await tester.tap(
            find.descendant(
              of: find.byType(AlertDialog),
              matching: find.byIcon(Icons.chevron_left),
            ),
          );
          await tester.pumpAndSettle();
        }
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text(DateFormat.MMM(loc.localeName).format(target)),
          ),
        );
        await tester.pump();
        expect(service.periods.last!.month, target);
        expect(service.keywords.last, '新北');
        service.pending.last.complete(ModelContentPerformance([]));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text(loc.statisticsNoData),
          100,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text(loc.statisticsNoData), findsOneWidget);
        await tester.ensureVisible(find.byType(TextField));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Festival');
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pump();
        expect(service.periods.last!.month, target);
        expect(service.keywords.last, 'Festival');
        service.pending.last.complete(ModelContentPerformance([]));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text(loc.performanceActive));
        await tester.pumpAndSettle();
        await tester.tap(find.text(loc.performanceActive));
        await tester.pump();
        expect(service.periods.last!.month, null);
        expect(service.keywords.last, 'Festival');
        service.pending.last.complete(ModelContentPerformance([]));
        await tester.pumpAndSettle();
        expect(tester.takeException(), null);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
