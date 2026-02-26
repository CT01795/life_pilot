import 'dart:async';

import 'package:flutter/material.dart';
import 'package:life_pilot/game/steam_scratch_maze/model_game_steam_scratch_maze_level.dart';
import 'package:life_pilot/game/service_game.dart';

class GameState {
  int x = 0;
  int y = 0;
  int score = 0;
  bool treasureCollected = false;

  GameState copy() => GameState()
    ..x = x
    ..y = y
    ..score = score
    ..treasureCollected = treasureCollected;
}

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
    for (int i = 0; i < count; i++) {
      for (var cmd in commands) {
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
    var list = condition(game) ? thenCommands : elseCommands;
    for (var cmd in list) {
      bool cont = await cmd.execute(game);
      if (!cont) return false;
    }
    return true;
  }
}

// -------------------- Game Controller --------------------
class ControllerGameSteamScratchMaze {
  final String userName;
  final ServiceGame service;
  final String gameId;
  final ModelGameSteamScratchMazeLevel level;
  bool _scoreSaved = false;

  // 使用 ValueNotifier 提高效能，安全 UI 更新
  final ValueNotifier<GameState> stateNotifier = ValueNotifier(GameState());
  GameState get state => stateNotifier.value;

  // 事件 callback
  final StreamController<ModelGameEvent> _eventController =
      StreamController.broadcast();
  Stream<ModelGameEvent> get eventStream => _eventController.stream;

  ControllerGameSteamScratchMaze({
    required this.userName,
    required this.service,
    required this.gameId, // 初始化
    required this.level,
  });

  void resetGame() {
    stateNotifier.value = GameState();
    _scoreSaved = false; // ⭐ 重新遊戲前清空
    for (var fruit in level.fruits) {
      fruit.collected = false;
    }
    // ⭐ 清空事件 Stream 避免殘留事件再跳 Dialog
    _eventController.add(ModelGameEvent(EnumGameEventType.none, ''));
  }

  void _notifyEvent(ModelGameEvent event) => _eventController.add(event);

  // ---------------- Movement ----------------
  Future<bool> moveForward() async {
    int newX = state.x;
    int newY = state.y;
    while (await _isWalkable(newX + 1, newY)) {
      newX += 1;
      // ✅ 更新 ValueNotifier
      stateNotifier.value = state.copy()
        ..x = newX
        ..y = newY;
      await Future.delayed(Duration(milliseconds: 400));
      if (await _isWalkable(newX, newY - 1) ||
          await _isWalkable(newX, newY + 1)) { //岔路處跳出
        break;
      }
    }
    return true; // _afterMovement();
  }

  Future<bool> moveBackward() async {
    int newX = state.x;
    int newY = state.y;
    while (await _isWalkable(newX - 1, newY)) {
      newX -= 1;
      // ✅ 更新 ValueNotifier
      stateNotifier.value = state.copy()
        ..x = newX
        ..y = newY;  
      await Future.delayed(Duration(milliseconds: 400));
      if (await _isWalkable(newX, newY - 1) ||
          await _isWalkable(newX, newY + 1)) { //岔路處跳出
        break;
      }
    }
    return true; // _afterMovement();
  }

  Future<bool> jumpUp() async {
    int newX = state.x;
    int newY = state.y;
    while (await _isWalkable(newX, newY + 1)) {
      newY += 1;
      // ✅ 更新 ValueNotifier
      stateNotifier.value = state.copy()
        ..x = newX
        ..y = newY;
      await Future.delayed(Duration(milliseconds: 400));
      if (await _isWalkable(newX - 1, newY) ||
          await _isWalkable(newX + 1, newY)) { //岔路處跳出
        break;
      }
    }
    return true; // _afterMovement();
  }

  Future<bool> jumpDown() async {
    int newX = state.x;
    int newY = state.y;
    while (await _isWalkable(newX, newY - 1)) {
      newY -= 1;
      // ✅ 更新 ValueNotifier
      stateNotifier.value = state.copy()
        ..x = newX
        ..y = newY;
      await Future.delayed(Duration(milliseconds: 400));
      if (await _isWalkable(newX - 1, newY) ||
          await _isWalkable(newX + 1, newY)) { //岔路處跳出
        break;
      }
    }
    return true; // _afterMovement();
  }

  Future<bool> _isWalkable(int x, int y) async {
    // 延遲 400ms 再回傳
    if (_scoreSaved) return false; // 已經過關 → 不要再檢查
    if (x < 0 || y < 0 || x > level.treasure.x || y > level.treasure.y) {
      return false;
    }
    for (var obs in level.obstacles) {
      if (obs.x == x && obs.y == y) return false; // 牆
    }
    _checkFruit();
    return await _checkTreasure();
  }

  // ---- 檢查水果 ----
  void _checkFruit() {
    for (var fruit in level.fruits) {
      if (!fruit.collected && fruit.x == state.x && fruit.y == state.y) {
        fruit.collected = true;
        state.score += fruit.scoreValue;
        _notifyEvent(ModelGameEvent(
            EnumGameEventType.fruit, "Food +${fruit.scoreValue}!"));
      }
    }
  }

  // ---- 檢查寶藏 ----
  Future<bool> _checkTreasure() async {
    if (!state.treasureCollected &&
        state.x == level.treasure.x &&
        state.y == level.treasure.y) {
      state.treasureCollected = true;
      state.score += level.treasure.scoreValue;
      _notifyEvent(ModelGameEvent(
          EnumGameEventType.treasure, "Treasure found！Score: ${state.score}"));
      await _saveScore(true);
    }
    return true;
  }

  // ---- 執行 commands ----
  Future<void> executeCommands(List<Command> commands) async {
    for (var cmd in commands) {
      bool ok = await cmd.execute(this);
      if (!ok) return; // 撞障礙直接停止
    }
  }

  Future<void> _saveScore(bool isPass) async {
    if (_scoreSaved || state.score < level.treasure.scoreValue) {
      return; // ⛔ 已存過就不再存
    }
    _scoreSaved = true;
    await service.saveUserGameScore(
      newUserName: userName,
      newScore: state.score.toDouble(),
      newGameId: gameId, // 使用傳入的 gameId
      newIsPass: isPass,
    );
    state.score = 0;
  }

  void dispose() {
    _eventController.close();
  }
}
