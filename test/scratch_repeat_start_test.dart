import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/game/service_game.dart';
import 'package:life_pilot/game/steam_scratch/blockly_parser.dart' as scratch;
import 'package:life_pilot/game/steam_scratch/controller_game_steam_scratch.dart'
    as sc;
import 'package:life_pilot/game/steam_scratch/model_game_steam_scratch_level.dart'
    as sl;
import 'package:life_pilot/game/steam_scratch_maze/blockly_parser.dart' as maze;
import 'package:life_pilot/game/steam_scratch_maze/controller_game_steam_scratch_maze.dart'
    as mc;
import 'package:life_pilot/game/steam_scratch_maze/model_game_steam_scratch_maze_level.dart'
    as ml;

const _three = {
  'xml':
      '<xml><block type="forward"><next><block type="forward"><next><block type="forward"/></next></block></next></block></xml>',
};
const _one = {'xml': '<xml><block type="forward"/></xml>'};

dynamic _game(bool isMaze, Future<void> Function(Duration) delay) => isMaze
    ? mc.ControllerGameSteamScratchMaze(
        userName: 'test',
        service: ServiceGame(),
        gameId: 'test',
        delay: delay,
        level: ml.ModelGameSteamScratchMazeLevel(
          levelNumber: 1,
          obstacles: [],
          fruits: [],
          treasure: ml.ModelGameSteamScratchMazeTreasure(x: 20, y: 20),
        ),
      )
    : sc.ControllerGameSteamScratch(
        userName: 'test',
        service: ServiceGame(),
        gameId: 'test',
        delay: delay,
        level: sl.ModelGameSteamScratchLevel(
          levelNumber: 1,
          obstacles: [],
          fruits: [],
          treasure: sl.ModelGameSteamScratchTreasure(x: 20, y: 20),
        ),
      );

Future<void> _start(
  dynamic game,
  bool isMaze,
  Map<String, dynamic> data,
) async {
  if (isMaze) {
    await (game as mc.ControllerGameSteamScratchMaze).restartAndExecute(
      maze.parseBlocklyJson(data),
    );
  } else {
    await (game as sc.ControllerGameSteamScratch).restartAndExecute(
      scratch.parseBlocklyJson(data),
    );
  }
}

void main() {
  for (final isMaze in [false, true]) {
    final name = isMaze ? 'maze' : 'scratch';
    test(
      '$name repeated starts do not accumulate parsed steps or position',
      () async {
        final game = _game(isMaze, (_) async {});
        addTearDown(() => game.dispose());
        await _start(game, isMaze, _three);
        expect(game.state.x, 3);
        await _start(game, isMaze, _three);
        expect(game.state.x, 3);
        await _start(game, isMaze, _one);
        expect(game.state.x, 1);
        await _start(game, isMaze, {'xml': '<xml/>'});
        expect(game.state.x, 0);
      },
    );
    test(
      '$name starting again during movement cancels remaining old steps',
      () async {
        final paused = Completer<void>();
        var pauseOnce = true;
        final game = _game(isMaze, (duration) {
          if (duration.inMilliseconds == 400 && pauseOnce) {
            pauseOnce = false;
            return paused.future;
          }
          return Future<void>.value();
        });
        addTearDown(() => game.dispose());
        final first = _start(game, isMaze, _three);
        await Future<void>.delayed(Duration.zero);
        expect(game.state.x, 1);
        await _start(game, isMaze, _one);
        expect(game.state.x, 1);
        paused.complete();
        await first;
        expect(game.state.x, 1);
      },
    );
  }
}
