// -------------------- Game Event --------------------
import 'package:flutter/material.dart';
import 'package:life_pilot/views/game/widgets_game_steam_super_hero_game_board.dart';

enum GameEventType { none, warning, fruit, obstacle, treasure, complete }

class GameEvent {
  final GameEventType type;
  final String message;
  GameEvent(this.type, this.message);
}

// -------------------- Game Level --------------------
class GameSteamSuperHeroLevel {
  int levelNumber;
  List<GameSteamSuperHeroObstacle> obstacles;
  List<GameSteamSuperHeroFruit> fruits;
  GameSteamSuperHeroTreasure treasure;

  GameSteamSuperHeroLevel({
    required this.levelNumber,
    required this.obstacles,
    required this.fruits,
    required this.treasure,
  });
}

class GameSteamSuperHeroTreasure {
  int x;
  int y;
  int scoreValue;
  GameSteamSuperHeroTreasure({required this.x, required this.y, this.scoreValue = 10});
}

class GameSteamSuperHeroObstacle {
  int x;
  int y;
  int scoreValue;
  GameSteamSuperHeroObstacle({required this.x, required this.y, this.scoreValue = -1});
}

class GameSteamSuperHeroFruit {
  int x;
  int y;
  int scoreValue;
  bool collected = false;
  IconData icon;
  GameSteamSuperHeroFruit({
    required this.x, required this.y, this.scoreValue = 1, IconData? icon,
  }) : icon = icon ?? WidgetsGameSteamSuperHeroGameBoard.getRandomFruitIconStatic();
}