import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/event/model_content_performance.dart';
import 'package:life_pilot/event/content_performance_metric_presentation.dart';
import 'package:life_pilot/event/widgets_content_performance_card.dart';
import 'package:life_pilot/event/widgets_content_performance_overview.dart';
import 'package:life_pilot/l10n/app_localizations.dart';

void main() {
  test(
    'shares use the same metric total, not item count or another metric',
    () {
      final model = ModelContentPerformance([
        {'card_clicks': 25, 'like_counts': 2},
        {'card_clicks': 75, 'like_counts': 8},
      ]);
      expect(
        model.shareFor(
          model.items.first,
          ContentPerformanceMetric.navigationClicks,
        ),
        0.25,
      );
      expect(
        model.shareFor(model.items.first, ContentPerformanceMetric.likes),
        0.2,
      );
      expect(
        model.shareFor(model.items.first, ContentPerformanceMetric.dislikes),
        0,
      );
      expect(
        ModelContentPerformance([]).shareFor(
          model.items.first,
          ContentPerformanceMetric.navigationClicks,
        ),
        0,
      );
    },
  );
  test(
    'typed metrics preserve the database order and immutable column contract',
    () {
      expect(contentPerformanceColumns, [
        'page_views',
        'card_clicks',
        'registration_clicks',
        'saves',
        'like_counts',
        'dislike_counts',
      ]);
      expect(
        contentPerformanceColumns.toSet(),
        hasLength(ContentPerformanceMetric.values.length),
      );
      expect(() => contentPerformanceColumns.clear(), throwsUnsupportedError);
      final row = {
        for (final metric in ContentPerformanceMetric.values)
          metric.column: metric.index + 1,
      };
      final model = ModelContentPerformance([row]);
      for (final metric in ContentPerformanceMetric.values) {
        expect(model.totalFor(metric), metric.index + 1);
        expect(model.items.single.countFor(metric), metric.index + 1);
      }
    },
  );
  for (final language in ['zh', 'en', 'ja', 'ko']) {
    testWidgets(
      '$language: default-open ratios, tooltip and filtered totals without bars',
      (tester) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final model = ModelContentPerformance([
          {'id': 'a', 'name': 'Item', 'card_clicks': 25},
          {'id': 'b', 'name': 'Other', 'card_clicks': 75},
        ]);
        Widget app(ModelContentPerformance data) => MaterialApp(
          locale: Locale(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: WidgetsContentPerformanceCard(
                item: data.items.first,
                performance: data,
                expansionKey: const ValueKey('ratio'),
              ),
            ),
          ),
        );
        await tester.pumpWidget(app(model));
        await tester.pumpAndSettle();
        expect(find.text('25/100'), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsNothing);
        final loc = AppLocalizations.of(
          tester.element(find.byType(WidgetsContentPerformanceCard)),
        )!;
        final message = loc.performanceMetricShareLabel(
          loc.vendorAnalyticsCardClicks,
        );
        expect(find.byTooltip(message), findsOneWidget);
        expect(find.text(loc.vendorAnalyticsCardClicks), findsNothing);
        await tester.longPress(find.byIcon(Icons.directions_outlined));
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.text(message), findsOneWidget);
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
        await tester.longPress(find.byIcon(Icons.info_outline));
        await tester.pump(const Duration(milliseconds: 200));
        expect(
          find.text(loc.performanceMetricShareExplanation),
          findsOneWidget,
        );
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
        await tester.pumpWidget(
          app(ModelContentPerformance([model.rows.first])),
        );
        await tester.pumpAndSettle();
        expect(find.text('25/25'), findsOneWidget);
        expect(find.byIcon(Icons.thumb_down_alt_outlined), findsNothing);
        await tester.tap(find.text('Item'));
        await tester.pumpAndSettle();
        expect(find.text('25/25'), findsNothing);
        await tester.tap(find.text('Item'));
        await tester.pumpAndSettle();
        expect(find.text('25/25'), findsOneWidget);
        expect(tester.takeException(), null);
        await tester.pumpWidget(const SizedBox());
      },
    );
    for (final enlarged in [false, true]) {
      testWidgets(
        '$language: four indicators ${enlarged ? 'wrap for large values and fonts' : 'fit the same row'}',
        (tester) async {
          tester.view.physicalSize = const Size(320, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final metrics = ContentPerformanceMetric.values.take(4).toList();
          final model = ModelContentPerformance([
            {
              'id': 'a',
              'name': 'Item',
              'end_date': '2100-01-01',
              for (final metric in metrics)
                metric.column: enlarged ? 9999999 : metric.index + 1,
            },
          ]);
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(language),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(enlarged ? 1.5 : 1)),
                child: child!,
              ),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: WidgetsContentPerformanceCard(
                      item: model.items.first,
                      performance: model,
                      expansionKey: const ValueKey('layout'),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final positions = [
            for (final metric in metrics)
              tester.getTopLeft(
                find.byKey(ValueKey(('performance-metric', 'a', metric))),
              ),
          ];
          for (final metric in metrics) {
            expect(find.byIcon(metric.icon), findsOneWidget);
            final loc = AppLocalizations.of(
              tester.element(find.byType(WidgetsContentPerformanceCard)),
            )!;
            expect(
              find.byTooltip(
                loc.performanceMetricShareLabel(metric.label(loc)),
              ),
              findsOneWidget,
            );
          }
          if (enlarged) {
            expect(positions[1].dy, greaterThan(positions[0].dy));
            expect(find.text('9,999,999/9,999,999'), findsNWidgets(4));
          } else {
            expect(
              positions.every(
                (point) => (point.dy - positions.first.dy).abs() < 1,
              ),
              true,
              reason: 'Metric positions: $positions',
            );
            expect(positions.last.dx, greaterThan(positions.first.dx));
          }
          expect(find.textContaining('2100'), findsNothing);
          expect(find.byType(LinearProgressIndicator), findsNothing);
          expect(tester.takeException(), null);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
    testWidgets(
      '$language: overview retains its icon mapping and hides zero metrics',
      (tester) async {
        final model = ModelContentPerformance([
          {'card_clicks': 1234},
        ]);
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: WidgetsContentPerformanceOverview(data: model),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final loc = AppLocalizations.of(
          tester.element(find.byType(WidgetsContentPerformanceOverview)),
        )!;
        expect(find.text(loc.vendorAnalyticsCardClicks), findsOneWidget);
        expect(find.byIcon(Icons.directions_outlined), findsOneWidget);
        expect(find.text('1,234'), findsOneWidget);
        expect(find.text(loc.vendorAnalyticsLikes), findsNothing);
        expect(tester.takeException(), null);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
