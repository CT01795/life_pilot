import 'dart:math';

import 'package:life_pilot/game/steam_scratch/model_game_steam_scratch_level.dart';

/// Domain-only placement rules with injectable randomness for reproducible tests.
class ModelScratchLevelGenerator {
  final Random _random;
  ModelScratchLevelGenerator({Random? random}) : _random = random ?? Random();
  ModelGameSteamScratchLevel generateLevel(int levelNumber) {
    final rand = _random;
    final width = (levelNumber * 1.1).toInt() + 2;
    final height = width;

    final occupied = <(int, int)>{}; // 記錄已占位置
    final obstacles = <ModelGameSteamScratchObstacle>[];
    final fruits = <ModelGameSteamScratchFruit>[];

    int numObstacles = (levelNumber * 1.4).toInt();
    int numFruits = numObstacles;

    // 玩家起點
    final startX = 0;
    final startY = 0;
    occupied.add((startX, startY));

    // -------------------------------
    // 1️⃣ 生成寶藏（固定在右下角前一格）
    // -------------------------------
    final treasureX = width - 1;
    final treasureY = height - 1;

    occupied.add((treasureX, treasureY));
    final treasure = ModelGameSteamScratchTreasure(x: treasureX, y: treasureY);

    // -------------------------------
    // 2️⃣ 生成水果
    // -------------------------------
    int attempts = 0;
    while (fruits.length < numFruits && attempts < numFruits * 5) {
      final x = rand.nextInt(width);
      final y = rand.nextInt(height);
      final position = (x, y);

      if (!occupied.contains(position)) {
        occupied.add(position);
        fruits.add(ModelGameSteamScratchFruit(x: x, y: y));
      }
      attempts++;
    }

    final treasureDirs = [
      [0, 1],
      [0, -1],
      [1, 0],
      [-1, 0],
    ];
    final treasureOpenPositions = <(int, int)>{};
    for (var dir in treasureDirs) {
      int nx = treasureX + dir[0];
      int ny = treasureY + dir[1];
      if (nx >= 0 && nx < width && ny >= 0 && ny < height) {
        treasureOpenPositions.add((nx, ny));
      }
      nx = startX + dir[0];
      ny = startY + dir[1];
      if (nx >= 0 && nx < width && ny >= 0 && ny < height) {
        treasureOpenPositions.add((nx, ny));
      }
    }

    // -------------------------------
    // 3️⃣ 生成障礙物（避開寶藏及寶藏至少保留一方向空格）
    // -------------------------------
    attempts = 0;
    while (obstacles.length < numObstacles && attempts < numObstacles * 10) {
      final x = rand.nextInt(width);
      final y = rand.nextInt(height);
      final position = (x, y);

      // 避開寶藏本身、寶藏周圍空格、起點
      if (occupied.contains(position) ||
          treasureOpenPositions.contains(position)) {
        attempts++;
        continue;
      }

      occupied.add(position);
      obstacles.add(ModelGameSteamScratchObstacle(x: x, y: y));
      attempts++;
    }

    return ModelGameSteamScratchLevel(
      levelNumber: levelNumber,
      obstacles: obstacles,
      fruits: fruits,
      treasure: treasure,
    );
  }
}
