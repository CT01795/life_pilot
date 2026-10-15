import 'package:life_pilot/game/steam_scratch_maze/model_game_steam_scratch_maze_level.dart';

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

class MazeStepResult {
  final List<ModelGameEvent> events;
  final bool needsSave;
  MazeStepResult(this.events, {this.needsSave = false});
}

/// Maze rules with indexed walls/fruit and side-effect-free walkability queries.
class ModelScratchMazeSession {
  final ModelGameSteamScratchMazeLevel level;
  GameState state = GameState();
  final Set<(int, int)> _walls = {};
  final Map<(int, int), List<ModelGameSteamScratchMazeFruit>> _fruits = {};

  ModelScratchMazeSession(this.level) {
    _walls.addAll(level.obstacles.map((wall) => (wall.x, wall.y)));
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

  bool isWalkable(int x, int y) =>
      x >= 0 &&
      y >= 0 &&
      x <= level.treasure.x &&
      y <= level.treasure.y &&
      !_walls.contains((x, y));

  bool hasJunction(int dx, int dy) =>
      dx.abs() + dy.abs() == 1 &&
      (dx != 0
          ? isWalkable(state.x, state.y - 1) || isWalkable(state.x, state.y + 1)
          : isWalkable(state.x - 1, state.y) ||
                isWalkable(state.x + 1, state.y));

  MazeStepResult? step(int dx, int dy) {
    if (dx.abs() + dy.abs() != 1 || !isWalkable(state.x + dx, state.y + dy)) {
      return null;
    }
    state.x += dx;
    state.y += dy;
    final events = <ModelGameEvent>[];
    for (final fruit
        in _fruits[(state.x, state.y)] ??
            const <ModelGameSteamScratchMazeFruit>[]) {
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
      state.treasureCollected = true;
      state.score += level.treasure.scoreValue;
      events.add(
        ModelGameEvent(
          EnumGameEventType.treasure,
          'Treasure found！Score: ${state.score}',
        ),
      );
      return MazeStepResult(events, needsSave: true);
    }
    return MazeStepResult(events);
  }

  void rollbackTreasure() {
    if (!state.treasureCollected) return;
    state.treasureCollected = false;
    state.score -= level.treasure.scoreValue;
  }
}
