import 'dart:async';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/game/service_game.dart';
import 'package:life_pilot/game/steam_monomino/controller_game_steam_monomino.dart';
import 'package:life_pilot/game/steam_monomino/model_game_steam_monomino.dart';

typedef Direction = EnumMonominoTileDirection;

class FixtureLevel extends ModelGameMonominoLevel {
  FixtureLevel() : super(levelNumber: 1, rows: 3, cols: 3, random: Random(1)) {
    board = List.generate(
      3,
      (_) => List.generate(3, (_) => ModelGameMonominoTile()),
    );
    start = const Point(0, 0);
    goal = const Point(2, 2);
    board[0][0].isStartP = true;
    board[2][2].isGoalP = true;
    board[1][0].isObstacle = true;
    board[1][2]
      ..isFixedArrow = true
      ..direction = Direction.down;
    remainingFixed = [const Point(1, 2)];
    tilesToPlace = [Direction.right, Direction.right, Direction.down];
    solutionPath = [
      const Point(0, 0),
      const Point(0, 1),
      const Point(0, 2),
      const Point(1, 2),
      const Point(2, 2),
    ];
  }
}

class Service extends ServiceGame {
  final requests = <Completer<void>>[];
  final scores = <double>[];
  @override
  Future<void> saveUserGameScore({
    required String newUserName,
    required double newScore,
    required String? newGameId,
    bool? newIsPass,
  }) async {
    scores.add(newScore);
    final pending = Completer<void>();
    requests.add(pending);
    await pending.future;
  }
}

void solve(ControllerGameSteamMonomino controller) {
  controller.placeTile(0, 0, null, null, Direction.right);
  controller.placeTile(0, 1, null, null, Direction.right);
  controller.placeTile(0, 2, null, null, Direction.down);
}

void main() {
  group('monomino session model', () {
    late FixtureLevel level;
    late ModelMonominoSession session;
    setUp(() {
      level = FixtureLevel();
      session = ModelMonominoSession(level);
    });
    test('bank placement consumes one tile and one step', () {
      expect(session.place(0, 0, null, null, Direction.right), true);
      expect(level.board[0][0].direction, Direction.right);
      expect(session.remainingCounts[Direction.right], 1);
      expect(session.remainingTiles.length, 2);
      expect(session.usedSteps, 1);
    });
    test('replacing a tile returns the previous direction to inventory', () {
      session.place(0, 0, null, null, Direction.right);
      session.place(0, 0, null, null, Direction.down);
      expect(session.remainingCounts[Direction.right], 2);
      expect(session.remainingCounts[Direction.down], null);
      expect(session.remainingTiles.length, 2);
      expect(session.usedSteps, 2);
    });
    test('moving board tile conserves inventory and clears source', () {
      session.place(0, 0, null, null, Direction.right);
      expect(session.place(0, 1, 0, 0, null), true);
      expect(level.board[0][0].direction, Direction.empty);
      expect(level.board[0][1].direction, Direction.right);
      expect(session.remainingTiles.length, 2);
    });
    test('moving onto another tile returns the replaced tile', () {
      session.place(0, 0, null, null, Direction.right);
      session.place(0, 1, null, null, Direction.down);
      session.place(0, 1, 0, 0, null);
      expect(session.remainingCounts[Direction.down], 1);
      expect(session.remainingTiles.length, 2);
    });
    test(
      'missing empty or exhausted bank directions are rejected atomically',
      () {
        expect(session.place(0, 0, null, null, null), false);
        expect(session.place(0, 0, null, null, Direction.empty), false);
        expect(session.place(0, 0, null, null, Direction.up), false);
        session.place(0, 0, null, null, Direction.down);
        expect(session.place(0, 1, null, null, Direction.down), false);
        expect(session.usedSteps, 1);
        expect(session.remainingTiles.length, 2);
      },
    );
    test(
      'fixed obstacles empty sources and malformed coordinates are rejected',
      () {
        expect(session.place(1, 0, null, null, Direction.right), false);
        expect(session.place(1, 2, null, null, Direction.right), false);
        expect(session.place(0, 0, 1, 2, null), false);
        expect(session.place(0, 0, 1, 1, null), false);
        expect(session.place(-1, 0, null, null, Direction.right), false);
        expect(session.place(0, 0, -1, 0, null), false);
        expect(session.place(0, 0, 0, null, Direction.right), false);
        expect(session.place(0, 0, 0, 0, Direction.right), false);
        expect(session.usedSteps, 0);
        expect(session.remainingTiles.length, 3);
      },
    );
    test(
      'reset restores inventory steps and highlights while keeping fixed arrow',
      () {
        session.place(0, 0, null, null, Direction.right);
        level.highlightPath(level.solutionPath);
        session.reset();
        expect(session.usedSteps, 0);
        expect(session.remainingTiles.length, 3);
        expect(level.board[0][0].direction, Direction.empty);
        expect(level.board[1][2].direction, Direction.down);
        expect(level.board.expand((r) => r).any((t) => t.isHighlighted), false);
      },
    );
    test('inventory exposes stable read-only views', () {
      final counts = session.remainingCounts;
      expect(() => counts.clear(), throwsUnsupportedError);
      expect(() => session.remainingTiles.clear(), throwsUnsupportedError);
      session.place(0, 0, null, null, Direction.right);
      expect(identical(counts, session.remainingCounts), true);
      expect(counts[Direction.right], 1);
    });
    test('completion score preserves tile and step formula', () {
      session.place(0, 0, null, null, Direction.right);
      session.place(0, 1, null, null, Direction.right);
      session.place(0, 2, null, null, Direction.down);
      expect(level.checkPath(List.of(level.remainingFixed)), true);
      expect(session.completionScore, 15);
    });
    test('unchanged direction does not notify tile listeners', () {
      final tile = ModelGameMonominoTile();
      var notifications = 0;
      tile.addListener(() => notifications++);
      tile.direction = Direction.empty;
      tile.direction = Direction.right;
      tile.direction = Direction.right;
      expect(notifications, 1);
      tile.dispose();
    });
    test('seeded generation is reproducible', () {
      final a = ModelGameMonominoLevel(
        levelNumber: 5,
        rows: 10,
        cols: 10,
        random: Random(42),
      );
      final b = ModelGameMonominoLevel(
        levelNumber: 5,
        rows: 10,
        cols: 10,
        random: Random(42),
      );
      expect(a.solutionPath, b.solutionPath);
      expect(a.remainingFixed, b.remainingFixed);
      expect(a.tilesToPlace, b.tilesToPlace);
      expect(
        a.board.expand((r) => r).map((t) => t.isObstacle),
        b.board.expand((r) => r).map((t) => t.isObstacle),
      );
    });
  });

  late Service service;
  late ControllerGameSteamMonomino controller;
  setUp(() {
    service = Service();
    controller = ControllerGameSteamMonomino(
      userName: 'user',
      service: service,
      gameId: 'game',
      gameLevel: 1,
      level: FixtureLevel(),
    );
  });
  tearDown(() {
    if (!controller.notifierDisposed) controller.dispose();
  });
  test('invalid placement does not notify or change revision', () {
    var notifications = 0;
    controller.addListener(() => notifications++);
    final revision = controller.boardRevision;
    controller.placeTile(-1, 0, null, null, Direction.right);
    expect(notifications, 0);
    expect(controller.boardRevision, revision);
  });
  test('incomplete path does not save or consume fixed arrows', () async {
    expect(await controller.checkPath(), false);
    expect(controller.remainingFixed, [const Point(1, 2)]);
    expect(service.requests, isEmpty);
  });
  test('save failure retry does not add the same score twice', () async {
    solve(controller);
    final pending = controller.checkPath();
    final failure = expectLater(pending, throwsStateError);
    service.requests[0].completeError(StateError('offline'));
    await failure;
    final retry = controller.checkPath();
    service.requests[1].complete();
    expect(await retry, true);
    expect(controller.score, 15);
    expect(service.scores, [15.0, 15.0]);
  });
  test('completed board saves only once and reset clears score', () async {
    solve(controller);
    final pending = controller.checkPath();
    expect(await controller.checkPath(), true);
    service.requests[0].complete();
    expect(await pending, true);
    expect(service.requests.length, 1);
    controller.resetLevel();
    expect(controller.score, 0);
    expect(controller.usedSteps, 0);
    expect(controller.remainingTiles.length, 3);
  });
  test('old save failure cannot invalidate a newer saved round', () async {
    solve(controller);
    final old = controller.checkPath();
    controller.resetLevel();
    solve(controller);
    final current = controller.checkPath();
    service.requests[0].completeError(StateError('old request'));
    expect(await old, false);
    service.requests[1].complete();
    expect(await current, true);
    expect(await controller.checkPath(), true);
    expect(service.requests.length, 2);
  });
  test('reset during save ignores late success', () async {
    solve(controller);
    final pending = controller.checkPath();
    controller.resetLevel();
    service.requests[0].complete();
    expect(await pending, false);
    expect(controller.score, 0);
  });
  test('disposed controller cannot modify or complete a round', () async {
    solve(controller);
    final pending = controller.checkPath();
    final revision = controller.boardRevision;
    controller.dispose();
    service.requests[0].complete();
    expect(await pending, false);
    controller.resetLevel();
    controller.placeTile(0, 0, null, null, Direction.right);
    controller.showHint();
    controller.clearHint();
    expect(controller.boardRevision, revision);
    expect(await controller.checkPath(), false);
  });
}
