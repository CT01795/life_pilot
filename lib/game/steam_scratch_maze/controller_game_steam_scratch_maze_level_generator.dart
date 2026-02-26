import 'dart:math';

import 'package:life_pilot/game/steam_scratch_maze/model_game_steam_scratch_maze_level.dart';

class GameSteamScratchMazeLevelGenerator {
  ModelGameSteamScratchMazeLevel generateLevel(int levelNumber) {
    final rand = Random();

    // -----------------------------
    // 1️⃣ 設定迷宮尺寸（奇數正方形）
    // -----------------------------
    final baseSize = 17;
    final size = baseSize + (levelNumber ~/ 3) * 2;
    final width = size % 2 == 0 ? size + 1 : size;
    final height = width;

    // false = 牆, true = 路
    final maze =
        List.generate(width, (_) => List.generate(height, (_) => false));
    final fruits = <ModelGameSteamScratchMazeFruit>[];

    const startX = 0;
    const startY = 0;
    final exitX = width - 1; // 右上角出口
    final exitY = height - 1;

    // -----------------------------
    // 2️⃣ 隨機 DFS 挖迷宮（保證出口可達）
    // -----------------------------
    void carve(int x, int y) {
      maze[x][y] = true;

      final dirs = [
        [1, 0],
        [-1, 0],
        [0, 1],
        [0, -1],
      ]..shuffle(rand);

      for (var d in dirs) {
        int nx = x + d[0] * 2;
        int ny = y + d[1] * 2;

        if (nx < 0 || ny < 0 || nx >= width || ny >= height) continue;

        // 打通中間牆
        if (!maze[nx][ny]) {
          maze[x + d[0]][y + d[1]] = true;
          carve(nx, ny);
        }
      }
    }

    carve(startX, startY);

    // -----------------------------
    // 3️⃣ 隨機打牆增加岔路
    // -----------------------------
    for (int x = 1; x < width - 1; x++) {
      for (int y = 1; y < height - 1; y++) {
        // 如果是牆，且鄰格有路，則有小機率打通形成岔路
        if (!maze[x][y]) {
          int adjacentPaths = 0;
          if (maze[x + 1][y]) adjacentPaths++;
          if (maze[x - 1][y]) adjacentPaths++;
          if (maze[x][y + 1]) adjacentPaths++;
          if (maze[x][y - 1]) adjacentPaths++;

          if (adjacentPaths == 2 && rand.nextInt(100) < 10) {
            maze[x][y] = true; // 10% 機率打通牆
          }
        }
      }
    }

    // -----------------------------
    // 4️⃣ 確保出口可達
    // -----------------------------
    maze[exitX][exitY] = true;
    if (!maze[exitX - 1][exitY]) maze[exitX - 1][exitY] = true;
    if (!maze[exitX][exitY - 1]) maze[exitX][exitY - 1] = true;

    // -----------------------------
    // 5️⃣ 生成障礙物（牆）
    // -----------------------------
    final obstacles = <ModelGameSteamScratchMazeObstacle>[];
    for (int x = 0; x < width; x++) {
      for (int y = 0; y < height; y++) {
        if (!maze[x][y]) {
          obstacles.add(ModelGameSteamScratchMazeObstacle(x: x, y: y));
        }
      }
    }

    // -----------------------------
    // 6️⃣ 寶藏放在出口
    // -----------------------------
    final treasure = ModelGameSteamScratchMazeTreasure(x: exitX, y: exitY);

    return ModelGameSteamScratchMazeLevel(
      levelNumber: levelNumber,
      obstacles: obstacles,
      fruits: fruits,
      treasure: treasure,
    );
  }
}
