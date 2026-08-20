import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/game/puzzle_map/controller_game_puzzle_map.dart';
import 'package:life_pilot/game/service_game.dart';

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

void _solve(ControllerGamePuzzleMap controller) {
  for (final piece in controller.pieces) {
    piece.currentIndex = piece.correctIndex;
  }
}

void main() {
  test('puzzle map saves each completed grid only once', () async {
    final service = _BlockingGameService();
    final controller = ControllerGamePuzzleMap(
      userName: 'test-user',
      service: service,
      gameId: 'test-game',
      gameLevel: 1,
    );
    controller.setGridSize(400, 300, 4);
    _solve(controller);

    final firstCheck = controller.checkResult();
    final secondCheck = controller.checkResult();

    expect(await secondCheck, isTrue);
    expect(service.savedScores, 1);

    service.release.complete();
    expect(await firstCheck, isTrue);

    controller.setGridSize(400, 300, 5);
    _solve(controller);
    expect(await controller.checkResult(), isTrue);
    expect(service.savedScores, 2);
  });
}
