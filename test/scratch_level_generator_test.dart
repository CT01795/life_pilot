import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/game/steam_scratch/controller_game_steam_scratch_level_generator.dart';
import 'package:life_pilot/game/steam_scratch/model_scratch_level_generator.dart';
import 'package:life_pilot/game/steam_scratch/model_game_steam_scratch_level.dart';
import 'package:life_pilot/utils/value_parser.dart';

List<(int, int)> walls(ModelGameSteamScratchLevel level) =>
    level.obstacles.map((wall) => (wall.x, wall.y)).toList();
List<(int, int)> fruitPositions(ModelGameSteamScratchLevel level) =>
    level.fruits.map((fruit) => (fruit.x, fruit.y)).toList();

void expectSameLevel(
  ModelGameSteamScratchLevel actual,
  ModelGameSteamScratchLevel expected,
) {
  expect(actual.levelNumber, expected.levelNumber);
  expect(
    (actual.treasure.x, actual.treasure.y),
    (expected.treasure.x, expected.treasure.y),
  );
  expect(walls(actual), walls(expected));
  expect(fruitPositions(actual), fruitPositions(expected));
  expect(actual.treasure.scoreValue, 10);
  expect(actual.obstacles.every((wall) => wall.scoreValue == -1), true);
  expect(
    actual.fruits.every((fruit) => fruit.scoreValue == 1 && !fruit.collected),
    true,
  );
}

class _CornerRandom implements Random {
  final bool treasureCorner;
  int calls = 0;
  _CornerRandom(this.treasureCorner);
  @override
  int nextInt(int max) {
    calls++;
    return treasureCorner ? max - 1 : 0;
  }

  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0;
}

void main() {
  for (final number in [0, 1, 2, 5, 20, 100]) {
    test('level $number preserves old placement for 10 seeds', () {
      for (var seed = 0; seed < 10; seed++) {
        expectSameLevel(
          ModelScratchLevelGenerator(
            random: Random(seed),
          ).generateLevel(number),
          _LegacyGenerator(Random(seed)).generateLevel(number),
        );
      }
    });
  }
  test('old constructor alias retains level generation API', () {
    expectSameLevel(
      GameSteamScratchLevelGenerator(random: Random(12)).generateLevel(5),
      ModelScratchLevelGenerator(random: Random(12)).generateLevel(5),
    );
    expect(GameSteamScratchLevelGenerator().generateLevel(1).treasure.x, 2);
  });
  test(
    'reusing generator preserves random sequence and independent levels',
    () {
      final generator = ModelScratchLevelGenerator(random: Random(31));
      final reference = _LegacyGenerator(Random(31));
      final first = generator.generateLevel(8);
      expectSameLevel(first, reference.generateLevel(8));
      final second = generator.generateLevel(8);
      expectSameLevel(second, reference.generateLevel(8));
      final savedWalls = walls(second);
      final savedFruits = fruitPositions(second);
      first.obstacles.clear();
      first.fruits.clear();
      first.treasure.x = 0;
      expect(walls(second), savedWalls);
      expect(fruitPositions(second), savedFruits);
      expect(second.treasure.x, 9);
    },
  );
  for (final treasureCorner in [false, true]) {
    test(
      'bounded attempts when randomness repeats protected corner $treasureCorner',
      () {
        final random = _CornerRandom(treasureCorner);
        final level = ModelScratchLevelGenerator(
          random: random,
        ).generateLevel(10);
        expect(level.fruits, isEmpty);
        expect(level.obstacles, isEmpty);
        expect(random.calls, 2 * (14 * 5 + 14 * 10));
      },
    );
  }
  test(
    'placements are unique in bounds and protect both endpoint neighbours',
    () {
      for (var seed = 0; seed < 50; seed++) {
        final level = ModelScratchLevelGenerator(
          random: Random(seed),
        ).generateLevel(7);
        final edge = level.treasure.x;
        final obstaclePositions = walls(level).toSet();
        final fruitSet = fruitPositions(level).toSet();
        expect(obstaclePositions.length, level.obstacles.length);
        expect(fruitSet.length, level.fruits.length);
        expect(obstaclePositions.intersection(fruitSet), isEmpty);
        for (final position in [...obstaclePositions, ...fruitSet]) {
          expect(position.$1, inInclusiveRange(0, edge));
          expect(position.$2, inInclusiveRange(0, edge));
          expect(position, isNot((0, 0)));
          expect(position, isNot((edge, edge)));
        }
        for (final position in [
          (1, 0),
          (0, 1),
          (edge - 1, edge),
          (edge, edge - 1),
        ]) {
          expect(obstaclePositions, isNot(contains(position)));
        }
        expect(level.fruits.length, lessThanOrEqualTo(9));
        expect(level.obstacles.length, lessThanOrEqualTo(9));
      }
    },
  );
  test(
    'large board stores only placed elements and preserves target counts',
    () {
      final level = ModelScratchLevelGenerator(
        random: Random(20),
      ).generateLevel(500);
      expect(level.treasure.x, 551);
      expect(level.treasure.y, 551);
      expect(level.fruits.length, 700);
      expect(level.obstacles.length, 700);
      expect(
        walls(level).toSet().intersection(fruitPositions(level).toSet()),
        isEmpty,
      );
    },
  );
}

// Frozen pre-refactor placement algorithm; compares coordinates, not random icons.
class _LegacyGenerator {
  final Random random;
  _LegacyGenerator(this.random);
  ModelGameSteamScratchLevel generateLevel(int levelNumber) {
    final rand = random;
    final width = parseIntValue(levelNumber * 1.1) + 2;
    final height = width;

    final occupied = <String>{}; // 記錄已占位置
    final obstacles = <ModelGameSteamScratchObstacle>[];
    final fruits = <ModelGameSteamScratchFruit>[];

    int numObstacles = parseIntValue(levelNumber * 1.4);
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
    final treasure = ModelGameSteamScratchTreasure(x: treasureX, y: treasureY);

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
