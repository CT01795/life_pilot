import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/event/widgets_event_empty_state.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/widgets/widgets_load_more.dart';

void main() {
  for (final language in ['zh', 'en', 'ja', 'ko']) {
    for (final attractions in [false, true]) {
      testWidgets(
        '$language / attractions=$attractions: empty mine filter never offers more',
        (tester) async {
          var mine = true;
          late StateSetter update;
          late AppLocalizations loc;
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(language),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: StatefulBuilder(
                builder: (context, set) {
                  update = set;
                  loc = AppLocalizations.of(context)!;
                  return Scaffold(
                    body: mine
                        ? WidgetsEventEmptyState(
                            message: attractions
                                ? loc.recommendPlacesZero
                                : loc.recommendEventZero,
                          )
                        : WidgetsLoadMore(
                            hasMore: true,
                            count: 10,
                            scope: 'all',
                            onLoadMore: () async {},
                          ),
                  );
                },
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            find.text(
              attractions ? loc.recommendPlacesZero : loc.recommendEventZero,
            ),
            findsOneWidget,
          );
          expect(find.byType(WidgetsLoadMore), findsNothing);
          expect(find.text(loc.clickHereToSeeMore), findsNothing);
          expect(find.text(loc.noMoreData), findsNothing);
          update(() => mine = false);
          await tester.pumpAndSettle();
          expect(find.byType(WidgetsEventEmptyState), findsNothing);
          expect(find.text(loc.clickHereToSeeMore), findsOneWidget);
        },
      );
    }
  }
  testWidgets('empty search retains its clear-filter action', (tester) async {
    var clears = 0;
    late AppLocalizations loc;
    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) {
            loc = AppLocalizations.of(context)!;
            return Scaffold(
              body: WidgetsEventEmptyState(
                message: loc.recommendEventZero,
                onClear: () => clears++,
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(loc.clear));
    expect(clears, 1);
    expect(find.text(loc.clickHereToSeeMore), findsNothing);
  });
}
