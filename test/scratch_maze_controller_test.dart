import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/game/service_game.dart';
import 'package:life_pilot/game/steam_scratch_maze/controller_game_steam_scratch_maze.dart';
import 'package:life_pilot/game/steam_scratch_maze/model_game_steam_scratch_maze_level.dart';

class _BlockingCommand extends Command {
  _BlockingCommand(this.release);

  final Completer<void> release;
  int executions = 0;

  @override
  Future<bool> execute(ControllerGameSteamScratchMaze game) async {
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
  test('scratch maze ignores a second command run while one is active',
      () async {
    final controller = ControllerGameSteamScratchMaze(
      userName: 'test-user',
      service: ServiceGame(),
      gameId: 'test-game',
      level: ModelGameSteamScratchMazeLevel(
        levelNumber: 1,
        obstacles: [],
        fruits: [],
        treasure: ModelGameSteamScratchMazeTreasure(x: 2, y: 2),
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

  test('scratch maze detects the treasure and retries a failed save', () async {
    final service = _FailOnceGameService();
    final controller = ControllerGameSteamScratchMaze(
      userName: 'test-user',
      service: service,
      gameId: 'test-game',
      level: ModelGameSteamScratchMazeLevel(
        levelNumber: 1,
        obstacles: [],
        fruits: [],
        treasure: ModelGameSteamScratchMazeTreasure(x: 1, y: 0),
      ),
    );

    await expectLater(controller.moveForward(), throwsStateError);
    expect(controller.state.treasureCollected, isFalse);
    expect(controller.state.score, 0);

    controller.resetGame();
    expect(await controller.moveForward(), isTrue);
    expect(service.attempts, 2);
    controller.dispose();
  });
}
