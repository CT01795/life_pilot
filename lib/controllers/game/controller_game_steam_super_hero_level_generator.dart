import 'dart:math';

import 'package:life_pilot/models/game/model_game_steam_super_hero_level.dart';

class GameSteamSuperHeroLevelGenerator {
  GameSteamSuperHeroLevel generateLevel(int levelNumber) {
    final rand = Random();
    final width = min(levelNumber * 4 + 2, 50); // 隨著關卡增加寬度
    final height = min(levelNumber * 4 + 2, 50); // 隨著關卡增加寬度

    final occupied = <String>{}; // 儲存已佔位置 "x_y"
    final obstacles = <GameSteamSuperHeroObstacle>[];
    final fruits = <GameSteamSuperHeroFruit>[];

    int numObstacles = (levelNumber * 1.3).toInt() + 1;
    int numFruits = (levelNumber * 1.3).toInt() + 1;

    // 起點 (0,0) 這是玩家初始位置
    final startX = 0;
    final startY = 0;

    // 生成障礙物
    for (int i = 0; i < numObstacles; i++) {
      int x, y;
      do {
        // 隨機 X, Y 位置，確保不超過邊界並且不與已有物品重疊
        x = rand.nextInt(width);
        y = rand.nextInt(height);
      } while (
          occupied.contains('${x}_$y') || (x == startX && y == startY)); // 不重疊
      occupied.add('${x}_$y');
      obstacles.add(GameSteamSuperHeroObstacle(x: x, y: y));
    }

    // 生成水果
    for (int i = 0; i < numFruits; i++) {
      int x, y;
      do {
        // 隨機 X, Y 位置，確保不超過邊界並且不與已有物品重疊
        x = rand.nextInt(width);
        y = rand.nextInt(height);
      } while (
          occupied.contains('${x}_$y') || (x == startX && y == startY)); // 不重疊
      occupied.add('${x}_$y');
      fruits.add(GameSteamSuperHeroFruit(x: x, y: y));
    }

    // 生成寶藏，確保可通路且不重疊
    int treasureX, treasureY;
    List<List<int>> path;

    do {
      // 固定寶藏 X + 隨機偏移，確保在畫面內
      treasureX = levelNumber * 5 + rand.nextInt(3); // 寶藏 X，位置稍微偏移
      treasureY = rand.nextInt(height); // 寶藏 Y，隨機 0~5
      path = _findPath(
          startX, startY, treasureX, treasureY, width, height, occupied);
    } while (path.isEmpty);

    occupied.add('${treasureX}_$treasureY');
    final treasure = GameSteamSuperHeroTreasure(x: treasureX, y: treasureY);

    return GameSteamSuperHeroLevel(
      levelNumber: levelNumber,
      obstacles: obstacles,
      fruits: fruits,
      treasure: treasure,
    );
  }

  // BFS尋找路徑，確保有通路
  List<List<int>> _findPath(int startX, int startY, int endX, int endY,
      int width, int height, Set<String> occupied) {
    final visited = <String>{};
    final queue = <List<int>>[];
    final parent = <String, String>{};

    queue.add([startX, startY]);
    visited.add('${startX}_$startY');

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      final cx = current[0];
      final cy = current[1];

      if (cx == endX && cy == endY) {
        // 回溯路徑
        final path = <List<int>>[];
        String key = '${endX}_$endY';
        while (key != '${startX}_$startY') {
          final parts = key.split('_').map(int.parse).toList();
          path.add(parts);
          key = parent[key]!; // 回溯
        }
        path.add([startX, startY]);
        return path.reversed.toList();
      }

      final directions = [
        [0, 1],
        [0, -1],
        [1, 0],
        [-1, 0],
      ];

      for (var d in directions) {
        final nx = cx + d[0];
        final ny = cy + d[1];
        final key = '${nx}_$ny';

        // 確保不出界並且不與已佔位置重疊
        if (nx < 0 || nx >= width || ny < 0 || ny >= height) continue;
        if (visited.contains(key)) continue;
        if (occupied.contains(key)) continue;

        queue.add([nx, ny]);
        visited.add(key);
        parent[key] = '${cx}_$cy';
      }
    }

    return []; // 找不到路徑
  }
}
