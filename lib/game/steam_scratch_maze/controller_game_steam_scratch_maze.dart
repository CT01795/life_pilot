import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:life_pilot/game/steam_scratch_maze/model_game_steam_scratch_maze_level.dart';
import 'package:life_pilot/game/steam_scratch_maze/model_scratch_maze_session.dart';
import 'package:life_pilot/game/service_game.dart';
import 'package:life_pilot/utils/value_parser.dart';
export 'package:life_pilot/game/steam_scratch_maze/model_scratch_maze_session.dart'
    show GameState;

// -------------------- Command 定義 --------------------
abstract class Command {
  Future<bool> execute(ControllerGameSteamScratchMaze game);
}

// 基本動作
class ForwardCommand extends Command {
  @override
  Future<bool> execute(ControllerGameSteamScratchMaze game) async {
    return await game.moveForward();
  }
}

class BackwardCommand extends Command {
  @override
  Future<bool> execute(ControllerGameSteamScratchMaze game) async {
    return await game.moveBackward();
  }
}

// 跳躍動畫
class JumpUpCommand extends Command {
  @override
  Future<bool> execute(ControllerGameSteamScratchMaze game) async {
    return await game.jumpUp();
  }
}

class JumpDownCommand extends Command {
  @override
  Future<bool> execute(ControllerGameSteamScratchMaze game) async {
    return await game.jumpDown();
  }
}

// 迴圈
class LoopCommand extends Command {
  int count;
  List<Command> commands;
  LoopCommand({required this.count, required this.commands});

  @override
  Future<bool> execute(ControllerGameSteamScratchMaze game) async {
    final generation = game.generation;
    final repetitions = count;
    final snapshot = List<Command>.of(commands);
    for (int i = 0; i < repetitions; i++) {
      for (var cmd in snapshot) {
        if (!game.canExecute || !game.isCurrentGeneration(generation)) {
          return false;
        }
        bool cont = await cmd.execute(game);
        if (!cont) return false;
      }
    }
    return true;
  }
}

// if/else
class IfElseCommand extends Command {
  bool Function(ControllerGameSteamScratchMaze) condition;
  List<Command> thenCommands;
  List<Command> elseCommands;

  IfElseCommand({
    required this.condition,
    required this.thenCommands,
    required this.elseCommands,
  });

  @override
  Future<bool> execute(ControllerGameSteamScratchMaze game) async {
    final generation = game.generation;
    if (!game.canExecute) return false;
    final list = List<Command>.of(
      condition(game) ? thenCommands : elseCommands,
    );
    for (var cmd in list) {
      if (!game.canExecute || !game.isCurrentGeneration(generation)) {
        return false;
      }
      bool cont = await cmd.execute(game);
      if (!cont) return false;
    }
    return true;
  }
}

class ControllerGameSteamScratchMaze {
  final String userName;
  final ServiceGame service;
  final String gameId;
  final ModelGameSteamScratchMazeLevel level;
  late final ModelScratchMazeSession _session;
  final Future<void> Function(Duration) _delay;
  bool _scoreSaved = false;
  bool _disposed = false;
  bool _isExecuting = false;
  bool _movementActive = false;
  int _generation = 0;
  int get generation => _generation;
  bool get canExecute => !_disposed && !_scoreSaved;
  bool isCurrentGeneration(int generation) =>
      !_disposed && generation == _generation;
  late final ValueNotifier<GameState> stateNotifier;
  GameState get state => _session.state;
  final StreamController<ModelGameEvent> _eventController =
      StreamController.broadcast();
  Stream<ModelGameEvent> get eventStream => _eventController.stream;

  ControllerGameSteamScratchMaze({
    required this.userName,
    required this.service,
    required this.gameId,
    required this.level,
    Future<void> Function(Duration)? delay,
  }) : _delay = delay ?? ((duration) => Future<void>.delayed(duration)) {
    _session = ModelScratchMazeSession(level);
    stateNotifier = ValueNotifier(state.copy());
  }

  void resetGame() {
    if (_disposed) return;
    _generation++;
    _isExecuting = false;
    _movementActive = false;
    _scoreSaved = false;
    _session.reset();
    stateNotifier.value = state.copy();
    _notifyEvent(ModelGameEvent(EnumGameEventType.none, ''));
  }

  void _notifyEvent(ModelGameEvent event) {
    if (!_disposed && !_eventController.isClosed) _eventController.add(event);
  }

  Future<bool> moveForward() => _move(1, 0);
  Future<bool> moveBackward() => _move(-1, 0);
  Future<bool> jumpUp() => _move(0, 1);
  Future<bool> jumpDown() => _move(0, -1);

  Future<bool> _move(int dx, int dy) async {
    if (!canExecute || _movementActive) return false;
    final generation = _generation;
    _movementActive = true;
    try {
      final result = _session.step(dx, dy);
      if (result == null) return true;
      stateNotifier.value = state.copy();
      if (!isCurrentGeneration(generation)) return false;
      for (final event in result.events) {
        if (event.type != EnumGameEventType.treasure) _notifyEvent(event);
      }
      if (result.needsSave) {
        final scoreToSave = state.score;
        _scoreSaved = true;
        try {
          await service.saveUserGameScore(
            newUserName: userName,
            newScore: parseDoubleValue(scoreToSave),
            newGameId: gameId,
            newIsPass: true,
          );
        } catch (_) {
          if (!isCurrentGeneration(generation)) return false;
          _scoreSaved = false;
          _session.rollbackTreasure();
          stateNotifier.value = state.copy();
          rethrow;
        }
        if (!isCurrentGeneration(generation)) return false;
        state.score = 0;
        stateNotifier.value = state.copy();
        if (!isCurrentGeneration(generation)) return false;
        for (final event in result.events) {
          if (event.type == EnumGameEventType.treasure) _notifyEvent(event);
        }
        return true;
      }
      await _delay(const Duration(milliseconds: 400));
      return isCurrentGeneration(generation);
    } finally {
      if (isCurrentGeneration(generation)) _movementActive = false;
    }
  }

  Future<void> restartAndExecute(List<Command> commands) async {
    if (_disposed) return;
    final snapshot = List<Command>.of(commands);
    resetGame();
    final generation = _generation;
    await _delay(const Duration(milliseconds: 300));
    if (!isCurrentGeneration(generation)) return;
    await executeCommands(snapshot);
  }

  Future<void> executeCommands(List<Command> commands) async {
    if (!canExecute || _isExecuting) return;
    final generation = _generation;
    _isExecuting = true;
    try {
      for (final command in List<Command>.of(commands)) {
        if (!isCurrentGeneration(generation) || !canExecute) return;
        if (!await command.execute(this)) return;
      }
    } finally {
      if (isCurrentGeneration(generation)) _isExecuting = false;
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    stateNotifier.dispose();
    unawaited(_eventController.close());
  }
}
