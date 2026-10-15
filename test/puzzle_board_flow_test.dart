import 'dart:async';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/game/puzzle_map/controller_game_puzzle_map.dart';
import 'package:life_pilot/game/puzzle_map/model_game_puzzle_map.dart';
import 'package:life_pilot/game/service_game.dart';

void rotate(List<ModelGamePuzzlePiece> pieces) {
  for (final piece in pieces) {
    piece.currentIndex = (piece.correctIndex + 1) % pieces.length;
  }
}

void solve(List<ModelGamePuzzlePiece> pieces) {
  for (final piece in pieces) {
    piece.currentIndex = piece.correctIndex;
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

void main() {
  group('puzzle board model', () {
    test('landscape portrait and small grids retain original sizing', () {
      final landscape = ModelPuzzleBoard.fromImage(400, 300, 4);
      final portrait = ModelPuzzleBoard.fromImage(300, 400, 4);
      final small = ModelPuzzleBoard.fromImage(100, 100, 2);
      expect((landscape.rows, landscape.cols), (4, 5));
      expect((portrait.rows, portrait.cols), (5, 4));
      expect((small.rows, small.cols), (3, 3));
      expect(landscape.completionScore, 200);
    });
    test('invalid dimensions are rejected', () {
      expect(() => ModelPuzzleBoard.fromImage(0, 300, 4), throwsArgumentError);
      expect(() => ModelPuzzleBoard.fromImage(300, -1, 4), throwsArgumentError);
      expect(
        () => ModelPuzzleBoard.fromImage(300, 300, 0),
        throwsArgumentError,
      );
    });
    test(
      'seeded shuffle is reproducible and pieces container is immutable',
      () {
        final a = ModelPuzzleBoard.fromImage(400, 300, 4, random: Random(7));
        final b = ModelPuzzleBoard.fromImage(400, 300, 4, random: Random(7));
        expect(
          a.pieces.map((p) => p.correctIndex),
          b.pieces.map((p) => p.correctIndex),
        );
        expect(() => a.pieces.clear(), throwsUnsupportedError);
      },
    );
    test(
      'swap can solve two misplaced pieces without moving locked pieces',
      () {
        final board = ModelPuzzleBoard.fromImage(400, 300, 4);
        solve(board.pieces);
        final a = board.pieces.firstWhere((p) => p.correctIndex == 0);
        final b = board.pieces.firstWhere((p) => p.correctIndex == 1);
        a.currentIndex = 1;
        b.currentIndex = 0;
        expect(board.moveTo(a, 2), false);
        expect(board.moveTo(a, 0), true);
        expect(board.isSolved, true);
        expect(board.moveTo(a, 1), false);
      },
    );
    test('foreign and out-of-bounds moves cannot change the board', () {
      final board = ModelPuzzleBoard.fromImage(400, 300, 4);
      rotate(board.pieces);
      final piece = board.pieces.first;
      final before = board.pieces.map((p) => p.currentIndex).toList();
      expect(
        board.moveTo(
          ModelGamePuzzlePiece(
            correctIndex: piece.correctIndex,
            currentIndex: piece.currentIndex,
          ),
          0,
        ),
        false,
      );
      expect(board.moveTo(piece, -1), false);
      expect(board.moveTo(piece, board.pieces.length), false);
      expect(board.pieces.map((p) => p.currentIndex), before);
    });
    test('finger margin and edge clamping remain unchanged', () {
      final board = ModelPuzzleBoard.fromImage(400, 300, 4);
      rotate(board.pieces);
      final piece = board.pieces.firstWhere((p) => p.correctIndex == 0);
      expect(
        board.moveBy(piece, dx: 8.5, dy: 0, tileWidth: 10, tileHeight: 10),
        true,
      );
      expect(piece.currentIndex, 2);
      rotate(board.pieces);
      expect(
        board.moveBy(
          piece,
          dx: 10000,
          dy: 10000,
          tileWidth: 10,
          tileHeight: 10,
        ),
        true,
      );
      expect(piece.currentIndex, board.pieces.length - 1);
    });
    test('zero and nonfinite drag geometry is ignored', () {
      final board = ModelPuzzleBoard.fromImage(400, 300, 4);
      rotate(board.pieces);
      final piece = board.pieces.first;
      expect(
        board.moveBy(piece, dx: 1, dy: 1, tileWidth: 0, tileHeight: 10),
        false,
      );
      expect(
        board.moveBy(
          piece,
          dx: double.nan,
          dy: 1,
          tileWidth: 10,
          tileHeight: 10,
        ),
        false,
      );
      expect(
        board.moveBy(
          piece,
          dx: 1,
          dy: 1,
          tileWidth: double.infinity,
          tileHeight: 10,
        ),
        false,
      );
    });
    test('random swaps preserve unique positions and fixed pieces', () {
      final random = Random(42);
      final board = ModelPuzzleBoard.fromImage(400, 300, 4, random: random);
      for (var i = 0; i < 500; i++) {
        final locked = board.pieces
            .where((p) => p.currentIndex == p.correctIndex)
            .toList();
        board.moveTo(
          board.pieces[random.nextInt(board.pieces.length)],
          random.nextInt(board.pieces.length),
        );
        expect(
          board.pieces.map((p) => p.currentIndex).toSet().length,
          board.pieces.length,
        );
        expect(locked.every((p) => p.currentIndex == p.correctIndex), true);
      }
    });
  });

  late Service service;
  late ControllerGamePuzzleMap controller;
  late DateTime time;
  setUp(() {
    service = Service();
    time = DateTime(2026);
    controller = ControllerGamePuzzleMap(
      userName: 'user',
      service: service,
      gameId: 'game',
      gameLevel: 1,
      random: Random(7),
      now: () => time,
    );
  });
  tearDown(() {
    if (!controller.notifierDisposed) controller.dispose();
  });

  test('uninitialized result is safe and makes no save request', () async {
    expect(await controller.checkResult(), false);
    expect(service.requests, isEmpty);
    expect(controller.pieces, isEmpty);
  });
  test('drag notifications are throttled and final offset is cleared', () {
    controller.setGridSize(400, 300, 4);
    rotate(controller.pieces);
    var notifications = 0;
    controller.addListener(() => notifications++);
    final piece = controller.pieces.first;
    controller.updateDrag(piece, const Offset(1, 0));
    time = time.add(const Duration(milliseconds: 5));
    controller.updateDrag(piece, const Offset(1, 0));
    time = time.add(const Duration(milliseconds: 12));
    controller.updateDrag(piece, const Offset(1, 0));
    expect(notifications, 2);
    expect(controller.dragOffsets[piece.currentIndex], const Offset(3, 0));
    controller.endDrag(piece, 10, 10);
    expect(notifications, 3);
    expect(controller.dragOffsets, isEmpty);
    expect(() => controller.dragOffsets.clear(), throwsUnsupportedError);
  });
  test(
    'reset rejects stale pieces and invalid reset preserves existing board',
    () {
      controller.setGridSize(400, 300, 4);
      rotate(controller.pieces);
      final stale = controller.pieces.first;
      final revision = controller.boardRevision;
      expect(() => controller.setGridSize(0, 300, 4), throwsArgumentError);
      expect(controller.boardRevision, revision);
      controller.setGridSize(400, 300, 5);
      controller.updateDrag(stale, const Offset(20, 20));
      controller.endDrag(stale, 10, 10);
      expect(controller.dragOffsets, isEmpty);
    },
  );
  test(
    'late success from old board cannot report new board completed',
    () async {
      controller.setGridSize(400, 300, 4);
      solve(controller.pieces);
      final old = controller.checkResult();
      controller.setGridSize(400, 300, 5);
      service.requests[0].complete();
      expect(await old, false);
      expect(controller.score, 0);
    },
  );
  test('old failure cannot reset saved state for the new board', () async {
    controller.setGridSize(400, 300, 4);
    solve(controller.pieces);
    final old = controller.checkResult();
    controller.setGridSize(400, 300, 5);
    solve(controller.pieces);
    final current = controller.checkResult();
    service.requests[0].completeError(StateError('old save failed'));
    expect(await old, false);
    service.requests[1].complete();
    expect(await current, true);
    expect(await controller.checkResult(), true);
    expect(service.scores, [200.0, 350.0]);
  });
  test('current save failure remains retryable', () async {
    controller.setGridSize(400, 300, 4);
    solve(controller.pieces);
    final pending = controller.checkResult();
    final failure = expectLater(pending, throwsStateError);
    service.requests[0].completeError(StateError('offline'));
    await failure;
    final retry = controller.checkResult();
    service.requests[1].complete();
    expect(await retry, true);
    expect(service.scores.length, 2);
  });
  test('disposal prevents result completion drag and resets', () async {
    controller.setGridSize(400, 300, 4);
    solve(controller.pieces);
    final pending = controller.checkResult();
    final revision = controller.boardRevision;
    final piece = controller.pieces.first;
    controller.dispose();
    service.requests[0].complete();
    expect(await pending, false);
    controller.setGridSize(400, 300, 5);
    controller.updateDrag(piece, const Offset(10, 10));
    expect(controller.boardRevision, revision);
    expect(controller.dragOffsets, isEmpty);
  });
}
