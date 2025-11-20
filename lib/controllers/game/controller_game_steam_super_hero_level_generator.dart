import 'package:life_pilot/models/game/model_game_steam_super_hero_level.dart';

class GameSteamSuperHeroLevelGenerator {
  GameSteamSuperHeroLevel generateLevel(int levelNumber) {
    int numObstacles = levelNumber + 2;
    int numFruits = levelNumber + 1;
    List<GameSteamSuperHeroObstacle> obstacles = List.generate(numObstacles, (i) => GameSteamSuperHeroObstacle(x: i*3+2, y: i%2));
    List<GameSteamSuperHeroFruit> fruits = List.generate(numFruits, (i) => GameSteamSuperHeroFruit(x: i*2+1, y: i%2));
    GameSteamSuperHeroTreasure treasure = GameSteamSuperHeroTreasure(x: 10 + levelNumber*2, y: 0);
    return GameSteamSuperHeroLevel(
      levelNumber: levelNumber,
      obstacles: obstacles,
      fruits: fruits,
      treasure: treasure,
    );
  }
}
