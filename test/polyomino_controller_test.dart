import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/game/service_game.dart';
import 'package:life_pilot/game/steam_polyomino/controller_game_steam_polyomino.dart';
import 'package:life_pilot/game/steam_polyomino/model_game_steam_polyomino.dart';

class _BlockingGameService extends ServiceGame {
  final Completer<void> release = Completer<void>();
  int savedScores = 0;

  @override
  Future<void> saveUserGameScore({
    required String newUserName,
    required double newScore,
    required String? newGameId,
    bool? newIsPass,
  }) async {
    savedScores++;
    await release.future;
  }
}

void main() {
  test('polyomino saves a completed level only once', () async {
    final service = _BlockingGameService();
    final start = const Point<int>(0, 0);
    final goal = const Point<int>(1, 0);
    final controller = ControllerGameSteamPolyomino(
      userName: 'test-user',
      service: service,
      gameId: 'test-game',
      gameLevel: 1,
      level: ModelGamePolyominoLevelData(
        rows: 1,
        cols: 2,
        start: start,
        goal: goal,
        availableBlocks: [],
        path: [start, goal],
      ),
    );

    final firstCheck = controller.isLevelComplete();
    final secondCheck = controller.isLevelComplete();

    expect(await secondCheck, isTrue);
    expect(service.savedScores, 1);

    service.release.complete();
    expect(await firstCheck, isTrue);
  });
}
