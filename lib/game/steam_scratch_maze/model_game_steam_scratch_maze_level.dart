// -------------------- Game Event --------------------
import 'package:flutter/material.dart';
import 'package:life_pilot/game/steam_scratch_maze/widgets_game_steam_scratch_maze_game_board.dart';

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
  ModelGameSteamScratchMazeTreasure({required this.x, required this.y, this.scoreValue = 10});
}

class ModelGameSteamScratchMazeObstacle {
  int x;
  int y;
  int scoreValue;
  ModelGameSteamScratchMazeObstacle({required this.x, required this.y, this.scoreValue = -1});
}

class ModelGameSteamScratchMazeFruit {
  int x;
  int y;
  int scoreValue;
  bool collected = false;
  IconData icon;
  ModelGameSteamScratchMazeFruit({
    required this.x, required this.y, this.scoreValue = 1, IconData? icon,
  }) : icon = icon ?? WidgetsGameSteamScratchMazeGameBoard.getRandomFruitIconStatic();
}