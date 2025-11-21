import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/models/game/model_game_steam_super_hero_level.dart';
import 'package:life_pilot/services/game/service_game.dart';

enum Direction { north, east, south, west }

class GameState {
  int x = 0;
  int y = 0;
  int score = 0;
  bool treasureCollected = false;
  Direction facing = Direction.east;

  GameState copy() => GameState()
    ..x = x
    ..y = y
    ..score = score
    ..treasureCollected = treasureCollected
    ..facing = facing;
}

// -------------------- Command 定義 --------------------
abstract class Command {
  Future<bool> execute(ControllerGameSteamSuperHero game);
}

// 基本動作
class ForwardCommand extends Command {
  @override
  Future<bool> execute(ControllerGameSteamSuperHero game) async {
    return await game.moveForward();
  }
}

class BackwardCommand extends Command {
  @override
  Future<bool> execute(ControllerGameSteamSuperHero game) async {
    return await game.moveBackward();
  }
}

class TurnLeftCommand extends Command {
  @override
  Future<bool> execute(ControllerGameSteamSuperHero game) async {
    game.state.facing =
        Direction.values[(game.state.facing.index + 3) % 4]; // 左轉 90 度
    return await game.moveForward();
  }
}

class TurnRightCommand extends Command {
  @override
  Future<bool> execute(ControllerGameSteamSuperHero game) async {
    game.state.facing =
        Direction.values[(game.state.facing.index + 1) % 4]; // 右轉 90 度
    return await game.moveForward();
  }
}

// 跳躍動畫
class JumpUpCommand extends Command {
  @override
  Future<bool> execute(ControllerGameSteamSuperHero game) async {
    return await game.jumpUp();
  }
}

class JumpDownCommand extends Command {
  @override
  Future<bool> execute(ControllerGameSteamSuperHero game) async {
    return await game.jumpDown();
  }
}

// 迴圈
class LoopCommand extends Command {
  int count;
  List<Command> commands;
  LoopCommand({required this.count, required this.commands});

  @override
  Future<bool> execute(ControllerGameSteamSuperHero game) async {
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
  bool Function(ControllerGameSteamSuperHero) condition;
  List<Command> thenCommands;
  List<Command> elseCommands;

  IfElseCommand({
    required this.condition,
    required this.thenCommands,
    required this.elseCommands,
  });

  @override
  Future<bool> execute(ControllerGameSteamSuperHero game) async {
    var list = condition(game) ? thenCommands : elseCommands;
    for (var cmd in list) {
      bool cont = await cmd.execute(game);
      if (!cont) return false;
    }
    return true;
  }
}

// -------------------- Game Controller --------------------
class ControllerGameSteamSuperHero {
  final String userName;
  final ServiceGame service;
  final String gameId;
  final GameSteamSuperHeroLevel level;
  bool _scoreSaved = false;

  // 使用 ValueNotifier 提高效能，安全 UI 更新
  final ValueNotifier<GameState> stateNotifier = ValueNotifier(GameState());
  GameState get state => stateNotifier.value;

  // 事件 callback
  final StreamController<GameEvent> _eventController =
      StreamController.broadcast();
  Stream<GameEvent> get eventStream => _eventController.stream;

  ControllerGameSteamSuperHero({
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
    _eventController.add(GameEvent(GameEventType.none, constEmpty));
  }

  void _notifyEvent(GameEvent event) => _eventController.add(event);

  // ---------------- Movement ----------------
  Future<bool> moveForward() async {
    switch (state.facing) {
      case Direction.north:
        state.y += 1;
        break;
      case Direction.east:
        state.x += 1;
        break;
      case Direction.south:
        state.y -= 1;
        break;
      case Direction.west:
        state.x -= 1;
        break;
    }
    return _afterMovement();
  }

  Future<bool> moveBackward() async {
    switch (state.facing) {
      case Direction.north:
        state.y -= 1;
        break;
      case Direction.east:
        state.x -= 1;
        break;
      case Direction.south:
        state.y += 1;
        break;
      case Direction.west:
        state.x += 1;
        break;
    }
    return _afterMovement();
  }

  Future<bool> jumpUp() async {
    state.y += 1;
    return _afterMovement();
  }

  Future<bool> jumpDown() async {
    state.y -= 1;
    return _afterMovement();
  }

  Future<bool> _afterMovement() async {
    // 延遲 400ms 再回傳
    await Future.delayed(Duration(milliseconds: 400));

    if (_scoreSaved) return false; // 已經過關 → 不要再檢查

    // 限制角色不能超出場景
    final maxX = level.obstacles
            .map((o) => o.x)
            .followedBy(level.fruits.map((f) => f.x))
            .followedBy([level.treasure.x]).reduce(max) +
        2;
    final maxY = level.obstacles
            .map((o) => o.y)
            .followedBy(level.fruits.map((f) => f.y))
            .followedBy([level.treasure.y]).reduce(max) +
        2;

    // 先更新位置
    state.x = state.x.clamp(-1, maxX);
    state.y = state.y.clamp(-1, maxY); // ✅ 防止已卸載 widget 呼叫 setState
    stateNotifier.value = state.copy();

    // 掉下懸崖檢查
    if (state.x < 0 || state.x >= maxX || state.y < 0 || state.y >= maxY) {
      _notifyEvent(GameEvent(GameEventType.obstacle, "Fall off a cliff！"));
      return false; // 停止遊戲
    }

    if (_checkObstacle()) return false;
    _checkFruit();
    return _checkTreasure();
  }

  // ---- 檢查障礙 ----
  bool _checkObstacle() {
    for (var obs in level.obstacles) {
      if (obs.x == state.x && obs.y == state.y) {
        state.score += obs.scoreValue;
        _notifyEvent(GameEvent(GameEventType.obstacle, "Hit an obstacle！"));
        return true;
      }
    }
    return false;
  }

  // ---- 檢查水果 ----
  void _checkFruit() {
    for (var fruit in level.fruits) {
      if (!fruit.collected && fruit.x == state.x && fruit.y == state.y) {
        fruit.collected = true;
        state.score += fruit.scoreValue;
        _notifyEvent(
            GameEvent(GameEventType.fruit, "Food +${fruit.scoreValue}!"));
      }
    }
  }

  // ---- 檢查寶藏 ----
  bool _checkTreasure() {
    if (!state.treasureCollected &&
        state.x == level.treasure.x &&
        state.y == level.treasure.y) {
      if (state.score < (level.levelNumber * 0.5).toInt()) { //至少要吃一點東西
        _notifyEvent(GameEvent(
          GameEventType.warning, "Eat at least ${level.levelNumber} foods !!"));
        return true;
      } 
      state.treasureCollected = true;
      state.score += level.treasure.scoreValue;
      _notifyEvent(GameEvent(
          GameEventType.treasure, "Treasure found！Score: ${state.score}"));
      _saveScore(true);
      return false;
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
    if (_scoreSaved || state.score < level.treasure.scoreValue) return; // ⛔ 已存過就不再存
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
