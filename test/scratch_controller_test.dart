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
}
