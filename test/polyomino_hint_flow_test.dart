import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/game/service_game.dart';
import 'package:life_pilot/game/steam_polyomino/controller_game_steam_polyomino.dart';
import 'package:life_pilot/game/steam_polyomino/model_game_steam_polyomino.dart';
import 'package:life_pilot/game/steam_polyomino/model_polyomino_board.dart';

ModelGamePolyominoLevelData level() => ModelGamePolyominoLevelData(
  rows: 3,
  cols: 4,
  start: const Point(0, 1),
  goal: const Point(3, 1),
  availableBlocks: [
    ModelGamePolyominoPipeBlock(
      id: 1,
      cells: [const Point(0, 0)],
      connections: [
        [false, true, false, true],
      ],
    ),
  ],
  path: [
    const Point(0, 1),
    const Point(1, 1),
    const Point(2, 1),
    const Point(3, 1),
  ],
);

ControllerGameSteamPolyomino controller() => ControllerGameSteamPolyomino(
  userName: 'test',
  service: ServiceGame(),
  gameId: 'test',
  gameLevel: 1,
  level: level(),
);

void main() {
  group('hint model', () {
    test('clearing an empty hint is a no-op', () {
      expect(ModelPolyominoBoard(level()).clearHint(), false);
    });
    test('repeated hint keeps existing directions without a state change', () {
      final board = ModelPolyominoBoard(level());
      expect(board.highlightHint(), true);
      final directions = board.grid[1][1].hintDirs;
      expect(board.highlightHint(), false);
      expect(board.grid[1][1].hintDirs, same(directions));
      expect(directions, [false, true, false, true]);
    });
    test('show and clear preserve endpoints placement and board revision', () {
      final data = level();
      final board = ModelPolyominoBoard(data);
      final piece = data.availableBlocks.single.clone();
      expect(board.placeBlock(piece, 1, 1), true);
      final revision = board.revision;
      board.highlightHint();
      expect(board.grid[1][0].highlight, false);
      expect(board.grid[1][3].highlight, false);
      expect(board.clearHint(), true);
      expect(board.clearHint(), false);
      expect(board.grid[1][1].hintDirs, null);
      expect(board.grid[1][1].blockId, 1);
      expect(board.grid[1][1].left, true);
      expect(board.revision, revision);
    });
    test('changed path clears old cells and refreshes turn directions', () {
      final data = level();
      final board = ModelPolyominoBoard(data);
      board.highlightHint();
      data.path
        ..clear()
        ..addAll([
          const Point(0, 1),
          const Point(0, 0),
          const Point(1, 0),
          const Point(2, 0),
          const Point(3, 0),
          const Point(3, 1),
        ]);
      expect(board.highlightHint(), true);
      expect(board.grid[1][1].highlight, false);
      expect(board.grid[1][2].hintDirs, null);
      expect(board.grid[0][0].hintDirs, [false, true, true, false]);
      expect(board.grid[0][3].hintDirs, [false, false, true, true]);
      board.clearHint();
      expect(
        board.grid.expand((row) => row).any((tile) => tile.highlight),
        false,
      );
    });
    test('removing a hinted block allows its hint to be restored', () {
      final data = level();
      final board = ModelPolyominoBoard(data);
      final piece = data.availableBlocks.single.clone();
      board.placeBlock(piece, 1, 1);
      board.highlightHint();
      board.removeBlock(piece);
      expect(board.grid[1][1].highlight, false);
      expect(board.highlightHint(), true);
      expect(board.grid[1][1].hintDirs, [false, true, false, true]);
      expect(board.highlightHint(), false);
    });
    test('adjacent endpoints do not create hint state', () {
      final board = ModelPolyominoBoard(
        ModelGamePolyominoLevelData(
          rows: 1,
          cols: 2,
          start: const Point(0, 0),
          goal: const Point(1, 0),
          availableBlocks: [],
          path: [const Point(0, 0), const Point(1, 0)],
        ),
      );
      expect(board.highlightHint(), false);
      expect(board.clearHint(), false);
    });
  });

  testWidgets('temporary hint hides after exactly two seconds', (tester) async {
    final game = controller();
    addTearDown(game.dispose);
    var notifications = 0;
    game.addListener(() => notifications++);
    game.showHint();
    expect(game.grid[1][1].highlight, true);
    await tester.pump(const Duration(milliseconds: 1999));
    expect(game.grid[1][1].highlight, true);
    await tester.pump(const Duration(milliseconds: 1));
    expect(game.grid[1][1].highlight, false);
    expect(notifications, 2);
  });
  testWidgets('repeated hint restarts expiry without redundant notification', (
    tester,
  ) async {
    final game = controller();
    addTearDown(game.dispose);
    var notifications = 0;
    game.addListener(() => notifications++);
    game.showHint();
    await tester.pump(const Duration(seconds: 1));
    game.showHint();
    expect(notifications, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(game.grid[1][1].highlight, true);
    await tester.pump(const Duration(seconds: 1));
    expect(game.grid[1][1].highlight, false);
    expect(notifications, 2);
  });
  testWidgets('manual clear cancels expiry and repeated clear is silent', (
    tester,
  ) async {
    final game = controller();
    addTearDown(game.dispose);
    var notifications = 0;
    game.addListener(() => notifications++);
    game.clearHint();
    game.showHint();
    game.clearHint();
    game.clearHint();
    await tester.pump(const Duration(seconds: 3));
    expect(notifications, 2);
  });
  testWidgets('manual persistent hint cancels old temporary expiry', (
    tester,
  ) async {
    final game = controller();
    addTearDown(game.dispose);
    game.showHint();
    await tester.pump(const Duration(seconds: 1));
    game.highlightHint();
    await tester.pump(const Duration(seconds: 3));
    expect(game.grid[1][1].highlight, true);
    game.clearHint();
  });
  testWidgets('disposal cancels timer and ignores further hint actions', (
    tester,
  ) async {
    final game = controller();
    var notifications = 0;
    game.addListener(() => notifications++);
    game.showHint();
    game.dispose();
    game.showHint();
    game.highlightHint();
    game.clearHint();
    await tester.pump(const Duration(seconds: 3));
    expect(notifications, 1);
  });
  testWidgets('new hint from listener supersedes old scheduling', (
    tester,
  ) async {
    final game = controller();
    addTearDown(game.dispose);
    var first = true;
    game.addListener(() {
      if (!first) return;
      first = false;
      game.showHint(duration: const Duration(seconds: 5));
    });
    game.showHint();
    await tester.pump(const Duration(seconds: 2));
    expect(game.grid[1][1].highlight, true);
    await tester.pump(const Duration(seconds: 3));
    expect(game.grid[1][1].highlight, false);
  });
  testWidgets('clear from listener prevents stale scheduling', (tester) async {
    final game = controller();
    addTearDown(game.dispose);
    game.addListener(() {
      if (game.grid[1][1].highlight) game.clearHint();
    });
    game.showHint();
    expect(game.grid[1][1].highlight, false);
    // No outstanding timer should remain at test completion.
  });
}
