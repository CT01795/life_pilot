import 'dart:math';
import 'package:flutter/material.dart';

enum EnumPolyominoTileType { empty, pipe, start, goal }

class ModelGamePolyominoTile extends ChangeNotifier {
  EnumPolyominoTileType type;
  bool up = false;
  bool right = false;
  bool down = false;
  bool left = false;
  int? blockId;
  bool highlight = false; // ⭐ Hint
  // ⭐ 用於 Hint：該格方向（完整 block 的方向）
  List<bool>? hintDirs;

  ModelGamePolyominoTile({this.type = EnumPolyominoTileType.empty});

  void clearHint() {
    highlight = false;
    hintDirs = null;
  }

  void reset() {
    type = EnumPolyominoTileType.empty;
    up = right = down = left = false;
    blockId = null;
    clearHint();
    notifyListeners();
  }
}

// PipeBlock：每格有自己的方向（up,right,down,left）
class ModelGamePolyominoPipeBlock extends ChangeNotifier {
  final int id;
  List<Point<int>> cells; // (0,0) 起始
  List<List<bool>> connections; // 每個 cell 的 [up,right,down,left]

  int originX = -1; // 放在 grid 的座標
  int originY = -1;

  ModelGamePolyominoPipeBlock({
    required this.id,
    required this.cells,
    required this.connections,
  });

  int get width => cells.isEmpty
      ? 1
      : cells.map((c) => c.x).reduce(max) -
          cells.map((c) => c.x).reduce(min) +
          1;
  int get height => cells.isEmpty
      ? 1
      : cells.map((c) => c.y).reduce(max) -
          cells.map((c) => c.y).reduce(min) +
          1;

  // 右旋 90°，任意形狀 block 皆適用
  void rotateRight() {
    final h = height;

    // 旋轉 cell 座標：90°順時針
    cells = cells.map((c) => Point(h - 1 - c.y, c.x)).toList();

    // normalize: 最小 x/y 移到 0
    final minX = cells.map((c) => c.x).reduce(min);
    final minY = cells.map((c) => c.y).reduce(min);
    cells = cells.map((c) => Point(c.x - minX, c.y - minY)).toList();

    // 旋轉 cell 方向：右旋 90°
    connections = connections.map((conn) {
      // 原方向 [up, right, down, left] → 旋轉後 [left, up, right, down]
      return [conn[3], conn[0], conn[1], conn[2]];
    }).toList();

    notifyListeners();
  }

  ModelGamePolyominoPipeBlock clone() {
    return ModelGamePolyominoPipeBlock(
      id: id,
      cells: List.from(cells),
      connections: connections.map((c) => List<bool>.from(c)).toList(),
    )
      ..originX = originX
      ..originY = originY;
  }
}

class ModelGamePolyominoLevelData {
  final int rows;
  final int cols;
  final Point<int> start;
  final Point<int> goal;
  final List<ModelGamePolyominoPipeBlock> availableBlocks;
  final List<Point<int>> path;

  ModelGamePolyominoLevelData(
      {required this.rows,
      required this.cols,
      required this.start,
      required this.goal,
      required this.availableBlocks,
      required this.path});
}

class ModelGamePolyominoLevelFactory {
  static ModelGamePolyominoLevelData generateLevel(int level) {
    int rows = 3 + (level / 3).ceil();
    int cols = rows;

    final start = const Point(0, 0);
    final goal = Point(cols - 1, rows - 1);

    while (true) {
      final path = _generatePath(start, goal, rows, level);

      // 計算 start/goal 的方向
      Map<Point<int>, List<bool>> tileDirections = {};
      for (int i = 0; i < path.length; i++) {
        final cur = path[i];
        bool up = false, right = false, down = false, left = false;

        if (cur == start) {
          // 起點只看下一格
          final next = path[i + 1];
          up = next.y == cur.y - 1;
          down = next.y == cur.y + 1;
          left = next.x == cur.x - 1;
          right = next.x == cur.x + 1;
        } else if (cur == goal) {
          // 終點只看前一格
          final prev = path[i - 1];
          up = prev.y == cur.y - 1;
          down = prev.y == cur.y + 1;
          left = prev.x == cur.x - 1;
          right = prev.x == cur.x + 1;
        } else {
          // 中間格子照原本計算前後格方向
          final prev = path[i - 1];
          final next = path[i + 1];
          up = (prev.y == cur.y - 1 || next.y == cur.y - 1);
          down = (prev.y == cur.y + 1 || next.y == cur.y + 1);
          left = (prev.x == cur.x - 1 || next.x == cur.x - 1);
          right = (prev.x == cur.x + 1 || next.x == cur.x + 1);
        }

        tileDirections[cur] = [up, right, down, left];
      }

      final blocks = pathToPipeBlocks(path, start, goal, level);

      // ⭐ 檢查 cells 總數是否超過 path 長度
      int totalCells = blocks.fold(0, (sum, b) => sum + b.cells.length);
      if (totalCells <= path.length) {
        return ModelGamePolyominoLevelData(
          rows: rows,
          cols: cols,
          start: start,
          goal: goal,
          availableBlocks: blocks,
          path: path,
        );
      }
    }
  }

  static List<Point<int>> _generatePath(
      Point<int> start, Point<int> goal, int rows, int level) {
    final rnd = Random();
    List<Point<int>> path;
    double rate = 20;
    int cellCount = rows * rows;
    // 重試直到成功生成一條從 start 到 goal 的路徑
    while (true) {
      path = [start];
      var cur = start;
      Set<Point<int>> visited = {cur};

      // 記錄上一個移動方向，用來控制蜿蜒程度
      Point<int> lastDir = const Point(1, 0); // 初始假設向右

      bool stuck = false;

      while (cur != goal && path.length < cellCount) {
        List<Point<int>> candidates = [];

        // 四個方向
        final dirs = [
          Point(0, -1), // 上
          Point(1, 0), // 右
          Point(0, 1), // 下
          Point(-1, 0), // 左
        ];

        for (var d in dirs) {
          final next = Point(cur.x + d.x, cur.y + d.y);

          // 邊界檢查
          if (next.x < 0 || next.y < 0 || next.x > goal.x || next.y > goal.y) {
            continue;
          }

          // 避免回到已走過的格子
          if (visited.contains(next)) continue;

          candidates.add(d);
        }

        if (candidates.isEmpty) {
          // 無法繼續走，標記 stuck
          stuck = true;
          break;
        }

        // 控制蜿蜒程度
        Point<int> chosenDir;
        if (rnd.nextInt(100) < rate && candidates.contains(lastDir)) {
          // rate% 保持原方向
          chosenDir = lastDir;
        } else {
          chosenDir = candidates[rnd.nextInt(candidates.length)];
        }

        cur = Point(cur.x + chosenDir.x, cur.y + chosenDir.y);
        path.add(cur);
        visited.add(cur);
        lastDir = chosenDir;
      }

      // 如果成功到達 goal 且沒 stuck，就返回 path
      if (!stuck && path.last == goal) {
        return path;
      }
    }
    // 否則重新生成路徑
  }

  static int getWeightedSegmentSize(Random rnd, int maxSize) {
    // 權重表：index = segment size - 1
    // segment size 1,2,3,4,5 的權重
    List<int> weights = [1, maxSize + 2, maxSize + 3, maxSize + 1, 1];
    // 如果 maxSize < 5，就只取前 maxSize 個權重
    weights = weights.sublist(0, maxSize);

    // 計算權重總和
    int total = weights.reduce((a, b) => a + b);
    int r = rnd.nextInt(total);

    // 根據權重選擇 segment size
    int sum = 0;
    for (int i = 0; i < weights.length; i++) {
      sum += weights[i];
      if (r < sum) return i + 1;
    }
    return 1; // 預設 fallback
  }

  static List<ModelGamePolyominoPipeBlock> pathToPipeBlocks(
      List<Point<int>> path, Point<int> start, Point<int> goal, int level) {
    List<ModelGamePolyominoPipeBlock> blocks = [];
    int id = 1;
    int i = 0;
    final rnd = Random();
    // 隨機 segment 長度 1~5
    int maxSize = min(level + 1, 5);

    while (i < path.length) {
      int size = getWeightedSegmentSize(rnd, maxSize);
      // 不能超過 goal
      int end = min(i + size, path.length);
      List<Point<int>> seg = path.sublist(i, end);

      // origin 為 segment 的第一格
      final ox = seg[0].x;
      final oy = seg[0].y;

      List<Point<int>> cells = [];
      List<int> validIndices = [];

      // 過濾掉 start/goal
      for (int idx = 0; idx < seg.length; idx++) {
        final p = seg[idx];
        if (p == start || p == goal) continue; // ✅ 排除 start/goal
        cells.add(Point(p.x - ox, p.y - oy));
        validIndices.add(i + idx); // 對應 path 的全域索引
      }

      // 如果這段沒有可用格子就跳過
      if (cells.isEmpty) {
        i += size;
        continue;
      }

      List<List<bool>> connections = [];
      for (var idx in validIndices) {
        final cur = path[idx];
        bool up = false, right = false, down = false, left = false;

        // 上一格（前一格若是 start/goal 也算）
        if (idx > 0) {
          final prev = path[idx - 1];
          if (prev.x == cur.x && prev.y == cur.y - 1) up = true;
          if (prev.x == cur.x && prev.y == cur.y + 1) down = true;
          if (prev.x == cur.x - 1 && prev.y == cur.y) left = true;
          if (prev.x == cur.x + 1 && prev.y == cur.y) right = true;
        }

        // 下一格（後一格若是 start/goal 也算）
        if (idx < path.length - 1) {
          final next = path[idx + 1];
          if (next.x == cur.x && next.y == cur.y - 1) up = true;
          if (next.x == cur.x && next.y == cur.y + 1) down = true;
          if (next.x == cur.x - 1 && next.y == cur.y) left = true;
          if (next.x == cur.x + 1 && next.y == cur.y) right = true;
        }

        connections.add([up, right, down, left]);
      }

      blocks.add(ModelGamePolyominoPipeBlock(
        id: id++,
        cells: cells,
        connections: connections,
      ));

      // 下一段
      i = end;
    }

    return blocks;
  }
}

enum EnumPolyominoDragSource { waiting, grid }

class ModelGamePolyominoDragBlockData {
  final ModelGamePolyominoPipeBlock block;
  final EnumPolyominoDragSource source;
  ModelGamePolyominoDragBlockData({required this.block, required this.source});
}
