import 'dart:math';
import 'package:life_pilot/game/steam_scratch/model_game_steam_scratch_level.dart';

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

class ScratchMovementResult {
  final bool shouldContinue;
  final bool needsSave;
  final List<ModelGameEvent> events;
  ScratchMovementResult(
    this.shouldContinue,
    this.events, {
    this.needsSave = false,
  });
}

/// Pure movement/collision/scoring state. Coordinates are fixed for this level.
class ModelScratchSession {
  final ModelGameSteamScratchLevel level;
  GameState state = GameState();
  final Map<(int, int), ModelGameSteamScratchObstacle> _obstacles = {};
  final Map<(int, int), List<ModelGameSteamScratchFruit>> _fruits = {};

  ModelScratchSession(this.level) {
    for (final obstacle in level.obstacles) {
      _obstacles.putIfAbsent((obstacle.x, obstacle.y), () => obstacle);
    }
    for (final fruit in level.fruits) {
      (_fruits[(fruit.x, fruit.y)] ??= []).add(fruit);
    }
  }

  void reset() {
    state = GameState();
    for (final fruit in level.fruits) {
      fruit.collected = false;
    }
  }

  void move({bool backward = false, int turn = 0, int? vertical}) {
    if (vertical != null) {
      state.y += vertical;
      return;
    }
    state.facing = Direction.values[(state.facing.index + turn) % 4];
    final sign = backward ? -1 : 1;
    switch (state.facing) {
      case Direction.north:
        state.y += sign;
      case Direction.east:
        state.x += sign;
      case Direction.south:
        state.y -= sign;
      case Direction.west:
        state.x -= sign;
    }
  }

  ScratchMovementResult resolveMovement() {
    final events = <ModelGameEvent>[];
    state.x = state.x.clamp(-1, level.treasure.x + 1);
    state.y = state.y.clamp(-1, level.treasure.y + 1);
    if (state.x < 0 ||
        state.x > level.treasure.x ||
        state.y < 0 ||
        state.y > level.treasure.y) {
      events.add(
        ModelGameEvent(EnumGameEventType.obstacle, 'Fall off a cliff！'),
      );
      return ScratchMovementResult(false, events);
    }
    final obstacle = _obstacles[(state.x, state.y)];
    if (obstacle != null) {
      state.score += obstacle.scoreValue;
      events.add(
        ModelGameEvent(EnumGameEventType.obstacle, 'Hit an obstacle！'),
      );
      return ScratchMovementResult(false, events);
    }
    for (final fruit
        in _fruits[(state.x, state.y)] ??
            const <ModelGameSteamScratchFruit>[]) {
      if (fruit.collected) continue;
      fruit.collected = true;
      state.score += fruit.scoreValue;
      events.add(
        ModelGameEvent(EnumGameEventType.fruit, 'Food +${fruit.scoreValue}!'),
      );
    }
    if (!state.treasureCollected &&
        state.x == level.treasure.x &&
        state.y == level.treasure.y) {
      final required = min(
        (level.levelNumber * 0.5).toInt(),
        level.fruits.length,
      );
      if (state.score < required) {
        events.add(
          ModelGameEvent(
            EnumGameEventType.warning,
            'Eat at least $required foods !!',
          ),
        );
        return ScratchMovementResult(true, events);
      }
      state.treasureCollected = true;
      state.score += level.treasure.scoreValue;
      events.add(
        ModelGameEvent(
          EnumGameEventType.treasure,
          'Treasure found！Score: ${state.score}',
        ),
      );
      return ScratchMovementResult(false, events, needsSave: true);
    }
    return ScratchMovementResult(true, events);
  }

  void rollbackTreasure() {
    if (!state.treasureCollected) return;
    state.treasureCollected = false;
    state.score -= level.treasure.scoreValue;
  }
}
