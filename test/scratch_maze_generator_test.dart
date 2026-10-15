import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/game/steam_scratch_maze/controller_game_steam_scratch_maze_level_generator.dart';
import 'package:life_pilot/game/steam_scratch_maze/model_scratch_maze_generator.dart';
import 'package:life_pilot/game/steam_scratch_maze/model_game_steam_scratch_maze_level.dart';

List<(int, int)> walls(ModelGameSteamScratchMazeLevel level) =>
    level.obstacles.map((wall) => (wall.x, wall.y)).toList();

void expectConnected(ModelGameSteamScratchMazeLevel level) {
  final size = level.treasure.x + 1;
  final blocked = walls(level).toSet();
  final visited = <(int, int)>{(0, 0)};
  final queue = <(int, int)>[(0, 0)];
  for (var head = 0; head < queue.length; head++) {
    final (x, y) = queue[head];
    for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
      final next = (x + dx, y + dy);
      if (next.$1 >= 0 &&
          next.$2 >= 0 &&
          next.$1 < size &&
          next.$2 < size &&
          !blocked.contains(next) &&
          visited.add(next)) {
        queue.add(next);
      }
    }
  }
  expect(visited, contains((level.treasure.x, level.treasure.y)));
  expect(visited.length + blocked.length, size * size);
}

void main() {
  for (final number in [0, 1, 3, 12, 30]) {
    test('level $number exactly matches legacy walls for 12 seeds', () {
      for (var seed = 0; seed < 12; seed++) {
        final actual = ModelScratchMazeGenerator(
          random: Random(seed),
        ).generateLevel(number);
        final expected = _LegacyGenerator(Random(seed)).generateLevel(number);
        expect(walls(actual), walls(expected), reason: 'seed $seed');
        expect(actual.levelNumber, number);
        expect(actual.treasure.x, expected.treasure.x);
        expect(actual.treasure.y, expected.treasure.y);
        expect(actual.fruits, isEmpty);
        expectConnected(actual);
      }
    });
  }
  test('legacy constructor alias keeps seeded injection and level API', () {
    final actual = GameSteamScratchMazeLevelGenerator(
      random: Random(7),
    ).generateLevel(3);
    final expected = ModelScratchMazeGenerator(
      random: Random(7),
    ).generateLevel(3);
    expect(walls(actual), walls(expected));
    expect(
      GameSteamScratchMazeLevelGenerator().generateLevel(1).treasure.x,
      16,
    );
  });
  test('reusing generator consumes randomness without sharing level state', () {
    final generator = ModelScratchMazeGenerator(random: Random(9));
    final reference = _LegacyGenerator(Random(9));
    final first = generator.generateLevel(6);
    expect(walls(first), walls(reference.generateLevel(6)));
    final second = generator.generateLevel(6);
    expect(walls(second), walls(reference.generateLevel(6)));
    final secondWalls = walls(second);
    first.obstacles.clear();
    first.treasure.x = 0;
    expect(walls(second), secondWalls);
    expect(second.treasure.x, 20);
  });
  test('large level remains connected without recursive call stack', () {
    final level = ModelScratchMazeGenerator(
      random: Random(42),
    ).generateLevel(300);
    expect(level.treasure.x, 216);
    expect(level.treasure.y, 216);
    expect(walls(level).toSet().length, level.obstacles.length);
    expectConnected(level);
  });
}

// Frozen pre-refactor algorithm used only to verify seeded compatibility.
class _LegacyGenerator {
  final Random random;
  _LegacyGenerator(this.random);
  ModelGameSteamScratchMazeLevel generateLevel(int levelNumber) {
    final rand = random;

    // -----------------------------
    // 1️⃣ 設定迷宮尺寸（奇數正方形）
    // -----------------------------
    final baseSize = 17;
    final size = baseSize + (levelNumber ~/ 3) * 2;
    final width = size % 2 == 0 ? size + 1 : size;
    final height = width;

    // false = 牆, true = 路
    final maze = List.generate(
      width,
      (_) => List.generate(height, (_) => false),
    );
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
