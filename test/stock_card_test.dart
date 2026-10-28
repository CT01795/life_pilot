import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/stock/model_stock.dart';
import 'package:life_pilot/stock/widgets_stock_card.dart';

ModelStock _stock() => ModelStock(
  date: DateTime(2025, 12, 31),
  securityCode: '2330',
  securityName: 'Long company name 台積電 株式会社 테스트',
  closingPrice: 1234.5,
  pctChange: -2.5,
  peRatio: 23.4,
  rsi: 40,
  tradedNumber: 123456789,
  signal: -1,
  signalText: 'Long strategy description for a narrow screen',
)..origin = StockDataOrigin.cloud;

Widget _app(ModelStock stock, String locale) => MaterialApp(
  locale: Locale(locale),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
      child: SingleChildScrollView(
        child: WidgetsStockCard(stock: stock, index: 0),
      ),
    ),
  ),
);

void main() {
  for (final locale in ['zh', 'en', 'ja', 'ko']) {
    for (final width in [320.0, 800.0]) {
      testWidgets('stock card fits $locale at $width with enlarged text', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(_app(_stock(), locale));
        await tester.pumpAndSettle();
        expect(find.text('2330'), findsOneWidget);
        expect(find.text('2025/12/31'), findsOneWidget);
        expect(find.text('-2.50%'), findsOneWidget);
        expect(find.textContaining('1,234.50'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'card observes edits and language changes without retained values',
    (tester) async {
      final stock = _stock();
      await tester.pumpWidget(_app(stock, 'en'));
      await tester.pumpAndSettle();
      stock.pctChange = 3.5;
      stock.closingPrice = 99;
      stock.origin = StockDataOrigin.backend;
      await tester.pumpWidget(_app(stock, 'zh'));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(WidgetsStockCard));
      expect(
        find.text(AppLocalizations.of(context)!.stockSourceBackend),
        findsOneWidget,
      );
      expect(find.text('3.50%'), findsOneWidget);
      expect(find.text('-2.50%'), findsNothing);
      expect(find.textContaining('99.00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
