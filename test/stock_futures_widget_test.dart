import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/stock/model_stock.dart';
import 'package:life_pilot/stock/widgets_stock_futures.dart';

Widget _app({
  String locale = 'en',
  List<ModelFuture> items = const [],
  bool loading = false,
  Object? error,
  Future<void> Function()? onRetry,
}) => MaterialApp(
  locale: Locale(locale),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: SingleChildScrollView(
      child: WidgetsStockFutures(
        items: items,
        loading: loading,
        error: error,
        onRetry: onRetry ?? () async {},
      ),
    ),
  ),
);

void main() {
  for (final locale in ['zh', 'en', 'ja', 'ko']) {
    testWidgets('$locale futures fits a narrow screen with partial values', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _app(
          locale: locale,
          items: [
            ModelFuture(
              productName: 'Long futures product name 臺股期貨',
              identityType: 'Foreign institutional investor',
              oiNetQtyDiff: -1234,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('—', findRichText: true), findsOneWidget);
      expect(find.textContaining('-1,234', findRichText: true), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'loading, error and no-data are distinct and retry uses callback',
    (tester) async {
      await tester.pumpWidget(_app(loading: true));
      await tester.pump();
      AppLocalizations loc() => AppLocalizations.of(
        tester.element(find.byType(WidgetsStockFutures)),
      )!;
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(loc().noData), findsNothing);
      var retries = 0;
      await tester.pumpWidget(
        _app(
          error: TimeoutException('timeout'),
          onRetry: () async {
            retries++;
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(loc().stockReadTimeout), findsOneWidget);
      expect(find.text(loc().noData), findsNothing);
      await tester.tap(find.byType(TextButton));
      expect(retries, 1);
      await tester.pumpWidget(_app(error: StateError('offline')));
      await tester.pumpAndSettle();
      expect(find.text(loc().stockLoadFailed), findsOneWidget);
      expect(find.text(loc().noData), findsNothing);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text(loc().noData), findsOneWidget);
      expect(find.byType(TextButton), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('fresh data and locale replace prior presentation', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(items: [ModelFuture(productName: 'Old', oiNetQty: 1)]),
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      _app(
        locale: 'zh',
        items: [ModelFuture(productName: 'New', oiNetQty: 2500)],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Old', findRichText: true), findsNothing);
    expect(find.textContaining('New', findRichText: true), findsOneWidget);
    expect(find.textContaining('2,500', findRichText: true), findsOneWidget);
    final loc = AppLocalizations.of(
      tester.element(find.byType(WidgetsStockFutures)),
    )!;
    expect(find.text(loc.stockDashboardTitle), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
