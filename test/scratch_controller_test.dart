import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/game/service_game.dart';
import 'package:life_pilot/game/steam_scratch/controller_game_steam_scratch.dart';
import 'package:life_pilot/game/steam_scratch/model_game_steam_scratch_level.dart';

class _BlockingCommand extends Command {
  _BlockingCommand(this.release);

  final Completer<void> release;
  int executions = 0;

  @override
  Future<bool> execute(ControllerGameSteamScratch game) async {
    executions++;
    await release.future;
    return true;
  }
}

class _FailOnceGameService extends ServiceGame {
  int attempts = 0;

  @override
  Future<void> saveUserGameScore({
    required String newUserName,
    required double newScore,
    required String? newGameId,
    bool? newIsPass,
  }) async {
    attempts++;
    if (attempts == 1) throw StateError('temporary save failure');
  }
}

void main() {
  test('scratch ignores a second command run while one is active', () async {
    final controller = ControllerGameSteamScratch(
      userName: 'test-user',
      service: ServiceGame(),
      gameId: 'test-game',
      level: ModelGameSteamScratchLevel(
        levelNumber: 1,
        obstacles: [],
        fruits: [],
        treasure: ModelGameSteamScratchTreasure(x: 2, y: 2),
      ),
    );
    final release = Completer<void>();
    final command = _BlockingCommand(release);

    final firstRun = controller.executeCommands([command]);
    await controller.executeCommands([command]);

    expect(command.executions, 1);
    release.complete();
    await firstRun;

    controller.dispose();
    controller.dispose();
  });

  test('scratch movement stops safely when disposed during animation',
      () async {
    final controller = ControllerGameSteamScratch(
      userName: 'test-user',
      service: ServiceGame(),
      gameId: 'test-game',
      level: ModelGameSteamScratchLevel(
        levelNumber: 1,
        obstacles: [],
        fruits: [],
        treasure: ModelGameSteamScratchTreasure(x: 2, y: 2),
      ),
    );

    final movement = controller.moveForward();
    controller.dispose();

    expect(await movement, isFalse);
  });

  test('scratch can retry after a score save failure', () async {
    final service = _FailOnceGameService();
    final controller = ControllerGameSteamScratch(
      userName: 'test-user',
      service: service,
      gameId: 'test-game',
      level: ModelGameSteamScratchLevel(
        levelNumber: 1,
        obstacles: [],
        fruits: [],
        treasure: ModelGameSteamScratchTreasure(x: 1, y: 0),
      ),
    );

    await expectLater(controller.moveForward(), throwsStateError);
    expect(controller.state.treasureCollected, isFalse);
    expect(controller.state.score, 0);

    controller.resetGame();
    expect(await controller.moveForward(), isFalse);
    expect(service.attempts, 2);
    controller.dispose();
  });
}
