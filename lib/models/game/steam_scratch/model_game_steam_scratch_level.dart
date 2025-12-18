// -------------------- Game Event --------------------
import 'package:flutter/material.dart';
import 'package:life_pilot/views/game/widgets_game_steam_scratch_game_board.dart';

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
  ModelGameSteamScratchTreasure({required this.x, required this.y, this.scoreValue = 10});
}

class ModelGameSteamScratchObstacle {
  int x;
  int y;
  int scoreValue;
  ModelGameSteamScratchObstacle({required this.x, required this.y, this.scoreValue = -1});
}

class ModelGameSteamScratchFruit {
  int x;
  int y;
  int scoreValue;
  bool collected = false;
  IconData icon;
  ModelGameSteamScratchFruit({
    required this.x, required this.y, this.scoreValue = 1, IconData? icon,
  }) : icon = icon ?? WidgetsGameSteamScratchGameBoard.getRandomFruitIconStatic();
}