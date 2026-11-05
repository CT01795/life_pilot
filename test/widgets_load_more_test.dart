import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/widgets/widgets_load_more.dart';

void main() {
  testWidgets(
    'lazy footer keeps exhaustion but resets after query or city changes',
    (tester) async {
      final owner = Object();
      var scope = 'search', city = 'A', footerKey = 0;
      var more = true;
      late StateSetter update;
      late AppLocalizations loc;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: StatefulBuilder(
            builder: (context, set) {
              update = set;
              loc = AppLocalizations.of(context)!;
              return Scaffold(
                body: PaginationScope(
                  value: city,
                  child: WidgetsLoadMore(
                    key: ValueKey(footerKey),
                    owner: owner,
                    hasMore: more,
                    count: 1,
                    scope: scope,
                    onLoadMore: () async {},
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(loc.clickHereToSeeMore));
      await tester.pumpAndSettle();
      expect(find.text(loc.noMoreData), findsOneWidget);
      update(() => footerKey++);
      await tester.pumpAndSettle();
      expect(find.text(loc.noMoreData), findsOneWidget);
      update(() {
        footerKey++;
        scope = '';
        more = false;
      });
      await tester.pumpAndSettle();
      expect(find.text(loc.clickHereToSeeMore), findsOneWidget);
      await tester.tap(find.text(loc.clickHereToSeeMore));
      await tester.pumpAndSettle();
      expect(find.text(loc.noMoreData), findsOneWidget);
      update(() => city = 'B');
      await tester.pumpAndSettle();
      expect(find.text(loc.clickHereToSeeMore), findsOneWidget);
    },
  );
  for (final language in ['zh', 'en', 'ja', 'ko']) {
    testWidgets('$language empty page stops and filter change reopens action', (
      tester,
    ) async {
      var count = 1, calls = 0;
      var more = true, fail = false;
      var scope = 'keyword';
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
                body: WidgetsLoadMore(
                  hasMore: more,
                  count: count,
                  scope: scope,
                  onLoadMore: () async {
                    calls++;
                    if (fail) throw StateError('offline');
                  },
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(loc.clickHereToSeeMore));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.text(loc.noMoreData), findsOneWidget);
      expect(find.text(loc.clickHereToSeeMore), findsNothing);
      update(() {
        scope = '';
        more = false;
      });
      await tester.pumpAndSettle();
      expect(find.text(loc.noMoreData), findsNothing);
      expect(find.text(loc.clickHereToSeeMore), findsOneWidget);
      fail = true;
      await tester.tap(find.text(loc.clickHereToSeeMore));
      await tester.pumpAndSettle();
      expect(find.text(loc.retry), findsOneWidget);
      expect(find.text(loc.noMoreData), findsNothing);
      fail = false;
      await tester.tap(find.text(loc.retry));
      await tester.pumpAndSettle();
      expect(find.text(loc.noMoreData), findsOneWidget);
      update(() {
        count = 2;
        more = true;
      });
      await tester.pumpAndSettle();
      expect(find.text(loc.clickHereToSeeMore), findsOneWidget);
    });
  }
  testWidgets('old empty response cannot close a changed filter', (
    tester,
  ) async {
    var scope = 'old';
    late StateSetter update;
    late AppLocalizations loc;
    final response = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: StatefulBuilder(
          builder: (context, set) {
            update = set;
            loc = AppLocalizations.of(context)!;
            return Scaffold(
              body: WidgetsLoadMore(
                hasMore: true,
                count: 0,
                scope: scope,
                onLoadMore: () => response.future,
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(loc.clickHereToSeeMore));
    await tester.pump();
    update(() => scope = 'new');
    await tester.pump();
    response.complete();
    await tester.pumpAndSettle();
    expect(find.text(loc.clickHereToSeeMore), findsOneWidget);
    expect(find.text(loc.noMoreData), findsNothing);
  });
}
