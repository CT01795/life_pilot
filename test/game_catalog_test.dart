import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/game/controller_game_list.dart';
import 'package:life_pilot/game/model_game_catalog.dart';
import 'package:life_pilot/game/model_game_item.dart';
import 'package:life_pilot/game/model_game_user.dart';
import 'package:life_pilot/game/page_game_list.dart';
import 'package:life_pilot/game/service_game.dart';
import 'package:life_pilot/l10n/app_localizations.dart';

ModelGameItem _game(String type, String name, int level, [String? id]) =>
    ModelGameItem(
      id: id ?? '$type|$name|$level',
      gameType: type,
      gameName: name,
      level: level,
    );

class _Service extends ServiceGame {
  int loads = 0;
  int historyLoads = 0;
  bool fail = false;
  List<ModelGameItem> games = [];
  Completer<List<ModelGameItem>>? pending;
  @override
  Future<List<ModelGameItem>> fetchGames() async {
    loads++;
    if (pending != null) return pending!.future;
    if (fail) throw StateError('unavailable');
    return games;
  }

  @override
  Future<int> fetchHighestPassedLevel({
    required String userName,
    required String gameType,
    required String gameName,
  }) async => 0;
  @override
  Future<List<ModelGameUser>> fetchUserProgressPage({
    required String userName,
    required String gameType,
    required String gameName,
    required DateTime dateFrom,
    required DateTime dateTo,
    bool includeLatestFallback = false,
  }) async {
    historyLoads++;
    return [];
  }

  @override
  Future<bool> hasUserProgressBefore({
    required String userName,
    required String gameType,
    required String gameName,
    required DateTime before,
  }) async => false;
}

class _SyncFailure extends ServiceGame {
  @override
  Future<List<ModelGameItem>> fetchGames() => throw StateError('sync failure');
}

class _Auth extends ControllerAuth {
  @override
  String get currentAccount => 'user@example.com';
  @override
  bool get storesNewDataLocally => false;
}

Widget _app(_Service service, _Auth auth) =>
    ChangeNotifierProvider<ControllerAuth>.value(
      value: auth,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PageGameList(service: service),
      ),
    );

void main() {
  test('catalog preserves service category/name/level order', () {
    final rows = [
      _game('B', 'Second', 3),
      _game('A', 'First', 1),
      _game('B', 'Second', 1),
      _game('B', 'Other', 2),
    ];
    final catalog = ModelGameCatalog(rows);
    expect(catalog.categories, ['B', 'A']);
    expect(catalog.gamesByCategory['B']!.keys, ['Second', 'Other']);
    expect(catalog.gamesByCategory['B']!['Second']!.map((g) => g.level), [
      3,
      1,
    ]);
    expect(catalog.firstGame, same(rows.first));
  });

  test(
    'catalog containers are immutable and do not retain the source list',
    () {
      final rows = [_game('A', 'Game', 1)];
      final catalog = ModelGameCatalog(rows);
      rows.clear();
      expect(catalog.firstGame, isNotNull);
      expect(() => catalog.categories.clear(), throwsUnsupportedError);
      expect(() => catalog.gamesByCategory.clear(), throwsUnsupportedError);
      expect(
        () => catalog.gamesByCategory['A']!.clear(),
        throwsUnsupportedError,
      );
      expect(
        () => catalog.gamesByCategory['A']!['Game']!.clear(),
        throwsUnsupportedError,
      );
    },
  );

  test(
    'level index preserves first duplicate and the original fallback rule',
    () {
      final first = _game('A', 'Game', 1, 'first');
      final catalog = ModelGameCatalog([
        first,
        _game('A', 'Game', 1, 'duplicate'),
        _game('A', 'Game', 2, 'second'),
      ]);
      expect(
        catalog.findGame(gameType: 'A', gameName: 'Game', level: 1),
        same(first),
      );
      expect(
        catalog.findGame(gameType: 'A', gameName: 'Game', level: 2)!.id,
        'second',
      );
      expect(
        catalog.findGame(gameType: 'A', gameName: 'Game', level: 99),
        same(first),
      );
      expect(
        catalog.findGame(gameType: 'missing', gameName: 'Game', level: 1),
        isNull,
      );
      expect(catalog.findGame(gameType: 'A', gameName: 'Game'), isNull);
    },
  );

  test('empty catalog safely exposes no first game', () {
    final catalog = ModelGameCatalog([]);
    expect(catalog.categories, isEmpty);
    expect(catalog.firstGame, isNull);
    expect(catalog.findGame(gameType: 'A', gameName: 'Game', level: 1), isNull);
  });

  test(
    'concurrent catalog loads share one future and one service call',
    () async {
      final service = _Service()..pending = Completer<List<ModelGameItem>>();
      final controller = ControllerGameList(serviceGame: service);
      final first = controller.loadGames();
      final second = controller.loadGames();
      expect(identical(first, second), isTrue);
      expect(service.loads, 1);
      expect(controller.isLoading, isTrue);
      service.pending!.complete([_game('A', 'Game', 1)]);
      await Future.wait([first, second]);
      expect(controller.categories, ['A']);
      expect(controller.isLoading, isFalse);
      controller.dispose();
    },
  );

  test('refresh failure preserves snapshot and retry replaces it', () async {
    final service = _Service()..games = [_game('A', 'Old', 1)];
    final controller = ControllerGameList(serviceGame: service);
    await controller.loadGames();
    final snapshot = controller.gamesByCategory;
    service.fail = true;
    await expectLater(controller.loadGames(), throwsStateError);
    expect(controller.gamesByCategory, same(snapshot));
    expect(controller.loadError, isA<StateError>());
    expect(controller.isLoading, isFalse);
    service.fail = false;
    service.games = [_game('B', 'New', 1)];
    await controller.loadGames();
    expect(controller.loadError, isNull);
    expect(controller.categories, ['B']);
    expect(service.loads, 3);
    controller.dispose();
  });

  test(
    'synchronous service error releases loading and permits retry',
    () async {
      final controller = ControllerGameList(serviceGame: _SyncFailure());
      await expectLater(controller.loadGames(), throwsStateError);
      expect(controller.isLoading, isFalse);
      await expectLater(controller.loadGames(), throwsStateError);
      controller.dispose();
    },
  );

  test(
    'late load after disposal does not replace the catalog or notify',
    () async {
      final service = _Service()..pending = Completer<List<ModelGameItem>>();
      final controller = ControllerGameList(serviceGame: service);
      var notifications = 0;
      controller.addListener(() => notifications++);
      final load = controller.loadGames();
      controller.dispose();
      service.pending!.complete([_game('A', 'Game', 1)]);
      await load;
      expect(controller.categories, isEmpty);
      expect(notifications, 1);
      await controller.loadGames();
      expect(service.loads, 1);
    },
  );

  testWidgets(
    'game page renders a successful empty catalog without progress queries',
    (tester) async {
      final service = _Service();
      final auth = _Auth();
      await tester.pumpWidget(_app(service, auth));
      await tester.pumpAndSettle();
      final loc = AppLocalizations.of(
        tester.element(find.byType(PageGameList)),
      )!;
      expect(find.text(loc.noData), findsOneWidget);
      expect(service.historyLoads, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      auth.dispose();
    },
  );

  testWidgets('game page retry resolves the error and loads paged history', (
    tester,
  ) async {
    final service = _Service()..fail = true;
    final auth = _Auth();
    await tester.pumpWidget(_app(service, auth));
    await tester.pumpAndSettle();
    final loc = AppLocalizations.of(tester.element(find.byType(PageGameList)))!;
    expect(find.text(loc.retry), findsOneWidget);
    service.fail = false;
    service.games = [_game('Practice', 'Grammar', 1)];
    await tester.tap(find.text(loc.retry));
    await tester.pumpAndSettle();
    expect(find.text(loc.retry), findsNothing);
    expect(service.loads, 2);
    expect(service.historyLoads, 1);
    expect(find.byType(DropdownButtonFormField<String>), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    auth.dispose();
  });

  testWidgets(
    'leaving game page before response does not notify a disposed view',
    (tester) async {
      final service = _Service()..pending = Completer<List<ModelGameItem>>();
      final auth = _Auth();
      await tester.pumpWidget(_app(service, auth));
      await tester.pumpWidget(const SizedBox.shrink());
      service.pending!.complete([_game('A', 'Game', 1)]);
      await tester.pump();
      expect(service.historyLoads, 0);
      expect(tester.takeException(), isNull);
      auth.dispose();
    },
  );
}
