import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/widgets/widgets_record_explorer.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final bottom in [24.0, 48.0]) {
      testWidgets(
        '$platform bottom=$bottom: safe area cannot push scrollbar onto values',
        (tester) async {
          tester.view.physicalSize = const Size(360, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final search = TextEditingController();
          addTearDown(search.dispose);
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: platform),
              home: Scaffold(
                body: MediaQuery(
                  data: MediaQueryData(
                    padding: EdgeInsets.only(bottom: bottom),
                    viewPadding: EdgeInsets.only(bottom: bottom),
                    textScaler: const TextScaler.linear(1.6),
                  ),
                  child: SingleChildScrollView(
                    key: const ValueKey('page-scroll'),
                    child: WidgetsRecordExplorer(
                      searchController: search,
                      searchHint: 'Search',
                      clearTooltip: 'Clear',
                      categories: [
                        for (var i = 0; i < 6; i++)
                          RecordCategoryFilterOption(
                            value: '$i',
                            label: 'Category $i',
                          ),
                      ],
                      selectedCategory: null,
                      onSearchChanged: (_) {},
                      onCategorySelected: (_) {},
                      metrics: const [
                        RecordExplorerMetric(
                          icon: Icons.add,
                          label: 'Income',
                          value: '1,234',
                          color: Colors.green,
                        ),
                        RecordExplorerMetric(
                          icon: Icons.remove,
                          label: 'Expense',
                          value: '234',
                          color: Colors.red,
                        ),
                        RecordExplorerMetric(
                          icon: Icons.swap_vert,
                          label: 'Net',
                          value: '1,000',
                          color: Colors.blue,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            MediaQuery.paddingOf(
              tester.element(find.byKey(const ValueKey('page-scroll'))),
            ).bottom,
            bottom,
          );
          final bars = find.descendant(
            of: find.byType(WidgetsRecordExplorer),
            matching: find.byType(Scrollbar),
          );
          expect(bars, findsNWidgets(2));
          final painters = tester
              .widgetList<CustomPaint>(
                find.descendant(
                  of: find.byType(WidgetsRecordExplorer),
                  matching: find.byType(CustomPaint),
                ),
              )
              .map((paint) => paint.foregroundPainter)
              .whereType<ScrollbarPainter>()
              .toList();
          expect(painters.length, 2);
          for (final painter in painters) {
            expect(painter.padding.resolve(TextDirection.ltr).bottom, 0);
          }
          final metricBar = bars.last;
          final viewport = find.descendant(
            of: metricBar,
            matching: find.byType(SingleChildScrollView),
          );
          expect(
            tester.getBottomLeft(metricBar).dy -
                tester.getBottomLeft(viewport).dy,
            closeTo(16, 0.01),
          );
          expect(
            tester.getBottomLeft(find.text('1,234')).dy,
            lessThan(tester.getBottomLeft(metricBar).dy - 8),
          );
          expect(tester.takeException(), null);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
  for (final language in ['zh', 'en', 'ja', 'ko']) {
    for (final points in [false, true]) {
      testWidgets(
        '$language points=$points: labels and values precede a separate scrollbar lane',
        (tester) async {
          tester.view.physicalSize = const Size(320, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final loc = await AppLocalizations.delegate.load(Locale(language));
          final search = TextEditingController();
          addTearDown(search.dispose);
          final labels = [
            points ? loc.eventPointIncrease : loc.eventIncome,
            points ? loc.eventPointDecrease : loc.eventExpense,
            loc.recordNetChange,
          ];
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: TargetPlatform.windows),
              home: Scaffold(
                body: MediaQuery(
                  data: const MediaQueryData(
                    textScaler: TextScaler.linear(2),
                    padding: EdgeInsets.only(bottom: 40),
                  ),
                  child: SingleChildScrollView(
                    child: WidgetsRecordExplorer(
                      searchController: search,
                      searchHint: loc.recordSearchHint,
                      clearTooltip: loc.clear,
                      categories: [
                        for (var i = 0; i < 8; i++)
                          RecordCategoryFilterOption(
                            value: '$i',
                            label: '${loc.recordAllCategories} $i',
                          ),
                      ],
                      selectedCategory: null,
                      onSearchChanged: (_) {},
                      onCategorySelected: (_) {},
                      metrics: [
                        for (var i = 0; i < labels.length; i++)
                          RecordExplorerMetric(
                            icon: Icons.add,
                            label: labels[i],
                            value: '${i + 1},234.5678',
                            color: Colors.blue,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final explorer = find.byType(WidgetsRecordExplorer);
          final bars = find.descendant(
            of: explorer,
            matching: find.byType(Scrollbar),
          );
          expect(
            bars,
            findsNWidgets(2),
          ); // No additional desktop auto-scrollbars.
          final metricsBar = bars.last;
          final viewport = find.descendant(
            of: metricsBar,
            matching: find.byType(SingleChildScrollView),
          );
          expect(viewport, findsOneWidget);
          final barBottom = tester.getBottomLeft(metricsBar).dy;
          final viewportBottom = tester.getBottomLeft(viewport).dy;
          expect(barBottom - viewportBottom, closeTo(16, 0.01));
          for (final bar in bars.evaluate()) {
            expect(MediaQuery.paddingOf(bar).bottom, 0);
          }
          for (var i = 0; i < labels.length; i++) {
            final label = find.text(labels[i]);
            final value = find.text('${i + 1},234.5678');
            expect(
              tester.getBottomLeft(label).dy,
              lessThanOrEqualTo(tester.getTopLeft(value).dy),
            );
            expect(
              tester.getBottomLeft(value).dy,
              lessThanOrEqualTo(viewportBottom),
            );
          }
          final scroll = tester
              .widget<SingleChildScrollView>(viewport)
              .controller!;
          expect(scroll.position.maxScrollExtent, greaterThan(0));
          await tester.drag(viewport, const Offset(-200, 0));
          await tester.pumpAndSettle();
          expect(scroll.offset, greaterThan(0));
          expect(tester.takeException(), null);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }

  for (final width in [600.0, 1000.0]) {
    testWidgets('wide $width: metrics need no extra scrollbar', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final search = TextEditingController();
      addTearDown(search.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.windows),
          home: Scaffold(
            body: WidgetsRecordExplorer(
              searchController: search,
              searchHint: 'Search',
              clearTooltip: 'Clear',
              categories: const [
                RecordCategoryFilterOption(value: null, label: 'All'),
              ],
              selectedCategory: null,
              onSearchChanged: (_) {},
              onCategorySelected: (_) {},
              metrics: const [
                RecordExplorerMetric(
                  icon: Icons.add,
                  label: 'Income',
                  value: '1,234',
                  color: Colors.green,
                ),
                RecordExplorerMetric(
                  icon: Icons.remove,
                  label: 'Expense',
                  value: '234',
                  color: Colors.red,
                ),
                RecordExplorerMetric(
                  icon: Icons.swap_vert,
                  label: 'Net',
                  value: '1,000',
                  color: Colors.blue,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(WidgetsRecordExplorer),
          matching: find.byType(Scrollbar),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
