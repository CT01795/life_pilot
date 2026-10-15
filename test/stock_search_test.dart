import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/stock/controller_stock.dart';
import 'package:life_pilot/stock/model_stock.dart';
import 'package:life_pilot/stock/model_stock_search_index.dart';
import 'package:life_pilot/stock/service_stock.dart';
import 'package:life_pilot/stock/widgets_stock_search.dart';

ModelStock _stock(String code, String name) => ModelStock(
  date: DateTime(2026, 10, 15),
  securityCode: code,
  securityName: name,
  closingPrice: 100,
);
ModelInstitutional _institutional(String code, String name, int diff) =>
    ModelInstitutional(
      stockNo: code,
      stockName: name,
      foreignDiff: diff,
      totalDiff: diff,
    );

class _Service extends ServiceStock {
  Completer<List<ModelStock>>? pendingDate;
  Completer<List<ModelInstitutional>>? pendingInstitutionals;
  Completer<List<ModelFuture>>? pendingFutures;
  List<ModelInstitutional> rows = [];
  @override
  Future<List<ModelStock>> getSimpleStrategyForDate(DateTime date) =>
      pendingDate!.future;
  @override
  Future<List<ModelInstitutional>> selectStockInstitutional(
    DateTime date,
  ) async => pendingInstitutionals?.future ?? Future.value(rows);
  @override
  Future<List<ModelFuture>> selectFutures(DateTime date) async =>
      pendingFutures?.future ?? Future.value([]);
}

void main() {
  test('index normalizes query and caches the most recent result', () {
    var indexingCalls = 0;
    final index = StockSearchIndex(
      rows: [_stock('2330', 'TSMC'), _stock('2317', 'Hon Hai')],
      fields: (row) {
        indexingCalls++;
        return [row.securityCode, row.securityName];
      },
    );
    expect(index.filter('  tSmC ').single.securityCode, '2330');
    expect(identical(index.filter('TSMC'), index.filter('tsmc')), true);
    expect(indexingCalls, 2);
    expect(index.filter('231').single.securityName, 'Hon Hai');
    expect(index.filter('missing'), isEmpty);
  });
  test(
    'index preserves order, protects the source snapshot and result list',
    () {
      final source = [_stock('2', 'Same'), _stock('1', 'Same')];
      final index = StockSearchIndex(
        rows: source,
        fields: (row) => [row.securityCode, row.securityName],
      );
      source.clear();
      expect(index.filter('').map((row) => row.securityCode), ['2', '1']);
      expect(index.filter('same').map((row) => row.securityCode), ['2', '1']);
      expect(() => index.filter('').clear(), throwsUnsupportedError);
      expect(() => index.filter('same').clear(), throwsUnsupportedError);
    },
  );
  test(
    'controller filters all three sections and clear restores their order',
    () {
      final c = ControllerStock(_Service());
      addTearDown(c.dispose);
      c.stocks = [_stock('2330', 'TSMC'), _stock('2317', 'Hon Hai')];
      c.foreignBuy = [
        _institutional('2317', 'Hon Hai', 20),
        _institutional('2330', 'TSMC', 10),
      ];
      c.foreignSell = [_institutional('2330', 'TSMC', -10)];
      c.setSearchQuery('tsmc');
      expect(c.visibleStocks.single.securityCode, '2330');
      expect(c.visibleForeignBuy.single.stockNo, '2330');
      expect(c.visibleForeignSell.single.stockNo, '2330');
      expect(identical(c.visibleStocks, c.visibleStocks), true);
      c.setSearchQuery('');
      expect(c.visibleStocks.map((row) => row.securityCode), ['2330', '2317']);
      expect(c.visibleForeignBuy.map((row) => row.stockNo), ['2317', '2330']);
    },
  );
  test('new datasets invalidate cached results for the same query', () {
    final c = ControllerStock(_Service());
    addTearDown(c.dispose);
    c.setSearchQuery('new');
    expect(c.visibleStocks, isEmpty);
    expect(c.visibleForeignBuy, isEmpty);
    expect(c.visibleForeignSell, isEmpty);
    c.stocks = [_stock('new', 'New')];
    c.foreignBuy = [_institutional('new', 'New', 5)];
    c.foreignSell = [_institutional('new', 'New', -5)];
    expect(c.visibleStocks, hasLength(1));
    expect(c.visibleForeignBuy, hasLength(1));
    expect(c.visibleForeignSell, hasLength(1));
  });
  test('dashboard keeps buy and sell ranking directions', () async {
    final service = _Service()
      ..rows = [
        _institutional('a', 'A', 5),
        _institutional('b', 'B', 20),
        _institutional('c', 'C', -5),
        _institutional('d', 'D', -20),
      ];
    final c = ControllerStock(service);
    addTearDown(c.dispose);
    await c.buildDashboard(DateTime(2026, 10, 15));
    expect(c.foreignBuy.map((row) => row.stockNo), ['b', 'a']);
    expect(c.foreignSell.map((row) => row.stockNo), ['d', 'c']);
  });
  test(
    'late historical response cannot change disposed controller data',
    () async {
      final service = _Service()..pendingDate = Completer<List<ModelStock>>();
      final c = ControllerStock(service)..stocks = [_stock('old', 'Old')];
      final request = c.loadDate(DateTime(2026, 10, 10));
      c.dispose();
      service.pendingDate!.complete([_stock('late', 'Late')]);
      await request;
      expect(c.stocks.single.securityCode, 'old');
    },
  );
  test(
    'late institutional response cannot change disposed controller data',
    () async {
      final service = _Service()
        ..pendingInstitutionals = Completer<List<ModelInstitutional>>();
      final c = ControllerStock(service)
        ..institutionals = [_institutional('old', 'Old', 5)];
      final request = c.buildDashboard(DateTime(2026, 10, 10));
      c.dispose();
      service.pendingInstitutionals!.complete([
        _institutional('late', 'Late', 10),
      ]);
      await request;
      expect(c.institutionals.single.stockNo, 'old');
    },
  );
  test(
    'late futures response cannot change disposed controller data',
    () async {
      final service = _Service()
        ..pendingFutures = Completer<List<ModelFuture>>();
      final c = ControllerStock(service)
        ..futures = [ModelFuture(productName: 'Old')];
      final request = c.buildDashboard(DateTime(2026, 10, 10));
      await Future<void>.delayed(Duration.zero);
      c.dispose();
      service.pendingFutures!.complete([ModelFuture(productName: 'Late')]);
      await request;
      expect(c.futures.single.productName, 'Old');
    },
  );
  testWidgets('clear synchronizes both filter and displayed input text', (
    tester,
  ) async {
    var query = '2330';
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => WidgetsStockSearch(
              query: query,
              onChanged: (value) => setState(() => query = value),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.clear));
    await tester.pump();
    expect(query, '');
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );
    await tester.enterText(find.byType(TextField), '2317');
    await tester.pump();
    expect(query, '2317');
    expect(tester.takeException(), isNull);
  });
}
