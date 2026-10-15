import 'dart:async';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/game/service_game.dart';
import 'package:life_pilot/game/steam_polyomino/controller_game_steam_polyomino.dart';
import 'package:life_pilot/game/steam_polyomino/model_game_steam_polyomino.dart';
import 'package:life_pilot/game/steam_polyomino/model_polyomino_board.dart';

ModelGamePolyominoPipeBlock block(int id) => ModelGamePolyominoPipeBlock(
  id: id,
  cells: [const Point(0, 0)],
  connections: [
    [false, true, false, true],
  ],
);
ModelGamePolyominoLevelData level() => ModelGamePolyominoLevelData(
  rows: 3,
  cols: 4,
  start: const Point(0, 1),
  goal: const Point(3, 1),
  availableBlocks: [block(1), block(2)],
  path: [
    const Point(0, 1),
    const Point(1, 1),
    const Point(2, 1),
    const Point(3, 1),
  ],
);

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

void solve(ControllerGameSteamPolyomino controller) {
  controller.placeBlock(controller.levelData.availableBlocks[0].clone(), 1, 1);
  controller.placeBlock(controller.levelData.availableBlocks[1].clone(), 2, 1);
}

void main() {
  group('polyomino board model', () {
    late ModelPolyominoBoard board;
    setUp(() => board = ModelPolyominoBoard(level()));
    test('initial endpoints face the path and board is incomplete', () {
      expect(board.grid[1][0].type, EnumPolyominoTileType.start);
      expect(board.grid[1][0].right, true);
      expect(board.grid[1][3].left, true);
      expect(board.isComplete, false);
    });
    test('placement supports clones and indexes by id', () {
      final piece = block(1);
      expect(board.placeBlock(piece, 1, 1), true);
      expect(board.blockById(1), same(piece));
      expect(board.grid[1][1].blockId, 1);
      expect(board.grid[1][1].left, true);
      expect(board.revision, 1);
    });
    test(
      'endpoints occupied cells and negative coordinates reject direct placement',
      () {
        final piece = block(1);
        expect(board.canPlaceBlock(piece, 0, 1), false);
        expect(board.canPlaceBlock(piece, 3, 1), false);
        expect(board.canPlaceBlock(piece, -1, 0), false);
        board.placeBlock(piece, 1, 1);
        expect(board.canPlaceBlock(block(2), 1, 1), false);
      },
    );
    test('nearby fallback retains the original upward-first order', () {
      final piece = block(1);
      expect(board.placeBlock(piece, 0, 1), true);
      expect((piece.originX, piece.originY), (0, 0));
      expect(board.grid[1][0].type, EnumPolyominoTileType.start);
    });
    test('duplicate and unknown ids cannot consume more board cells', () {
      board.placeBlock(block(1), 1, 1);
      expect(board.placeBlock(block(1), 2, 1), false);
      expect(board.placeBlock(block(99), 2, 1), false);
      expect(board.placedBlocks.length, 1);
    });
    test(
      'malformed empty duplicate or negative cells are rejected atomically',
      () {
        final variants = [
          block(1)..cells = [],
          block(1)..connections = [],
          block(1)
            ..connections = [
              [true],
            ],
          block(1)..cells = [const Point(-1, 0)],
          block(1)
            ..cells = [const Point(0, 0), const Point(0, 0)]
            ..connections = [
              [true, false, false, false],
              [true, false, false, false],
            ],
        ];
        for (final piece in variants) {
          expect(board.placeBlock(piece, 1, 1), false);
        }
        expect(board.placedBlocks, isEmpty);
        expect(board.revision, 0);
      },
    );
    test(
      'removal uses stored occupied cells even if drag object is mutated',
      () {
        final piece = block(1);
        board.placeBlock(piece, 1, 1);
        piece.cells = [const Point(999, 999)];
        piece.originX = 999;
        expect(board.removeBlock(piece), true);
        expect(board.grid[1][1].type, EnumPolyominoTileType.empty);
        expect(board.grid[1][1].left, false);
        expect(board.blockById(1), null);
        expect(board.removeBlock(piece), false);
      },
    );
    test('foreign remove cannot clear placed block or endpoints', () {
      final piece = block(1);
      board.placeBlock(piece, 1, 1);
      final foreign = block(1)
        ..originX = 0
        ..originY = 1;
      expect(board.removeBlock(foreign), false);
      expect(board.grid[1][1].blockId, 1);
      expect(board.grid[1][0].type, EnumPolyominoTileType.start);
    });
    test('completion requires connected path and all available blocks', () {
      board.placeBlock(block(1), 1, 1);
      expect(board.isComplete, false);
      final wrong = block(2)
        ..connections = [
          [true, false, true, false],
        ];
      board.placeBlock(wrong, 2, 1);
      expect(board.isComplete, false);
      board.removeBlock(wrong);
      board.placeBlock(block(2), 2, 1);
      expect(board.isComplete, true);
    });
    test('grid and placed list containers are read-only', () {
      expect(() => board.grid.clear(), throwsUnsupportedError);
      expect(() => board.grid.first.clear(), throwsUnsupportedError);
      expect(() => board.placedBlocks.clear(), throwsUnsupportedError);
    });
    test(
      'hint directions can be cleared without changing placement revision',
      () {
        board.highlightHint();
        expect(board.grid[1][1].highlight, true);
        expect(board.grid[1][1].hintDirs, [false, true, false, true]);
        board.clearHint();
        expect(board.grid[1][1].highlight, false);
        expect(board.revision, 0);
      },
    );
    test('invalid level is rejected before endpoint indexing', () {
      expect(
        () => ModelPolyominoBoard(
          ModelGamePolyominoLevelData(
            rows: 0,
            cols: 0,
            start: const Point(0, 0),
            goal: const Point(0, 0),
            availableBlocks: [],
            path: [],
          ),
        ),
        throwsArgumentError,
      );
    });
  });

  late Service service;
  late ControllerGameSteamPolyomino controller;
  setUp(() {
    service = Service();
    controller = ControllerGameSteamPolyomino(
      userName: 'user',
      service: service,
      gameId: 'game',
      gameLevel: 1,
      level: level(),
    );
  });
  tearDown(() {
    if (!controller.notifierDisposed) controller.dispose();
  });
  test('accepted edits notify once and invalid edits do not notify', () {
    var notifications = 0;
    controller.addListener(() => notifications++);
    final piece = block(1);
    controller.placeBlock(piece, 1, 1);
    controller.placeBlock(block(1), 2, 1);
    controller.removeBlock(block(1));
    expect(notifications, 1);
    controller.removeBlock(piece);
    expect(notifications, 2);
  });
  test('incomplete board does not save', () async {
    expect(await controller.isLevelComplete(), false);
    expect(service.requests, isEmpty);
  });
  test('score save is deduplicated and uses unchanged block score', () async {
    solve(controller);
    final pending = controller.isLevelComplete();
    expect(await controller.isLevelComplete(), true);
    service.requests[0].complete();
    expect(await pending, true);
    expect(service.scores, [20.0]);
  });
  test('save failure can be retried', () async {
    solve(controller);
    final pending = controller.isLevelComplete();
    final failure = expectLater(pending, throwsStateError);
    service.requests[0].completeError(StateError('offline'));
    await failure;
    final retry = controller.isLevelComplete();
    service.requests[1].complete();
    expect(await retry, true);
    expect(service.scores, [20.0, 20.0]);
  });
  test(
    'board edits during save invalidate the old completion result',
    () async {
      solve(controller);
      final pending = controller.isLevelComplete();
      controller.removeBlock(controller.placedBlocks.first);
      service.requests[0].complete();
      expect(await pending, false);
    },
  );
  test('disposal prevents changes and late completion', () async {
    solve(controller);
    final pending = controller.isLevelComplete();
    final revision = controller.boardRevision;
    final piece = controller.placedBlocks.first;
    controller.dispose();
    controller.removeBlock(piece);
    expect(controller.placeBlock(block(1), 0, 0), false);
    controller.highlightHint();
    controller.clearHint();
    service.requests[0].complete();
    expect(await pending, false);
    expect(controller.boardRevision, revision);
  });
}
