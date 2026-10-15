// -------------------- Game Event --------------------
import 'package:life_pilot/game/model_game_fruit_appearance.dart';
export 'package:life_pilot/game/model_game_fruit_appearance.dart'
    show EnumScratchFruitAppearance;

enum EnumGameEventType { none, warning, fruit, obstacle, treasure, complete }

class ModelGameEvent {
  final EnumGameEventType type;
  final String message;
  ModelGameEvent(this.type, this.message);
}

// -------------------- Game Level --------------------
class ModelGameSteamScratchMazeLevel {
  int levelNumber;
  List<ModelGameSteamScratchMazeObstacle> obstacles;
  List<ModelGameSteamScratchMazeFruit> fruits;
  ModelGameSteamScratchMazeTreasure treasure;

  ModelGameSteamScratchMazeLevel({
    required this.levelNumber,
    required this.obstacles,
    required this.fruits,
    required this.treasure,
  });
}

class ModelGameSteamScratchMazeTreasure {
  int x;
  int y;
  int scoreValue;
  ModelGameSteamScratchMazeTreasure({
    required this.x,
    required this.y,
    this.scoreValue = 10,
  });
}

class ModelGameSteamScratchMazeObstacle {
  int x;
  int y;
  int scoreValue;
  ModelGameSteamScratchMazeObstacle({
    required this.x,
    required this.y,
    this.scoreValue = -1,
  });
}

class ModelGameSteamScratchMazeFruit {
  int x;
  int y;
  int scoreValue;
  bool collected = false;
  final EnumScratchFruitAppearance appearance;
  ModelGameSteamScratchMazeFruit({
    required this.x,
    required this.y,
    this.scoreValue = 1,
    EnumScratchFruitAppearance? appearance,
  }) : appearance = appearance ?? randomGameFruitAppearance();
}
