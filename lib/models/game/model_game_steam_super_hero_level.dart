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
  GameSteamSuperHeroFruit({required this.x, required this.y, this.scoreValue = 1});
}