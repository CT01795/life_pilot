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
class ModelGameSteamScratchLevel {
  int levelNumber;
  List<ModelGameSteamScratchObstacle> obstacles;
  List<ModelGameSteamScratchFruit> fruits;
  ModelGameSteamScratchTreasure treasure;

  ModelGameSteamScratchLevel({
    required this.levelNumber,
    required this.obstacles,
    required this.fruits,
    required this.treasure,
  });
}

class ModelGameSteamScratchTreasure {
  int x;
  int y;
  int scoreValue;
  ModelGameSteamScratchTreasure({
    required this.x,
    required this.y,
    this.scoreValue = 10,
  });
}

class ModelGameSteamScratchObstacle {
  int x;
  int y;
  int scoreValue;
  ModelGameSteamScratchObstacle({
    required this.x,
    required this.y,
    this.scoreValue = -1,
  });
}

class ModelGameSteamScratchFruit {
  int x;
  int y;
  int scoreValue;
  bool collected = false;
  final EnumScratchFruitAppearance appearance;
  ModelGameSteamScratchFruit({
    required this.x,
    required this.y,
    this.scoreValue = 1,
    EnumScratchFruitAppearance? appearance,
  }) : appearance = appearance ?? randomGameFruitAppearance();
}
