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
}
