import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/game/service_game.dart';
import 'package:life_pilot/game/widgets_game_fruit_icon.dart';
import 'package:life_pilot/game/steam_scratch_maze/controller_game_steam_scratch_maze.dart';
import 'package:life_pilot/game/steam_scratch_maze/model_game_steam_scratch_maze_level.dart';
import 'package:life_pilot/game/steam_scratch_maze/model_scratch_maze_session.dart';

ModelGameSteamScratchMazeLevel level({
  int x = 3,
  int y = 3,
  List<ModelGameSteamScratchMazeObstacle> walls = const [],
  List<ModelGameSteamScratchMazeFruit> fruits = const [],
}) => ModelGameSteamScratchMazeLevel(
  levelNumber: 1,
  obstacles: walls,
  fruits: fruits,
  treasure: ModelGameSteamScratchMazeTreasure(x: x, y: y),
);
ModelGameSteamScratchMazeObstacle wall(int x, int y) =>
    ModelGameSteamScratchMazeObstacle(x: x, y: y);

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

class CountingCommand extends Command {
  int calls = 0;
  @override
  Future<bool> execute(ControllerGameSteamScratchMaze game) async {
    calls++;
    return true;
  }
}

class BlockingCommand extends Command {
  final release = Completer<void>();
  int calls = 0;
  @override
  Future<bool> execute(ControllerGameSteamScratchMaze game) async {
    calls++;
    await release.future;
    return true;
  }
}

void main() {
  group('maze domain model', () {
    test(
      'walkability rejects walls bounds and does not collect current fruit',
      () {
        final fruit = ModelGameSteamScratchMazeFruit(x: 0, y: 0);
        final model = ModelScratchMazeSession(
          level(walls: [wall(1, 0)], fruits: [fruit]),
        );
        expect(model.isWalkable(1, 0), false);
        expect(model.isWalkable(-1, 0), false);
        expect(model.isWalkable(0, 4), false);
        expect(model.isWalkable(0, 1), true);
        expect(fruit.collected, false);
        expect(model.state.score, 0);
      },
    );
    test('blocked and diagonal steps do not change position', () {
      final model = ModelScratchMazeSession(level(walls: [wall(1, 0)]));
      expect(model.step(1, 0), null);
      expect(model.step(1, 1), null);
      expect((model.state.x, model.state.y), (0, 0));
    });
    test('junction checks use the perpendicular axis', () {
      final model = ModelScratchMazeSession(level(walls: [wall(1, 1)]));
      model.state.x = 1;
      expect(model.hasJunction(1, 0), false);
      expect(model.hasJunction(0, 1), true);
      expect(model.hasJunction(1, 1), false);
    });
    test('fruits at a cell score once each and reset restores collection', () {
      final fruits = [
        ModelGameSteamScratchMazeFruit(x: 1, y: 0),
        ModelGameSteamScratchMazeFruit(x: 1, y: 0, scoreValue: 2),
      ];
      final model = ModelScratchMazeSession(level(fruits: fruits));
      expect(model.step(1, 0)!.events.length, 2);
      model.step(-1, 0);
      model.step(1, 0);
      expect(model.state.score, 3);
      model.reset();
      expect(model.state.score, 0);
      expect(fruits.every((f) => !f.collected), true);
    });
    test('treasure award and rollback preserve fruit score', () {
      final model = ModelScratchMazeSession(
        level(x: 1, y: 0, fruits: [ModelGameSteamScratchMazeFruit(x: 1, y: 0)]),
      );
      final result = model.step(1, 0)!;
      expect(result.needsSave, true);
      expect(model.state.score, 11);
      model.rollbackTreasure();
      expect(model.state.score, 1);
      expect(model.state.treasureCollected, false);
    });
    test('shared fruit presentation retains all six original icons', () {
      const expected = [
        Icons.apple_rounded,
        Icons.card_giftcard_rounded,
        Icons.favorite_rounded,
        Icons.star_rounded,
        Icons.diamond_rounded,
        Icons.cake_rounded,
      ];
      for (final appearance in EnumScratchFruitAppearance.values) {
        expect(gameFruitIcon(appearance), expected[appearance.index]);
      }
    });
  });

  late Service service;
  late ControllerGameSteamScratchMaze controller;
  setUp(() {
    service = Service();
    controller = ControllerGameSteamScratchMaze(
      userName: 'user',
      service: service,
      gameId: 'game',
      level: level(),
      delay: (_) async {},
    );
  });
  tearDown(() => controller.dispose());
  Future<void> flush() => Future<void>.delayed(Duration.zero);
  void treasureLevel() {
    controller.dispose();
    controller = ControllerGameSteamScratchMaze(
      userName: 'user',
      service: service,
      gameId: 'game',
      level: level(x: 1, y: 0),
      delay: (_) async {},
    );
  }

  test('all four commands move exactly one cell at an open junction', () async {
    final moves = <Future<bool> Function()>[
      controller.moveForward,
      controller.moveBackward,
      controller.jumpUp,
      controller.jumpDown,
    ];
    const expected = [(2, 1), (0, 1), (1, 2), (1, 0)];
    for (var i = 0; i < moves.length; i++) {
      controller.resetGame();
      controller.state
        ..x = 1
        ..y = 1;
      expect(await moves[i](), true);
      expect((controller.state.x, controller.state.y), expected[i]);
    }
  });
  for (var direction = 0; direction < 4; direction++) {
    test(
      'direction $direction moves one cell even without a side junction',
      () async {
        controller.dispose();
        final horizontal = direction < 2;
        controller = ControllerGameSteamScratchMaze(
          userName: 'user',
          service: service,
          gameId: 'game',
          level: level(
            x: 6,
            y: 6,
            walls: [
              for (var i = 0; i <= 6; i++) ...[
                if (horizontal) ...[
                  wall(i, 1),
                  wall(i, 3),
                ] else ...[
                  wall(1, i),
                  wall(3, i),
                ],
              ],
            ],
          ),
          delay: (_) async {},
        );
        controller.state
          ..x = 2
          ..y = 2;
        final moves = [
          controller.moveForward,
          controller.moveBackward,
          controller.jumpUp,
          controller.jumpDown,
        ];
        expect(await moves[direction](), true);
        const expected = [(3, 2), (1, 2), (2, 3), (2, 1)];
        expect((controller.state.x, controller.state.y), expected[direction]);
      },
    );
  }
  test(
    'each corridor command moves one cell with one 400ms animation',
    () async {
      controller.dispose();
      final durations = <Duration>[];
      controller = ControllerGameSteamScratchMaze(
        userName: 'user',
        service: service,
        gameId: 'game',
        level: level(
          x: 4,
          y: 2,
          walls: [for (var x = 0; x <= 4; x++) wall(x, 1), wall(3, 0)],
        ),
        delay: (duration) async {
          durations.add(duration);
        },
      );
      expect(await controller.moveForward(), true);
      expect((controller.state.x, controller.state.y), (1, 0));
      expect(durations, [const Duration(milliseconds: 400)]);
      expect(await controller.moveForward(), true);
      expect((controller.state.x, controller.state.y), (2, 0));
      expect(durations.length, 2);
      // A third command hits the wall rather than adding an extra step.
      expect(await controller.moveForward(), true);
      expect((controller.state.x, controller.state.y), (2, 0));
      expect(durations.length, 2);
      expect(service.requests, isEmpty);
    },
  );
  test(
    'reset cancels old corridor movement while awaiting animation',
    () async {
      controller.dispose();
      final release = Completer<void>();
      controller = ControllerGameSteamScratchMaze(
        userName: 'user',
        service: service,
        gameId: 'game',
        level: level(),
        delay: (_) => release.future,
      );
      final pending = controller.moveForward();
      controller.resetGame();
      release.complete();
      expect(await pending, false);
      expect((controller.state.x, controller.state.y), (0, 0));
    },
  );
  test('overlapping directional commands do not move twice', () async {
    controller.dispose();
    final release = Completer<void>();
    controller = ControllerGameSteamScratchMaze(
      userName: 'user',
      service: service,
      gameId: 'game',
      level: level(),
      delay: (_) => release.future,
    );
    final pending = controller.moveForward();
    expect(await controller.jumpUp(), false);
    release.complete();
    await pending;
    expect((controller.state.x, controller.state.y), (1, 0));
  });
  test('treasure event waits for save and remaining commands stop', () async {
    treasureLevel();
    final events = <EnumGameEventType>[];
    final subscription = controller.eventStream.listen(
      (event) => events.add(event.type),
    );
    final counter = CountingCommand();
    final pending = controller.executeCommands([ForwardCommand(), counter]);
    await flush();
    expect(events, isEmpty);
    service.requests.single.complete();
    await pending;
    await flush();
    expect(events, [EnumGameEventType.treasure]);
    expect(counter.calls, 0);
    expect(service.scores, [10.0]);
    await subscription.cancel();
  });
  test('save failure rolls back without a false success event', () async {
    treasureLevel();
    final events = <EnumGameEventType>[];
    final subscription = controller.eventStream.listen(
      (event) => events.add(event.type),
    );
    final pending = controller.moveForward();
    final failure = expectLater(pending, throwsStateError);
    await flush();
    service.requests.single.completeError(StateError('offline'));
    await failure;
    expect(controller.state.treasureCollected, false);
    expect(controller.stateNotifier.value.score, 0);
    expect(events, isEmpty);
    await subscription.cancel();
  });
  test('old save cannot clear new score after reset', () async {
    treasureLevel();
    final pending = controller.moveForward();
    await flush();
    controller.resetGame();
    controller.state.score = 42;
    service.requests.single.complete();
    expect(await pending, false);
    expect(controller.state.score, 42);
  });
  test('old save failure cannot roll back a new round', () async {
    treasureLevel();
    final pending = controller.moveForward();
    await flush();
    controller.resetGame();
    controller.state.score = 42;
    service.requests.single.completeError(StateError('old request'));
    expect(await pending, false);
    expect(controller.state.score, 42);
  });
  test('new startup cancels old pending startup', () async {
    controller.dispose();
    final delays = <Completer<void>>[];
    controller = ControllerGameSteamScratchMaze(
      userName: 'user',
      service: service,
      gameId: 'game',
      level: level(),
      delay: (_) {
        final pending = Completer<void>();
        delays.add(pending);
        return pending.future;
      },
    );
    final first = CountingCommand(), second = CountingCommand();
    final old = controller.restartAndExecute([first]);
    final current = controller.restartAndExecute([second]);
    delays[0].complete();
    await old;
    delays[1].complete();
    await current;
    expect(first.calls, 0);
    expect(second.calls, 1);
  });
  test('reset stops nested loop and if branch commands', () async {
    for (final loop in [true, false]) {
      final blocking = BlockingCommand(), counter = CountingCommand();
      final Command command = loop
          ? LoopCommand(count: 2, commands: [blocking, counter])
          : IfElseCommand(
              condition: (_) => true,
              thenCommands: [blocking, counter],
              elseCommands: [],
            );
      final pending = controller.executeCommands([command]);
      controller.resetGame();
      blocking.release.complete();
      await pending;
      expect(counter.calls, 0);
    }
  });
  test(
    'command list is a snapshot and old run cannot unlock new run',
    () async {
      final old = BlockingCommand(),
          current = BlockingCommand(),
          counter = CountingCommand();
      final oldRun = controller.executeCommands([old]);
      controller.resetGame();
      final list = <Command>[current, counter];
      final newRun = controller.executeCommands(list);
      list.clear();
      old.release.complete();
      await oldRun;
      await controller.executeCommands([counter]);
      expect(counter.calls, 0);
      current.release.complete();
      await newRun;
      expect(counter.calls, 1);
    },
  );
  test('disposal cancels pending animation and future commands', () async {
    controller.dispose();
    final release = Completer<void>();
    controller = ControllerGameSteamScratchMaze(
      userName: 'user',
      service: service,
      gameId: 'game',
      level: level(),
      delay: (_) => release.future,
    );
    final pending = controller.moveForward();
    controller.dispose();
    release.complete();
    expect(await pending, false);
    expect(await controller.jumpUp(), false);
  });
  test('reset from completion listener suppresses old success event', () async {
    treasureLevel();
    final events = <EnumGameEventType>[];
    final subscription = controller.eventStream.listen(
      (event) => events.add(event.type),
    );
    controller.stateNotifier.addListener(() {
      if (controller.state.treasureCollected && controller.state.score == 0) {
        controller.resetGame();
      }
    });
    final pending = controller.moveForward();
    await flush();
    service.requests.single.complete();
    expect(await pending, false);
    await flush();
    expect(events, [EnumGameEventType.none]);
    await subscription.cancel();
  });
}
