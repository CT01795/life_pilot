import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/event/model_content_performance.dart';
import 'package:life_pilot/event/page_content_performance.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/record_statistics/model_record_statistics.dart';
import 'package:life_pilot/record_statistics/record_statistics_formats.dart';
import 'package:life_pilot/record_statistics/page_record_statistics.dart';
import 'package:life_pilot/record_statistics/service_record_statistics.dart';
import 'package:life_pilot/record_statistics/widgets_record_totals.dart';
import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:provider/provider.dart';
import 'record_statistics_test.dart' show StatisticsTestAuth;
import 'content_performance_and_event_dates_test.dart'
    show PerformanceTestService;

class _Records extends ServiceRecordStatistics {
  int calls = 0;
  int totalCalls = 0;
  @override
  Future<num> readTotal({
    required String owner,
    required DataStorageLocation storage,
    required String accountId,
    required RecordStatisticsKind kind,
    String? currency,
  }) async {
    totalCalls++;
    return 1234.5678;
  }

  @override
  Future<List<Map<String, dynamic>>> read({
    required String owner,
    required DataStorageLocation storage,
    required String accountId,
    required RecordStatisticsKind kind,
    required DateTime now,
    String? currency,
    bool history = false,
    bool Function()? shouldContinue,
  }) async {
    calls++;
    return [
      {'date': DateTime(now.year - 2).toIso8601String(), 'value': 100},
      {
        'date': DateTime(now.year, now.month - 1).toIso8601String(),
        'value': -200,
      },
      {'date': now.toIso8601String(), 'value': 12.3456},
    ];
  }
}

void main() {
  for (final kind in RecordStatisticsKind.values) {
    for (final monthOnly in [false, true]) {
      testWidgets(
        '$kind monthOnly=$monthOnly uses shared locale formatting without reloading',
        (tester) async {
          tester.view.physicalSize = const Size(320, 700);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final auth = StatisticsTestAuth();
          addTearDown(auth.dispose);
          final records = _Records();
          Widget page(String language) =>
              ChangeNotifierProvider<ControllerAuth>.value(
                value: auth,
                child: MaterialApp(
                  locale: Locale(language),
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: const TextScaler.linear(1.5)),
                    child: child!,
                  ),
                  home: Scaffold(
                    body: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: WidgetsRecordTotals(
                          accountId: 'a',
                          kind: kind,
                          monthOnly: monthOnly,
                          total: -1234.5678,
                          currency: 'TWD',
                          service: records,
                        ),
                      ),
                    ),
                  ),
                ),
              );
          for (final language in ['en', 'zh', 'ja', 'ko', 'en']) {
            final formats = RecordStatisticsFormats.forLocale(language);
            await tester.pumpWidget(page(language));
            await tester.pumpAndSettle();
            final context = tester.element(find.byType(WidgetsRecordTotals));
            final loc = AppLocalizations.of(context)!;
            expect(
              RecordStatisticsFormats.forLocale(loc.localeName),
              same(formats),
            );
            final points = kind == RecordStatisticsKind.points;
            final number = monthOnly ? 12.3456 : -1234.5678;
            final expected =
                '${NumberFormat('#,##0.####', loc.localeName).format(number)} ${points ? loc.pointsUnit : 'TWD'}';
            expect(find.text(expected), findsOneWidget);
            if (!monthOnly) {
              expect(
                tester.widget<Text>(find.text(expected)).style!.color,
                Theme.of(context).colorScheme.error,
              );
            }
            expect(
              find.text(points ? loc.monthlyPoints : loc.monthlyIncomeExpense),
              findsOneWidget,
            );
            expect(
              find.text(points ? loc.todayPoints : loc.todayIncomeExpense),
              monthOnly ? findsNothing : findsOneWidget,
            );
            expect(records.calls, 1);
            expect(records.totalCalls, 0);
            expect(tester.takeException(), isNull);
          }
        },
      );
    }
  }

  for (final kind in RecordStatisticsKind.values) {
    testWidgets(
      '$kind account card uses supplied total and refreshes after changes',
      (tester) async {
        final auth = StatisticsTestAuth();
        addTearDown(auth.dispose);
        final records = _Records();
        Widget page(num total) => ChangeNotifierProvider<ControllerAuth>.value(
          value: auth,
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: WidgetsRecordTotals(
                accountId: 'a',
                kind: kind,
                total: total,
                currency: 'TWD',
                service: records,
              ),
            ),
          ),
        );
        await tester.pumpWidget(page(4321));
        await tester.pumpAndSettle();
        expect(records.calls, 1);
        expect(records.totalCalls, 0);
        expect(find.textContaining('4,321'), findsOneWidget);
        await tester.pumpWidget(page(5432));
        await tester.pumpAndSettle();
        expect(records.calls, 2);
        expect(records.totalCalls, 0);
        expect(find.textContaining('5,432'), findsOneWidget);
        expect(tester.takeException(), null);
      },
    );
  }
  for (final language in ['zh', 'en', 'ja', 'ko']) {
    testWidgets('$language: narrow summary and chart switch have no overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final auth = StatisticsTestAuth();
      addTearDown(auth.dispose);
      final records = _Records();
      await tester.pumpWidget(
        ChangeNotifierProvider<ControllerAuth>.value(
          value: auth,
          child: MaterialApp(
            locale: Locale(language),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: WidgetsRecordTotals(
                    accountId: 'a',
                    accountName: 'My account',
                    kind: RecordStatisticsKind.accounting,
                    currency: 'TWD',
                    service: records,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(WidgetsRecordTotals));
      final loc = AppLocalizations.of(context)!;
      expect(find.text(loc.totalIncomeExpense), findsOneWidget);
      expect(find.text(loc.monthlyIncomeExpense), findsOneWidget);
      expect(find.text(loc.todayIncomeExpense), findsOneWidget);
      expect(find.textContaining('1,234.5678'), findsOneWidget);
      expect(tester.takeException(), null);
      await tester.tap(find.text(loc.recordStatistics));
      await tester.pumpAndSettle();
      expect(find.byType(PageRecordStatistics), findsOneWidget);
      expect(records.calls, 2);
      final currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
      final previousMonth = DateTime(currentMonth.year, currentMonth.month - 1);
      final firstMonth = DateTime(currentMonth.year, currentMonth.month - 11);
      final axes = [
        for (var i = 0; i < 12; i++)
          tester.widget<Text>(
            find.byKey(
              ValueKey((
                'record-axis-month',
                DateTime(currentMonth.year, currentMonth.month - i),
              )),
            ),
          ),
      ];
      expect(
        axes.first.data,
        DateFormat.MMM(loc.localeName).format(currentMonth),
      );
      expect(
        axes.last.data,
        DateFormat.yMMM(loc.localeName).format(firstMonth),
      );
      expect(
        tester
            .getTopLeft(
              find.byKey(ValueKey(('record-axis-month', currentMonth))),
            )
            .dx,
        lessThan(
          tester
              .getTopLeft(
                find.byKey(ValueKey(('record-axis-month', previousMonth))),
              )
              .dx,
        ),
      );
      expect(find.byType(ChoiceChip), findsNWidgets(2));
      await tester.tap(find.text(loc.monthlyNet));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, loc.monthlyNet))
            .selected,
        true,
      );
      expect(tester.takeException(), null);
      final negativeChartValue = tester.widget<Text>(
        find.byKey(ValueKey(('record-chart-value', previousMonth))),
      );
      expect(
        records.calls,
        2,
      ); // Switching projections never redownloads history.
      expect(negativeChartValue.data, '-200');
      final errorColor = Theme.of(
        tester.element(find.byType(PageRecordStatistics)),
      ).colorScheme.error;
      expect(negativeChartValue.style!.color, errorColor);
      await tester.scrollUntilVisible(
        find.byKey(ValueKey(('record-month-row', currentMonth))),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      final latestRow = tester.widget<ListTile>(
        find.byKey(ValueKey(('record-month-row', currentMonth))),
      );
      expect(
        (latestRow.title as Text).data,
        DateFormat.yMMM(loc.localeName).format(currentMonth),
      );
      await tester.scrollUntilVisible(
        find.byKey(ValueKey(('record-month-row', previousMonth))),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      final negativeRow = tester.widget<ListTile>(
        find.byKey(ValueKey(('record-month-row', previousMonth))),
      );
      expect((negativeRow.subtitle as Text).style!.color, errorColor);
      await tester.pumpWidget(const SizedBox());
    });
    testWidgets(
      '$language: author performance link target and counters render on narrow screen',
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
              locale: Locale(language),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: PageContentPerformance(attractions: true, service: service),
            ),
          ),
        );
        service.pending.single.complete(
          ModelContentPerformance([
            {'name': 'My attraction', 'page_views': 1234},
          ]),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('My attraction'),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('My attraction'), findsOneWidget);
        expect(find.text('1,234/1,234'), findsOneWidget);
        expect(find.textContaining('1,234'), findsWidgets);
        expect(tester.takeException(), null);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
