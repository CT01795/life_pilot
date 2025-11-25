import 'dart:math';

import 'package:life_pilot/models/game/model_game_steam_super_hero_level.dart';

class GameSteamSuperHeroLevelGenerator {
  GameSteamSuperHeroLevel generateLevel(int levelNumber) {
    final rand = Random();
    final width = (levelNumber * 1.1).toInt() + 2;
    final height = width;

    final occupied = <String>{}; // 記錄已占位置
    final obstacles = <GameSteamSuperHeroObstacle>[];
    final fruits = <GameSteamSuperHeroFruit>[];

    int numObstacles = (levelNumber * 1.4).toInt();
    int numFruits = numObstacles;

    // 玩家起點
    final startX = 0;
    final startY = 0;
    occupied.add('${startX}_$startY');

    // -------------------------------
    // 1️⃣ 生成寶藏（固定在右下角前一格）
    // -------------------------------
    final treasureX = width - 1;
    final treasureY = height - 1;

    occupied.add('${treasureX}_$treasureY');
    final treasure = GameSteamSuperHeroTreasure(x: treasureX, y: treasureY);

    // -------------------------------
    // 2️⃣ 生成水果
    // -------------------------------
    int attempts = 0;
    while (fruits.length < numFruits && attempts < numFruits * 5) {
      final x = rand.nextInt(width);
      final y = rand.nextInt(height);
      final posKey = '${x}_$y';

      if (!occupied.contains(posKey)) {
        occupied.add(posKey);
        fruits.add(GameSteamSuperHeroFruit(x: x, y: y));
      }
      attempts++;
    }

    final treasureDirs = [
      [0, 1],
      [0, -1],
      [1, 0],
      [-1, 0],
    ];
    final treasureOpenPositions = <String>[];
    for (var dir in treasureDirs) {
      int nx = treasureX + dir[0];
      int ny = treasureY + dir[1];
      if (nx >= 0 && nx < width && ny >= 0 && ny < height) {
        treasureOpenPositions.add('${nx}_$ny');
      }
      nx = startX + dir[0];
      ny = startY + dir[1];
      if (nx >= 0 && nx < width && ny >= 0 && ny < height) {
        treasureOpenPositions.add('${nx}_$ny');
      }
    }

    // -------------------------------
    // 3️⃣ 生成障礙物（避開寶藏及寶藏至少保留一方向空格）
    // -------------------------------
    attempts = 0;
    while (obstacles.length < numObstacles && attempts < numObstacles * 10) {
      final x = rand.nextInt(width);
      final y = rand.nextInt(height);
      final posKey = '${x}_$y';

      // 避開寶藏本身、寶藏周圍空格、起點
      if (occupied.contains(posKey) || treasureOpenPositions.contains(posKey)) {
        attempts++;
        continue;
      }

      occupied.add(posKey);
      obstacles.add(GameSteamSuperHeroObstacle(x: x, y: y));
      attempts++;
    }

    return GameSteamSuperHeroLevel(
      levelNumber: levelNumber,
      obstacles: obstacles,
      fruits: fruits,
      treasure: treasure,
    );
  }
}
