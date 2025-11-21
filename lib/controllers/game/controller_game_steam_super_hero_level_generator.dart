import 'dart:math';

import 'package:life_pilot/models/game/model_game_steam_super_hero_level.dart';

class GameSteamSuperHeroLevelGenerator {
  GameSteamSuperHeroLevel generateLevel(int levelNumber) {
    final rand = Random();
    final width = min(levelNumber * 3 + 2, 50); // 隨著關卡增加寬度
    final height = min(levelNumber * 3 + 2, 50); // 隨著關卡增加高度

    final occupied = <String>{}; // 儲存已佔位置 "x_y"
    final obstacles = <GameSteamSuperHeroObstacle>[];
    final fruits = <GameSteamSuperHeroFruit>[];

    int numObstacles = (levelNumber * 1.3).toInt() + 1;
    int numFruits = (levelNumber * 1.3).toInt() + 1;

    // 起點 (0,0) 這是玩家初始位置
    final startX = 0;
    final startY = 0;

    // 生成水果
    for (int i = 0; i < numFruits; i++) {
      int x, y;
      do {
        // 隨機 X, Y 位置，確保不超過邊界並且不與已有物品重疊
        x = rand.nextInt(width);
        y = rand.nextInt(height);
      } while (occupied.contains('${x}_$y') || (x == startX && y == startY)); // 不重疊
      occupied.add('${x}_$y');
      fruits.add(GameSteamSuperHeroFruit(x: x, y: y));
    }

    // 生成寶藏，確保四個方向不被障礙物完全包住
    int treasureX, treasureY;
    do {
      treasureX = levelNumber * 5 + rand.nextInt(3); // 寶藏 X，位置稍微偏移
      treasureY = rand.nextInt(height); // 寶藏 Y，隨機 0~5
    } while (!_checkTreasureAccessibility(treasureX, treasureY, width, height, occupied));

    occupied.add('${treasureX}_$treasureY');
    final treasure = GameSteamSuperHeroTreasure(x: treasureX, y: treasureY);

    // 生成障礙物
    for (int i = 0; i < numObstacles; i++) {
      int x, y;
      do {
        // 隨機 X, Y 位置，確保不超過邊界並且不與已有物品重疊
        x = rand.nextInt(width);
        y = rand.nextInt(height);
      } while (occupied.contains('${x}_$y') || (x == startX && y == startY) || // 不與已存在的水果或寶藏重疊
               _isNearTreasure(x, y, treasureX, treasureY)); // 確保不與寶藏相鄰

      // 如果與水果或寶藏重疊，跳過此障礙物
      if (occupied.contains('${x}_$y') || _isNearTreasure(x, y, treasureX, treasureY)) continue;

      occupied.add('${x}_$y');
      obstacles.add(GameSteamSuperHeroObstacle(x: x, y: y));
    }

    return GameSteamSuperHeroLevel(
      levelNumber: levelNumber,
      obstacles: obstacles,
      fruits: fruits,
      treasure: treasure,
    );
  }

  // 檢查寶藏的四個方向是否有通路
  bool _checkTreasureAccessibility(int treasureX, int treasureY, int width, int height, Set<String> occupied) {
    final directions = [
      [0, 1], // 下
      [0, -1], // 上
      [1, 0], // 右
      [-1, 0], // 左
    ];

    for (var direction in directions) {
      final nx = treasureX + direction[0];
      final ny = treasureY + direction[1];

      // 確保新位置在範圍內並且不被佔用
      if (nx >= 0 && nx < width && ny >= 0 && ny < height && !occupied.contains('${nx}_$ny')) {
        return true; // 至少有一個方向可通行
      }
    }
    return false; // 如果四個方向都被包圍了，返回 false
  }

  // 檢查障礙物是否與寶藏過近 (例如相鄰)
  bool _isNearTreasure(int obstacleX, int obstacleY, int treasureX, int treasureY) {
    final directions = [
      [0, 1], // 下
      [0, -1], // 上
      [1, 0], // 右
      [-1, 0], // 左
    ];

    for (var direction in directions) {
      final nx = treasureX + direction[0];
      final ny = treasureY + direction[1];

      if (nx == obstacleX && ny == obstacleY) {
        return true; // 若障礙物與寶藏相鄰，返回 true
      }
    }
    return false;
  }
}