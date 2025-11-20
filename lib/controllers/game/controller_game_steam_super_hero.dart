import 'package:life_pilot/models/game/model_game_steam_super_hero_level.dart';
import 'package:life_pilot/services/game/service_game.dart';

enum Direction { north, east, south, west }

// 遊戲事件類型
enum GameEventType { fruit, obstacle, treasure, complete }

class GameEvent {
  final GameEventType type;
  final String message;
  GameEvent(this.type, this.message);
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
    game.facing = Direction.values[(game.facing.index + 3) % 4]; // 左轉 90 度
    game.notifyUpdate();
    await Future.delayed(Duration(milliseconds: 1000));
    return true;
  }
}

class TurnRightCommand extends Command {
  @override
  Future<bool> execute(ControllerGameSteamSuperHero game) async {
    game.facing = Direction.values[(game.facing.index + 1) % 4]; // 右轉 90 度
    game.notifyUpdate();
    await Future.delayed(Duration(milliseconds: 1000));
    return true;
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

  ControllerGameSteamSuperHero({
    required this.userName,
    required this.service,
    required this.gameId, // 初始化
    required this.level,
  });

  int x = 0;
  int y = 0;
  int score = 0;
  bool treasureCollected = false;

  Direction facing = Direction.east; // 角色朝向東邊
  final GameSteamSuperHeroLevel level;

  Function? _onUpdate;
  Function(GameEvent)? _onEvent;

  void setUpdateCallback(Function onUpdate) => _onUpdate = onUpdate;

  void notifyUpdate() {
    if (_onUpdate != null) _onUpdate!();
  }

  // 遊戲事件 callback
  void setEventCallback(Function(GameEvent) callback) {
    _onEvent = callback;
  }

  void notifyEvent(GameEvent event) {
    if (_onEvent != null) _onEvent!(event);
  }

  void resetGame() {
    x = 0;
    y = 0;
    facing = Direction.east;
    score = 0;
    treasureCollected = false;

    for (var fruit in level.fruits) {
      fruit.collected = false;
    }

    notifyUpdate();
  }

  // ----------------
  // 移動邏輯
  // ----------------
  Future<bool> moveForward() async {
    switch (facing) {
      case Direction.north:
        y += 1;
        break;
      case Direction.east:
        x += 1;
        break;
      case Direction.south:
        y -= 1;
        break;
      case Direction.west:
        x -= 1;
        break;
    }
    return _afterMovement();
  }

  Future<bool> moveBackward() async {
    switch (facing) {
      case Direction.north:
        y -= 1;
        break;
      case Direction.east:
        x -= 1;
        break;
      case Direction.south:
        y += 1;
        break;
      case Direction.west:
        x += 1;
        break;
    }
    return _afterMovement();
  }

  Future<bool> jumpUp() async {
    y += 1;
    return _afterMovement();
  }

  Future<bool> jumpDown() async {
    y -= 1;
    return _afterMovement();
  }

  Future<bool> _afterMovement() async {
    notifyUpdate();
    await Future.delayed(Duration(milliseconds: 1000));

    if (checkObstacle()) return false;
    checkFruit();
    checkTreasure();
    return true;
  }

  // ---- 檢查水果 ----
  void checkFruit() {
    for (var fruit in level.fruits) {
      if (!fruit.collected && fruit.x == x && fruit.y == y) {
        fruit.collected = true;
        score += fruit.scoreValue;
        notifyEvent(
            GameEvent(GameEventType.fruit, "Eat food！ +${fruit.scoreValue}!"));
      }
    }
  }

  // ---- 檢查障礙 ----
  bool checkObstacle() {
    for (var obs in level.obstacles) {
      if (obs.x == x && obs.y == y) {
        notifyEvent(GameEvent(GameEventType.obstacle, "Hit an obstacle！"));
        return true;
      }
    }
    return false;
  }

  // ---- 檢查寶藏 ----
  void checkTreasure() {
    if (!treasureCollected && x == level.treasure.x && y == level.treasure.y) {
      treasureCollected = true;
      saveScore(true);
      notifyEvent(
          GameEvent(GameEventType.treasure, "Treasure found！Score: $score"));
      return;
    }
    if (!treasureCollected && x > level.treasure.x && y > level.treasure.y) {
      saveScore(false);
      notifyEvent(GameEvent(GameEventType.obstacle, "Game Over！"));
      return;
    }
  }

  // ---- 執行 commands ----
  Future<void> executeCommands(List<Command> commands) async {
    for (var cmd in commands) {
      bool ok = await cmd.execute(this);
      if (!ok) return; // 撞障礙直接停止
    }
  }

  Future<void> saveScore(bool isPass) async {
    await service.saveUserGameScore(
      userName: userName,
      score: score.toDouble(),
      gameId: gameId, // 使用傳入的 gameId
      isPass: isPass,
    );
  }
}
