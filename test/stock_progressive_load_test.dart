import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/stock/controller_stock.dart';
import 'package:life_pilot/stock/model_stock.dart';
import 'package:life_pilot/stock/service_stock.dart';
import 'package:life_pilot/stock/page_stock.dart';

final _day = DateTime(2026, 10, 28);
ModelStock _stock(DateTime date) => ModelStock(
  date: date,
  securityCode: '2330',
  securityName: 'Stock',
  closingPrice: 100,
);
ModelInstitutional _foreign(String name) => ModelInstitutional(
  stockNo: name,
  stockName: name,
  foreignDiff: 100,
  totalDiff: 100,
);

class _Service extends ServiceStock {
  int foreignCalls = 0, futuresCalls = 0;
  int cloudCalls = 0, serverCalls = 0, rawCalls = 0;
  int historyCalls = 0;
  final initial = Completer<List<ModelStock>>();
  final raw = Completer<void>();
  Completer<List<ModelStock>>? serverInitial;
  final foreign = <DateTime, Completer<List<ModelInstitutional>>>{};
  final futuresByDate = <DateTime, Completer<List<ModelFuture>>>{};
  @override
  Future<List<ModelStock>> getSimpleStrategySupabase(String level) {
    cloudCalls++;
    return initial.future;
  }

  @override
  Future<List<ModelStock>> getSimpleStrategy(String level) async {
    serverCalls++;
    return level == 'Updating 2' && serverInitial != null
        ? serverInitial!.future
        : [];
  }

  @override
  Future<void> loadRawData() {
    rawCalls++;
    return raw.future;
  }

  @override
  Future<List<ModelStock>> getSimpleStrategyForDate(DateTime date) async {
    historyCalls++;
    return [_stock(date)];
  }

  @override
  Future<List<ModelInstitutional>> selectStockInstitutional(DateTime date) =>
      _readForeign(date);
  Future<List<ModelInstitutional>> _readForeign(DateTime date) {
    foreignCalls++;
    return (foreign[date] ??= Completer<List<ModelInstitutional>>()).future;
  }

  @override
  Future<List<ModelFuture>> selectFutures(DateTime date) {
    futuresCalls++;
    return (futuresByDate[date] ??= Completer<List<ModelFuture>>()).future;
  }
}

class _CountedStock extends ModelStock {
  _CountedStock()
    : super(
        date: _day,
        securityCode: '2330',
        securityName: 'Stock',
        closingPrice: 100,
      );
  int priceReads = 0;
  @override
  double get closingPrice {
    priceReads++;
    return super.closingPrice;
  }
}

class _CountedSell extends ModelInstitutional {
  _CountedSell()
    : super(
        stockNo: 'sell',
        stockName: 'Common Alpha sell',
        foreignDiff: -1000,
        totalDiff: -500,
      );
  int quantityReads = 0;
  @override
  int get foreignDiff {
    quantityReads++;
    return super.foreignDiff;
  }
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  test(
    'startup notification superseded by history does not send an initial cloud read',
    () async {
      final service = _Service();
      final c = ControllerStock(service);
      addTearDown(c.dispose);
      final historical = _day.subtract(const Duration(days: 7));
      var changed = false;
      Future<void>? history;
      c.addListener(() {
        if (changed) return;
        changed = true;
        history = c.loadDate(historical);
      });
      final startup = c.load();
      await _flush();
      expect(service.cloudCalls, 0);
      expect(service.rawCalls, 0);
      service.foreign[historical]!.complete([]);
      service.futuresByDate[historical]!.complete([]);
      await history;
      await startup;
      expect(c.selectedDate, historical);
    },
  );

  test(
    'superseding update-start notification prevents an obsolete backend write',
    () async {
      final service = _Service();
      final c = ControllerStock(service);
      addTearDown(c.dispose);
      final historical = _day.subtract(const Duration(days: 7));
      var changed = false;
      Future<void>? history;
      c.addListener(() {
        if (changed || c.updateStatus != StockUpdateStatus.updating) return;
        changed = true;
        history = c.loadDate(historical);
      });
      final startup = c.load();
      service.initial.complete([_stock(_day)]);
      await _flush();
      expect(service.rawCalls, 0);
      for (final request in service.foreign.values) {
        request.complete([]);
      }
      for (final request in service.futuresByDate.values) {
        request.complete([]);
      }
      await history;
      await startup;
      expect(c.selectedDate, historical);
      expect(c.stocks.single.date, historical);
    },
  );

  testWidgets('equal stock search results do not rebuild cards or lose input', (
    tester,
  ) async {
    final service = _Service();
    final stock = _CountedStock();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: PageStock(service: service)),
      ),
    );
    service.initial.complete([stock]);
    await tester.pump();
    await tester.pump();
    service.foreign[_day]!.complete([]);
    service.futuresByDate[_day]!.complete([]);
    service.raw.complete();
    await tester.pumpAndSettle();
    final reads = stock.priceReads;
    expect(reads, greaterThan(0));
    for (final query in ['s', 'st', 'stock', ' STOCK ', '2330']) {
      await tester.enterText(find.byType(TextField), query);
      await tester.pumpAndSettle();
      expect(stock.priceReads, reads);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        query,
      );
    }
    await tester.enterText(find.byType(TextField), 'missing');
    await tester.pumpAndSettle();
    expect(find.text('2330'), findsNothing);
    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    expect(find.text('2330'), findsOneWidget);
    expect(stock.priceReads, greaterThan(reads));
    expect(tester.takeException(), isNull);
  });

  testWidgets('changing only buy search results does not rebuild sell rows', (
    tester,
  ) async {
    final service = _Service();
    final sell = _CountedSell();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: PageStock(service: service)),
      ),
    );
    service.initial.complete([_stock(_day)]);
    await tester.pump();
    await tester.pump();
    service.foreign[_day]!.complete([
      _foreign('Common Alpha buy'),
      _foreign('Common Beta buy'),
      sell,
    ]);
    service.futuresByDate[_day]!.complete([]);
    service.raw.complete();
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'common');
    await tester.pumpAndSettle();
    final reads = sell.quantityReads;
    expect(reads, greaterThan(0));
    await tester.enterText(find.byType(TextField), 'common alpha');
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Common Beta buy', findRichText: true),
      findsNothing,
    );
    expect(
      find.textContaining('Common Alpha buy', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('Common Alpha sell', findRichText: true),
      findsOneWidget,
    );
    expect(sell.quantityReads, reads);
    expect(tester.takeException(), isNull);
  });

  test(
    'fully loaded selected day is reused without queries or notifications',
    () async {
      final service = _Service();
      final controller = ControllerStock(service)
        ..loading = false
        ..selectedDate = _day
        ..stocks = [_stock(_day)]
        ..futures = [ModelFuture(productName: 'kept')];
      addTearDown(controller.dispose);
      var notifications = 0;
      controller.addListener(() => notifications++);
      final stocks = controller.stocks;
      final futures = controller.futures;
      await controller.loadDate(DateTime.utc(2026, 10, 28, 15));
      expect(service.historyCalls, 0);
      expect(service.foreignCalls, 0);
      expect(service.futuresCalls, 0);
      expect(controller.stocks, same(stocks));
      expect(controller.futures, same(futures));
      expect(notifications, 0);
    },
  );

  for (final reason in [
    'forced',
    'failed',
    'empty',
    'different snapshot',
    'section failure',
    'missing selection',
  ]) {
    test('same selected date is queried again when $reason', () async {
      final service = _Service();
      final controller = ControllerStock(service)
        ..loading = false
        ..selectedDate = _day
        ..stocks = [_stock(_day)];
      addTearDown(controller.dispose);
      switch (reason) {
        case 'failed':
          controller.loadFailed = true;
        case 'empty':
          controller.stocks = [];
        case 'different snapshot':
          controller.stocks = [_stock(_day.subtract(const Duration(days: 1)))];
        case 'section failure':
          controller.futuresError = StateError('retry');
        case 'missing selection':
          controller.selectedDate = null;
      }
      await controller.loadDate(_day, force: reason == 'forced');
      expect(service.historyCalls, 1);
      expect(service.foreignCalls, 1);
      expect(service.futuresCalls, 1);
      service.foreign[_day]!.complete([]);
      service.futuresByDate[_day]!.complete([]);
      await _flush();
      expect(controller.loadFailed, isFalse);
      expect(controller.futuresError, isNull);
    });
  }

  test(
    'reentrant dashboard replacement skips obsolete network requests',
    () async {
      final service = _Service();
      final controller = ControllerStock(service);
      addTearDown(controller.dispose);
      final oldDay = _day.subtract(const Duration(days: 1));
      Future<void>? replacement;
      var replaced = false;
      controller.addListener(() {
        if (replaced) return;
        replaced = true;
        replacement = controller.buildDashboard(_day);
      });
      final oldLoad = controller.buildDashboard(oldDay);
      expect(service.foreign.keys, [_day]);
      expect(service.futuresByDate.keys, [_day]);
      expect(service.foreignCalls, 1);
      expect(service.futuresCalls, 1);
      service.foreign[_day]!.complete([_foreign('current')]);
      service.futuresByDate[_day]!.complete([
        ModelFuture(productName: 'current'),
      ]);
      await oldLoad;
      await replacement;
      expect(controller.foreignBuy.single.stockNo, 'current');
      expect(controller.futures.single.productName, 'current');
      expect(controller.institutionalsLoading, isFalse);
      expect(controller.futuresLoading, isFalse);
    },
  );

  test(
    'replacement on combined loading notification skips both old reads',
    () async {
      final service = _Service();
      final controller = ControllerStock(service);
      addTearDown(controller.dispose);
      final oldDay = _day.subtract(const Duration(days: 1));
      Future<void>? replacement;
      var replaced = false;
      controller.addListener(() {
        if (replaced || !controller.futuresLoading) return;
        replaced = true;
        replacement = controller.buildDashboard(_day);
      });
      final oldLoad = controller.buildDashboard(oldDay);
      expect(service.foreign.keys, [_day]);
      expect(service.futuresByDate.keys, [_day]);
      service.foreign[_day]!.complete([_foreign('current')]);
      service.futuresByDate[_day]!.complete([
        ModelFuture(productName: 'current'),
      ]);
      await replacement;
      await oldLoad;
      expect(controller.foreignBuy.single.stockNo, 'current');
      expect(controller.futures.single.productName, 'current');
      expect(controller.institutionalsLoading, isFalse);
      expect(controller.futuresLoading, isFalse);
      expect(service.futuresCalls, 1);
      expect(service.foreignCalls, 1);
    },
  );

  test(
    'dashboard announces loading once and publishes each result independently',
    () async {
      final service = _Service();
      final controller = ControllerStock(service)
        ..institutionalsError = StateError('previous foreign failure')
        ..futuresError = StateError('previous futures failure');
      addTearDown(controller.dispose);
      final states = <(bool, bool)>[];
      controller.addListener(() {
        states.add((
          controller.institutionalsLoading,
          controller.futuresLoading,
        ));
        expect(controller.institutionalsError, isNull);
        expect(controller.futuresError, isNull);
      });
      final load = controller.buildDashboard(_day);
      expect(states, [(true, true)]);
      expect(service.foreignCalls, 1);
      expect(service.futuresCalls, 1);
      service.foreign[_day]!.complete([_foreign('ready')]);
      await _flush();
      expect(states, [(true, true), (false, true)]);
      expect(controller.foreignBuy.single.stockNo, 'ready');
      service.futuresByDate[_day]!.complete([
        ModelFuture(productName: 'ready'),
      ]);
      await load;
      expect(states, [(true, true), (false, true), (false, false)]);
      expect(controller.futures.single.productName, 'ready');
    },
  );

  testWidgets(
    'search filters futures and stocks and accepts refreshed matching data',
    (tester) async {
      final service = _Service();
      final future = ModelFuture(productName: 'Original 2330', oiNetQty: 1000);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: PageStock(service: service)),
        ),
      );
      service.initial.complete([_stock(_day)]);
      await tester.pump();
      await tester.pump();
      service.foreign[_day]!.complete([_foreign('Stock')]);
      service.futuresByDate[_day]!.complete([future]);
      service.raw.complete();
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Original 2330', findRichText: true),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField), 'missing');
      await tester.pumpAndSettle();
      expect(find.text('2330'), findsNothing);
      expect(
        find.textContaining('Original 2330', findRichText: true),
        findsNothing,
      );

      await tester.enterText(find.byType(TextField), '2330');
      await tester.pumpAndSettle();
      expect(find.text('2330'), findsWidgets);
      expect(
        find.textContaining('Original 2330', findRichText: true),
        findsOneWidget,
      );

      // A real refresh must still update the retained dashboard subtree.
      service.futuresByDate[_day] = Completer<List<ModelFuture>>()
        ..complete([ModelFuture(productName: 'Updated 2330', oiNetQty: 2000)]);
      final context = tester.element(find.byType(TextField));
      final controller = Provider.of<ControllerStock>(context, listen: false);
      await controller.buildDashboard(_day);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Updated 2330', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('Original 2330', findRichText: true),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      expect(find.text('2330'), findsOneWidget);
      expect(
        find.textContaining('Updated 2330', findRichText: true),
        findsOneWidget,
      );
    },
  );

  test('concurrent page loads share reads and the backend update', () async {
    final service = _Service();
    final controller = ControllerStock(service);
    addTearDown(controller.dispose);
    final first = controller.load();
    expect(identical(controller.load(), first), isTrue);
    expect(service.cloudCalls, 1);
    service.initial.complete([]);
    await _flush();
    expect(service.rawCalls, 1);
    expect(identical(controller.load(), first), isTrue);
    service.raw.complete();
    await first;
    expect(service.serverCalls, 2);
    expect(controller.updateStatus, StockUpdateStatus.succeeded);

    // Completed work is not a persistent cache or a queued refresh.
    await controller.load();
    expect(service.cloudCalls, 2);
    expect(service.rawCalls, 2);
    expect(service.serverCalls, 4);
  });

  test('reentrant listener joins the published page load', () async {
    final service = _Service();
    final controller = ControllerStock(service);
    addTearDown(controller.dispose);
    Future<void>? reentrant;
    controller.addListener(() {
      reentrant ??= controller.load();
    });
    final first = controller.load();
    expect(identical(reentrant, first), isTrue);
    service.initial.complete([]);
    service.raw.complete();
    await first;
    expect(service.cloudCalls, 1);
    expect(service.rawCalls, 1);
  });

  test('failed backend update releases the page load for retry', () async {
    final service = _Service();
    final controller = ControllerStock(service);
    addTearDown(controller.dispose);
    final first = controller.load();
    service.initial.complete([]);
    await _flush();
    service.raw.completeError(StateError('backend unavailable'));
    await first;
    expect(controller.updateStatus, StockUpdateStatus.failed);
    final retry = controller.load();
    expect(identical(retry, first), isFalse);
    await retry;
    expect(service.cloudCalls, 2);
    expect(service.rawCalls, 2);
  });

  test('disposed page neither restarts nor publishes an active load', () async {
    final service = _Service();
    final controller = ControllerStock(service);
    var notifications = 0;
    controller.addListener(() => notifications++);
    final first = controller.load();
    controller.dispose();
    await controller.load();
    service.initial.complete([]);
    await first;
    expect(service.cloudCalls, 1);
    expect(service.rawCalls, 0);
    expect(notifications, 1);
  });

  testWidgets(
    'partial futures quantities show a placeholder without crashing',
    (tester) async {
      final service = _Service();
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: PageStock(service: service)),
        ),
      );
      service.initial.complete([_stock(_day)]);
      await tester.pump();
      await tester.pump();
      service.foreign[_day]!.complete([]);
      service.futuresByDate[_day]!.complete([
        ModelFuture(
          productName: '臺股期貨',
          identityType: 'foreign',
          oiNetQtyDiff: 200,
        ),
      ]);
      service.raw.complete();
      await tester.pumpAndSettle();
      expect(find.textContaining('—', findRichText: true), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('slow server read times out without hiding cloud rows', (
    tester,
  ) async {
    final service = _Service()..serverInitial = Completer<List<ModelStock>>();
    final c = ControllerStock(
      service,
      requestTimeout: const Duration(seconds: 1),
    );
    addTearDown(c.dispose);
    final load = c.load();
    service.initial.complete([_stock(_day)]);
    await tester.pump();
    expect(c.loading, isFalse);
    expect(c.stocks.single.date, _day);
    service.foreign[_day]!.complete([]);
    service.futuresByDate[_day]!.complete([]);
    service.raw.complete();
    await tester.pump(const Duration(seconds: 2));
    await load;
    expect(c.canSelectDate, isTrue);
    service.serverInitial!.complete([_stock(DateTime(2026, 10, 29))]);
    await tester.pump();
    expect(c.selectedDate, _day);
    expect(tester.takeException(), isNull);
  });
  test('same-day concurrent dashboard loads share unfinished reads', () async {
    final service = _Service();
    final c = ControllerStock(service);
    addTearDown(c.dispose);
    final first = c.buildDashboard(_day);
    final second = c.buildDashboard(_day);
    expect(service.foreignCalls, 1);
    expect(service.futuresCalls, 1);
    service.foreign[_day]!.complete([_foreign('shared')]);
    service.futuresByDate[_day]!.complete([]);
    await Future.wait([first, second]);
    expect(c.foreignBuy.single.stockNo, 'shared');
    expect(c.institutionalsLoading, isFalse);
    expect(c.futuresLoading, isFalse);
  });

  test('post-update refresh does not join pre-update requests', () async {
    final service = _Service();
    final c = ControllerStock(service);
    addTearDown(c.dispose);
    final load = c.load();
    service.initial.complete([_stock(_day)]);
    await _flush();
    final oldForeign = service.foreign[_day]!;
    final oldFutures = service.futuresByDate[_day]!;
    service.foreign[_day] = Completer<List<ModelInstitutional>>();
    service.futuresByDate[_day] = Completer<List<ModelFuture>>();
    service.raw.complete();
    await _flush();
    expect(service.foreignCalls, 2);
    expect(service.futuresCalls, 2);
    service.foreign[_day]!.complete([_foreign('fresh')]);
    service.futuresByDate[_day]!.complete([ModelFuture(productName: 'fresh')]);
    await load;
    oldForeign.complete([_foreign('old')]);
    oldFutures.complete([ModelFuture(productName: 'old')]);
    await _flush();
    expect(c.foreignBuy.single.stockNo, 'fresh');
    expect(c.futures.single.productName, 'fresh');
  });

  test('retry reloads only the failed section', () async {
    final service = _Service();
    final c = ControllerStock(service)..selectedDate = _day;
    addTearDown(c.dispose);
    final load = c.buildDashboard(_day);
    service.foreign[_day]!.completeError(StateError('offline'));
    service.futuresByDate[_day]!.complete([ModelFuture(productName: 'kept')]);
    await load;
    expect(c.institutionalsError, isNotNull);
    service.foreign[_day] = Completer<List<ModelInstitutional>>();
    final retry = c.retryInstitutionals();
    service.foreign[_day]!.complete([_foreign('retried')]);
    await retry;
    expect(c.institutionalsError, isNull);
    expect(c.foreignBuy.single.stockNo, 'retried');
    expect(c.futures.single.productName, 'kept');
    expect(service.foreignCalls, 2);
    expect(service.futuresCalls, 1);
  });

  test(
    'historical stock load finishes before its dashboard sections',
    () async {
      final service = _Service();
      final c = ControllerStock(service);
      addTearDown(c.dispose);
      await c.loadDate(_day);
      expect(c.dateLoading, isFalse);
      expect(c.stocks.single.date, _day);
      expect(c.institutionalsLoading, isTrue);
      expect(c.futuresLoading, isTrue);
      service.foreign[_day]!.complete([]);
      service.futuresByDate[_day]!.complete([]);
      await _flush();
    },
  );

  testWidgets(
    'timeout releases date lock and late responses cannot overwrite retry',
    (tester) async {
      final service = _Service();
      final c =
          ControllerStock(service, requestTimeout: const Duration(seconds: 1))
            ..selectedDate = _day
            ..latestAvailableDate = _day
            ..loading = false
            ..updateStatus = StockUpdateStatus.failed;
      addTearDown(c.dispose);
      final load = c.buildDashboard(_day);
      await tester.pump(const Duration(seconds: 2));
      await load;
      expect(c.institutionalsError, isA<TimeoutException>());
      expect(c.futuresError, isA<TimeoutException>());
      expect(c.canSelectDate, isTrue);
      final oldFutures = service.futuresByDate[_day]!;
      service.futuresByDate[_day] = Completer<List<ModelFuture>>();
      final retry = c.retryFutures();
      service.futuresByDate[_day]!.complete([
        ModelFuture(productName: 'retry'),
      ]);
      await tester.pump();
      await retry;
      oldFutures.complete([ModelFuture(productName: 'expired')]);
      service.foreign[_day]!.completeError(StateError('late error'));
      await tester.pump();
      expect(c.futures.single.productName, 'retry');
      expect(c.futuresError, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('dashboard and status updates do not rebuild stock cards', (
    tester,
  ) async {
    final service = _Service();
    final stock = _CountedStock();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: PageStock(service: service)),
      ),
    );
    service.initial.complete([stock]);
    await tester.pump();
    await tester.pump();
    expect(find.text('2330'), findsOneWidget);
    final reads = stock.priceReads;
    expect(reads, greaterThan(0));
    service.foreign[_day]!.complete([]);
    await tester.pump();
    service.futuresByDate[_day]!.complete([]);
    await tester.pump();
    service.raw.complete();
    await tester.pumpAndSettle();
    expect(stock.priceReads, reads);
    expect(tester.takeException(), isNull);
  });

  for (final language in ['zh', 'en', 'ja', 'ko']) {
    testWidgets('source and full date fit narrow screens in $language', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = _Service();
      final stock = _stock(_day)
        ..origin = StockDataOrigin.cloud
        ..level = 'From Supabase 1';
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: PageStock(service: service)),
        ),
      );
      service.initial.complete([stock]);
      await tester.pump();
      await tester.pump();
      service.foreign[_day]!.complete([]);
      service.futuresByDate[_day]!.complete([]);
      service.raw.complete();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('2026/10/28'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      final context = tester.element(find.text('2026/10/28'));
      expect(
        find.text(AppLocalizations.of(context)!.stockSourceCloud),
        findsOneWidget,
      );
      expect(find.textContaining('From Supabase'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('page shows stock cards while dashboard sections are pending', (
    tester,
  ) async {
    final service = _Service();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: PageStock(service: service)),
      ),
    );
    service.initial.complete([_stock(_day)]);
    await tester.pump();
    await tester.pump();
    expect(find.text('2330'), findsOneWidget);
    expect(find.byKey(const ValueKey('stock-futures-loading')), findsOneWidget);
    final dateButton = tester.widget<OutlinedButton>(
      find.byType(OutlinedButton).first,
    );
    expect(dateButton.onPressed, isNull);
    service.foreign[_day]!.complete([]);
    service.futuresByDate[_day]!.complete([]);
    service.raw.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('stock-futures-loading')), findsNothing);
    expect(
      tester
          .widget<OutlinedButton>(find.byType(OutlinedButton).first)
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });
  test(
    'stocks publish before dashboard; institutions publish before futures',
    () async {
      final service = _Service();
      final controller = ControllerStock(service);
      addTearDown(controller.dispose);
      var notifications = 0;
      controller.addListener(() => notifications++);
      final pending = controller.load();
      service.initial.complete([_stock(_day)]);
      await _flush();
      expect(controller.loading, isFalse);
      expect(controller.stocks.single.date, _day);
      expect(service.foreign.containsKey(_day), isTrue);
      expect(service.futuresByDate.containsKey(_day), isTrue);
      expect(controller.institutionalsLoading, isTrue);
      expect(controller.futuresLoading, isTrue);
      expect(controller.canSelectDate, isFalse);

      final before = notifications;
      service.foreign[_day]!.complete([_foreign('foreign')]);
      await _flush();
      expect(controller.foreignBuy.single.stockNo, 'foreign');
      expect(controller.institutionalsLoading, isFalse);
      expect(controller.futuresLoading, isTrue);
      expect(notifications, greaterThan(before));

      service.futuresByDate[_day]!.complete([
        ModelFuture(productName: 'future'),
      ]);
      await _flush();
      expect(controller.futures.single.productName, 'future');
      expect(controller.canSelectDate, isFalse); // Raw update still pending.
      service.raw.complete();
      await pending;
      expect(controller.updateStatus, StockUpdateStatus.succeeded);
      expect(controller.canSelectDate, isTrue);
    },
  );

  test(
    'futures publish without waiting for institutions or raw update',
    () async {
      final service = _Service();
      final controller = ControllerStock(service);
      addTearDown(controller.dispose);
      final pending = controller.load();
      service.initial.complete([_stock(_day)]);
      await _flush();
      service.futuresByDate[_day]!.complete([
        ModelFuture(productName: 'first'),
      ]);
      await _flush();
      expect(controller.futures.single.productName, 'first');
      expect(controller.institutionalsLoading, isTrue);
      expect(controller.futuresLoading, isFalse);
      expect(controller.canSelectDate, isFalse);
      service.foreign[_day]!.complete([]);
      service.raw.complete();
      await pending;
    },
  );

  test(
    'a dashboard section failure does not discard the stock list or sibling',
    () async {
      final service = _Service();
      final controller = ControllerStock(service);
      addTearDown(controller.dispose);
      final pending = controller.load();
      service.initial.complete([_stock(_day)]);
      await _flush();
      service.foreign[_day]!.completeError(StateError('foreign unavailable'));
      service.futuresByDate[_day]!.complete([ModelFuture(productName: 'kept')]);
      service.raw.complete();
      await pending;
      expect(controller.stocks, hasLength(1));
      expect(controller.futures.single.productName, 'kept');
      expect(controller.institutionalsLoading, isFalse);
      expect(controller.futuresLoading, isFalse);
      expect(controller.canSelectDate, isTrue);
    },
  );

  test(
    'failed raw update unlocks dates after remaining dashboard reads finish',
    () async {
      final service = _Service();
      final controller = ControllerStock(service);
      addTearDown(controller.dispose);
      final pending = controller.load();
      service.initial.complete([_stock(_day)]);
      await _flush();
      service.raw.completeError(StateError('update failed'));
      await pending;
      expect(controller.updateStatus, StockUpdateStatus.failed);
      expect(controller.canSelectDate, isFalse);
      service.foreign[_day]!.complete([]);
      service.futuresByDate[_day]!.complete([]);
      await _flush();
      expect(controller.canSelectDate, isTrue);
    },
  );

  test('older dashboard response cannot overwrite a newer dashboard', () async {
    final service = _Service();
    final controller = ControllerStock(service);
    addTearDown(controller.dispose);
    final older = _day.subtract(const Duration(days: 1));
    final oldLoad = controller.buildDashboard(older);
    final newLoad = controller.buildDashboard(_day);
    service.foreign[_day]!.complete([_foreign('new')]);
    service.futuresByDate[_day]!.complete([ModelFuture(productName: 'new')]);
    await newLoad;
    service.foreign[older]!.complete([_foreign('old')]);
    service.futuresByDate[older]!.complete([ModelFuture(productName: 'old')]);
    await oldLoad;
    expect(controller.foreignBuy.single.stockNo, 'new');
    expect(controller.futures.single.productName, 'new');
  });

  test(
    'late startup responses cannot reset a selected historical date',
    () async {
      final service = _Service();
      final controller = ControllerStock(service);
      addTearDown(controller.dispose);
      final startup = controller.load();
      service.initial.complete([_stock(_day)]);
      await _flush();
      final historical = _day.subtract(const Duration(days: 7));
      final history = controller.loadDate(historical);
      await _flush();
      service.foreign[historical]!.complete([_foreign('history')]);
      service.futuresByDate[historical]!.complete([
        ModelFuture(productName: 'history'),
      ]);
      await history;
      service.foreign[_day]!.complete([_foreign('late')]);
      service.futuresByDate[_day]!.complete([ModelFuture(productName: 'late')]);
      service.raw.complete();
      await startup;
      expect(controller.selectedDate, historical);
      expect(controller.stocks.single.date, historical);
      expect(controller.foreignBuy.single.stockNo, 'history');
      expect(controller.futures.single.productName, 'history');
    },
  );
}
