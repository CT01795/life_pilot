import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/stock/model_stock.dart';
import 'package:life_pilot/stock/widgets_stock_foreign_ranking.dart';

List<ModelInstitutional> _rows(int count) => List.generate(
  count,
  (i) => ModelInstitutional(
    stockNo: '$i',
    stockName: 'Item $i',
    foreignDiff: 100000 - i,
    totalDiff: 200000 - i,
  ),
);

Widget _app(
  List<ModelInstitutional> rows, {
  String locale = 'en',
  bool loading = false,
  bool failed = false,
}) => MaterialApp(
  locale: Locale(locale),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: SingleChildScrollView(
      child: WidgetsStockForeignRanking(
        title: 'Foreign ranking',
        items: rows,
        isBuy: true,
        loading: loading,
        failed: failed,
      ),
    ),
  ),
);

Finder get _visibleRows => find.textContaining(' Item ', findRichText: true);

Future<void> _more(WidgetTester tester) async {
  final button = find.byType(TextButton);
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  for (final locale in ['zh', 'en', 'ja', 'ko']) {
    testWidgets(
      '$locale ranking expands 10, 30, 45 and hides more only at end',
      (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(_app(_rows(45), locale: locale));
        await tester.pumpAndSettle();
        expect(_visibleRows, findsNWidgets(10));
        await _more(tester);
        expect(_visibleRows, findsNWidgets(30));
        expect(find.byType(TextButton), findsOneWidget);
        await _more(tester);
        expect(_visibleRows, findsNWidgets(45));
        expect(find.byType(TextButton), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('status and language preserve expansion; replacement resets it', (
    tester,
  ) async {
    final rows = _rows(45);
    await tester.pumpWidget(_app(rows));
    await tester.pumpAndSettle();
    await _more(tester);
    await tester.pumpWidget(_app(rows, loading: true));
    await tester.pump();
    expect(_visibleRows, findsNWidgets(30));
    await tester.pumpWidget(_app(rows, locale: 'zh'));
    await tester.pumpAndSettle();
    expect(_visibleRows, findsNWidgets(30));
    await tester.pumpWidget(_app(_rows(12), locale: 'zh'));
    await tester.pumpAndSettle();
    expect(_visibleRows, findsNWidgets(10));
    expect(find.text('10 / 12'), findsOneWidget);
    expect(find.byType(TextButton), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
