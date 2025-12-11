// -------------------- Game Event --------------------
import 'package:flutter/material.dart';
import 'package:life_pilot/views/game/widgets_game_steam_super_hero_game_board.dart';

enum EnumGameEventType { none, warning, fruit, obstacle, treasure, complete }

class ModelGameEvent {
  final EnumGameEventType type;
  final String message;
  ModelGameEvent(this.type, this.message);
}

// -------------------- Game Level --------------------
class ModelGameSteamSuperHeroLevel {
  int levelNumber;
  List<ModelGameSteamSuperHeroObstacle> obstacles;
  List<ModelGameSteamSuperHeroFruit> fruits;
  ModelGameSteamSuperHeroTreasure treasure;

  ModelGameSteamSuperHeroLevel({
    required this.levelNumber,
    required this.obstacles,
    required this.fruits,
    required this.treasure,
  });
}

class ModelGameSteamSuperHeroTreasure {
  int x;
  int y;
  int scoreValue;
  ModelGameSteamSuperHeroTreasure({required this.x, required this.y, this.scoreValue = 10});
}

class ModelGameSteamSuperHeroObstacle {
  int x;
  int y;
  int scoreValue;
  ModelGameSteamSuperHeroObstacle({required this.x, required this.y, this.scoreValue = -1});
}

class ModelGameSteamSuperHeroFruit {
  int x;
  int y;
  int scoreValue;
  bool collected = false;
  IconData icon;
  ModelGameSteamSuperHeroFruit({
    required this.x, required this.y, this.scoreValue = 1, IconData? icon,
  }) : icon = icon ?? WidgetsGameSteamSuperHeroGameBoard.getRandomFruitIconStatic();
}