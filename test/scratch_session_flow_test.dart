import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/game/service_game.dart';
import 'package:life_pilot/game/steam_scratch/controller_game_steam_scratch.dart';
import 'package:life_pilot/game/steam_scratch/model_game_steam_scratch_level.dart';
import 'package:life_pilot/game/steam_scratch/model_scratch_session.dart';

ModelGameSteamScratchLevel level({
  int x = 3,
  int y = 2,
  int number = 1,
  List<ModelGameSteamScratchFruit> fruits = const [],
  List<ModelGameSteamScratchObstacle> obstacles = const [],
}) => ModelGameSteamScratchLevel(
  levelNumber: number,
  obstacles: obstacles,
  fruits: fruits,
  treasure: ModelGameSteamScratchTreasure(x: x, y: y),
);

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
  Future<bool> execute(ControllerGameSteamScratch game) async {
    calls++;
    return true;
  }
}

class BlockingCommand extends Command {
  final release = Completer<void>();
  int calls = 0;
  @override
  Future<bool> execute(ControllerGameSteamScratch game) async {
    calls++;
    await release.future;
    return true;
  }
}

void main() {
  group('scratch domain model', () {
    test('forward and backward retain all four original directions', () {
      for (final direction in Direction.values) {
        final model = ModelScratchSession(level());
        model.state.facing = direction;
        model.move();
        final expected = switch (direction) {
          Direction.north => (0, 1),
          Direction.east => (1, 0),
          Direction.south => (0, -1),
          Direction.west => (-1, 0),
        };
        expect((model.state.x, model.state.y), expected);
        model.move(backward: true);
        expect((model.state.x, model.state.y), (0, 0));
      }
    });
    test('turns still move and vertical jumps preserve facing', () {
      final model = ModelScratchSession(level());
      model.move(turn: -1);
      expect(
        (model.state.x, model.state.y, model.state.facing),
        (0, 1, Direction.north),
      );
      model.move(turn: 1);
      expect(
        (model.state.x, model.state.y, model.state.facing),
        (1, 1, Direction.east),
      );
      model.move(vertical: 1);
      model.move(vertical: -1);
      expect(
        (model.state.x, model.state.y, model.state.facing),
        (1, 1, Direction.east),
      );
    });
    test('cliff coordinates are clamped and stop movement', () {
      final model = ModelScratchSession(level());
      model.state.x = 100;
      final result = model.resolveMovement();
      expect(model.state.x, 4);
      expect(result.shouldContinue, false);
      expect(result.events.single.type, EnumGameEventType.obstacle);
    });
    test('obstacle wins over fruit on same cell', () {
      final fruit = ModelGameSteamScratchFruit(x: 1, y: 0);
      final model = ModelScratchSession(
        level(
          fruits: [fruit],
          obstacles: [
            ModelGameSteamScratchObstacle(x: 1, y: 0, scoreValue: -2),
          ],
        ),
      );
      model.move();
      expect(model.resolveMovement().shouldContinue, false);
      expect(model.state.score, -2);
      expect(fruit.collected, false);
    });
    test(
      'multiple fruits on same cell score once each and reset restores them',
      () {
        final fruits = [
          ModelGameSteamScratchFruit(x: 1, y: 0),
          ModelGameSteamScratchFruit(x: 1, y: 0, scoreValue: 2),
        ];
        final model = ModelScratchSession(level(fruits: fruits));
        model.move();
        expect(model.resolveMovement().events.length, 2);
        expect(model.state.score, 3);
        expect(model.resolveMovement().events, isEmpty);
        model.reset();
        expect(model.state.score, 0);
        expect(fruits.every((f) => !f.collected), true);
      },
    );
    test(
      'treasure threshold reward and rollback preserve original scoring',
      () {
        final model = ModelScratchSession(
          level(
            number: 6,
            fruits: [
              ModelGameSteamScratchFruit(x: 1, y: 0),
              ModelGameSteamScratchFruit(x: 1, y: 1),
              ModelGameSteamScratchFruit(x: 2, y: 1),
            ],
          ),
        );
        model.state
          ..x = 3
          ..y = 2;
        expect(
          model.resolveMovement().events.single.type,
          EnumGameEventType.warning,
        );
        model.state.score = 3;
        final result = model.resolveMovement();
        expect(result.needsSave, true);
        expect(model.state.score, 13);
        model.rollbackTreasure();
        expect(model.state.score, 3);
        expect(model.state.treasureCollected, false);
      },
    );
    test('fruit appearance is model data and supports explicit choice', () {
      final fruit = ModelGameSteamScratchFruit(
        x: 0,
        y: 0,
        appearance: EnumScratchFruitAppearance.cake,
      );
      expect(fruit.appearance, EnumScratchFruitAppearance.cake);
      expect(
        EnumScratchFruitAppearance.values,
        contains(ModelGameSteamScratchFruit(x: 0, y: 0).appearance),
      );
    });
  });

  late Service service;
  late ControllerGameSteamScratch controller;
  setUp(() {
    service = Service();
    controller = ControllerGameSteamScratch(
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
    controller = ControllerGameSteamScratch(
      userName: 'user',
      service: service,
      gameId: 'game',
      level: level(x: 1, y: 0),
      delay: (_) async {},
    );
  }

  test('new startup supersedes an old run waiting to start', () async {
    controller.dispose();
    final delays = <Completer<void>>[];
    controller = ControllerGameSteamScratch(
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
    final oldRun = controller.restartAndExecute([first]);
    final newRun = controller.restartAndExecute([second]);
    delays[0].complete();
    await oldRun;
    expect(first.calls, 0);
    delays[1].complete();
    await newRun;
    expect(second.calls, 1);
  });

  test('reset invalidates an animation already in flight', () async {
    controller.dispose();
    final release = Completer<void>();
    controller = ControllerGameSteamScratch(
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
    expect(service.requests, isEmpty);
  });
  test('overlapping movements are ignored instead of skipping cells', () async {
    controller.dispose();
    final release = Completer<void>();
    controller = ControllerGameSteamScratch(
      userName: 'user',
      service: service,
      gameId: 'game',
      level: level(),
      delay: (_) => release.future,
    );
    final pending = controller.moveForward();
    expect(await controller.moveForward(), false);
    release.complete();
    expect(await pending, true);
    expect(controller.state.x, 1);
  });
  test('fruit score is present in the published state', () async {
    controller.dispose();
    controller = ControllerGameSteamScratch(
      userName: 'user',
      service: service,
      gameId: 'game',
      level: level(fruits: [ModelGameSteamScratchFruit(x: 1, y: 0)]),
      delay: (_) async {},
    );
    final scores = <int>[];
    controller.stateNotifier.addListener(
      () => scores.add(controller.stateNotifier.value.score),
    );
    await controller.moveForward();
    expect(scores, [1]);
  });
  test(
    'treasure event waits for successful persistence and does not save twice',
    () async {
      treasureLevel();
      final events = <EnumGameEventType>[];
      final subscription = controller.eventStream.listen(
        (e) => events.add(e.type),
      );
      final pending = controller.moveForward();
      await flush();
      expect(events, isEmpty);
      service.requests.single.complete();
      expect(await pending, false);
      await flush();
      expect(events, [EnumGameEventType.treasure]);
      expect(await controller.moveForward(), false);
      expect(service.scores, [10.0]);
      await subscription.cancel();
    },
  );
  test('save failure rolls back treasure without publishing success', () async {
    treasureLevel();
    final events = <EnumGameEventType>[];
    final subscription = controller.eventStream.listen(
      (e) => events.add(e.type),
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
  test(
    'old save success cannot clear new round score or emit treasure',
    () async {
      treasureLevel();
      final events = <EnumGameEventType>[];
      final subscription = controller.eventStream.listen(
        (e) => events.add(e.type),
      );
      final pending = controller.moveForward();
      await flush();
      controller.resetGame();
      controller.state.score = 42;
      service.requests.single.complete();
      expect(await pending, false);
      await flush();
      expect(controller.state.score, 42);
      expect(events, [EnumGameEventType.none]);
      await subscription.cancel();
    },
  );
  test('old save failure cannot roll back new round state', () async {
    treasureLevel();
    final pending = controller.moveForward();
    await flush();
    controller.resetGame();
    controller.state.score = 42;
    service.requests.single.completeError(StateError('old request'));
    expect(await pending, false);
    expect(controller.state.score, 42);
  });
  test('reset stops remaining commands inside a nested loop', () async {
    final blocking = BlockingCommand(), counter = CountingCommand();
    final pending = controller.executeCommands([
      LoopCommand(count: 2, commands: [blocking, counter]),
    ]);
    controller.resetGame();
    blocking.release.complete();
    await pending;
    expect(counter.calls, 0);
    expect(blocking.calls, 1);
  });
  test('reset stops remaining commands inside if branch', () async {
    final blocking = BlockingCommand(), counter = CountingCommand();
    final pending = controller.executeCommands([
      IfElseCommand(
        condition: (_) => true,
        thenCommands: [blocking, counter],
        elseCommands: [],
      ),
    ]);
    controller.resetGame();
    blocking.release.complete();
    await pending;
    expect(counter.calls, 0);
  });
  test('old run completion cannot unlock an active new run', () async {
    final old = BlockingCommand(),
        current = BlockingCommand(),
        third = CountingCommand();
    final oldRun = controller.executeCommands([old]);
    controller.resetGame();
    final newRun = controller.executeCommands([current]);
    old.release.complete();
    await oldRun;
    await controller.executeCommands([third]);
    expect(third.calls, 0);
    current.release.complete();
    await newRun;
  });
  test('running command list is a stable snapshot', () async {
    final blocking = BlockingCommand(), counter = CountingCommand();
    final commands = <Command>[blocking, counter];
    final pending = controller.executeCommands(commands);
    commands.clear();
    blocking.release.complete();
    await pending;
    expect(counter.calls, 1);
  });
  test('loop snapshots its count and body during execution', () async {
    final blocking = BlockingCommand(), counter = CountingCommand();
    final body = <Command>[blocking, counter];
    final loop = LoopCommand(count: 2, commands: body);
    final pending = loop.execute(controller);
    loop.count = 100;
    body.clear();
    blocking.release.complete();
    await pending;
    expect(counter.calls, 2);
  });
  test(
    'disposed controller cannot turn or evaluate conditional commands',
    () async {
      controller.dispose();
      expect(await TurnLeftCommand().execute(controller), false);
      expect(controller.state.facing, Direction.east);
      var evaluated = false;
      final result = await IfElseCommand(
        condition: (_) {
          evaluated = true;
          return true;
        },
        thenCommands: [],
        elseCommands: [],
      ).execute(controller);
      expect(result, false);
      expect(evaluated, false);
    },
  );
  test(
    'reset from state listener invalidates pending movement resolution',
    () async {
      treasureLevel();
      controller.stateNotifier.addListener(() {
        if (controller.state.treasureCollected) controller.resetGame();
      });
      expect(await controller.moveForward(), false);
      expect(service.requests, isEmpty);
      expect(controller.state.score, 0);
    },
  );
}
