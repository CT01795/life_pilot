import 'dart:collection';
import 'dart:math';

import 'package:life_pilot/utils/safe_change_notifier.dart';
import 'package:life_pilot/utils/value_parser.dart';

enum EnumMonominoTileDirection { up, down, left, right, empty }

class ModelGameMonominoTile extends SafeChangeNotifier {
  EnumMonominoTileDirection _direction = EnumMonominoTileDirection.empty;
  EnumMonominoTileDirection get direction => _direction;
  set direction(EnumMonominoTileDirection dir) {
    if (_direction == dir) return;
    _direction = dir;
    notifyListeners();
  }

  bool isObstacle; // 起點/終點或障礙
  bool isStartP;
  bool isGoalP;
  bool isHighlighted = false;
  bool isFixedArrow = false;

  ModelGameMonominoTile({
    EnumMonominoTileDirection direction = EnumMonominoTileDirection.empty,
    this.isObstacle = false,
    this.isStartP = false,
    this.isGoalP = false,
  }) : _direction = direction;
}

class _BFSNode {
  Point<int> point;
  Point<int>? lastDelta;
  int straightCount;

  _BFSNode(this.point, this.lastDelta, this.straightCount);
}

class ModelGameMonominoLevel {
  late Map<Point<int>, Point<int>?> parent;
  final int levelNumber;
  final int rows;
  final int cols;
  final Random _random;
  late List<List<ModelGameMonominoTile>> board;
  late List<EnumMonominoTileDirection> tilesToPlace;
  late Point<int> start;
  late Point<int> goal;
  late List<Point<int>> remainingFixed;
  List<Point<int>> solutionPath = [];
  Set<Point<int>> highlighted = {};

  ModelGameMonominoLevel({
    required this.levelNumber,
    required this.rows,
    required this.cols,
    Random? random,
  }) : _random = random ?? Random() {
    remainingFixed = [];
    _generateLevel();
  }

  List<Point<int>> getSolutionPath() => solutionPath;

  void _generateLevel() {
    board = List.generate(
      rows,
      (_) => List.generate(cols, (_) => ModelGameMonominoTile()),
    );
    start = Point(0, 0);
    goal = Point(rows - 1, cols - 1);
    parent = {};
    parent[start] = null;

    board[start.x][start.y].isStartP = true;
    board[goal.x][goal.y].isGoalP = true;

    final rnd = _random;

    // --- DFS 生成迷宮，避免直線通道 ---
    List<Point<int>> directions = [
      Point(0, 1), // 右
      Point(0, -1), // 左
      Point(1, 0), // 下
      Point(-1, 0), // 上
    ];

    List<Point<int>> stack = [start];
    Set<Point<int>> visited = {start};
    Point<int>? lastDelta;
    int straightCount = 0; // ⭐ 新增：連續直走計數

    while (stack.isNotEmpty) {
      Point<int> current = stack.last;
      List<Point<int>> neighbors = [];
      List<Point<int>> neighborDeltas = [];

      for (var delta in directions) {
        Point<int> n = Point(current.x + delta.x, current.y + delta.y);
        if (n.x >= 0 &&
            n.x < rows &&
            n.y >= 0 &&
            n.y < cols &&
            !visited.contains(n)) {
          neighbors.add(n);
          neighborDeltas.add(delta);
        }
      }

      if (neighbors.isEmpty) {
        stack.removeLast();
        lastDelta = null;
        straightCount = 0;
        continue;
      }

      // --- 分成直走 / 轉彎方向 ---
      List<int> turnChoices = [];
      List<int> straightChoices = [];

      for (int i = 0; i < neighborDeltas.length; i++) {
        if (lastDelta == null || neighborDeltas[i] != lastDelta) {
          turnChoices.add(i);
        } else {
          straightChoices.add(i);
        }
      }

      int idx;

      // ⭐⭐⭐ 強制轉彎條件：連續直走 >= n
      if (straightCount >= 4 && turnChoices.isNotEmpty) {
        idx = turnChoices[rnd.nextInt(turnChoices.length)];
      }
      // 其他安全保底
      else if (turnChoices.isEmpty && straightChoices.isEmpty) {
        idx = 0;
      } else if (straightChoices.isEmpty) {
        idx = turnChoices[rnd.nextInt(turnChoices.length)];
      } else if (turnChoices.isEmpty) {
        idx = straightChoices[rnd.nextInt(straightChoices.length)];
      }
      // 正常情況 → 70% 直走 + 10% 轉彎
      else {
        double r = rnd.nextDouble();
        if (r < 0.7) {
          idx = straightChoices[rnd.nextInt(straightChoices.length)];
        } else {
          idx = turnChoices[rnd.nextInt(turnChoices.length)];
        }
      }

      // 新節點
      Point<int> next = neighbors[idx];
      Point<int> delta = neighborDeltas[idx];

      // ⭐ 計數直走 / 轉彎
      if (lastDelta != null && delta == lastDelta) {
        straightCount++;
      } else {
        straightCount = 0;
      }

      lastDelta = delta;

      parent[next] = current;
      visited.add(next);
      stack.add(next);
    }

    // --- 計算路徑 ---
    solutionPath = _buildPathFromParent(goal);

    // --- 放置固定箭頭，隨機顯示 path 上部分答案 ---
    double revealRate = 0.3;
    int showCnt = 0;
    int maxNumber = max(parseIntValue(levelNumber * 0.8), 2);
    for (int i = 5; i < solutionPath.length - 1; i++) {
      Point<int> p1 = solutionPath[i];
      if (board[p1.x][p1.y].isStartP) {
        continue;
      } else if (rnd.nextDouble() < revealRate && showCnt < maxNumber) {
        ModelGameMonominoTile tile1 = board[p1.x][p1.y];
        tile1.isFixedArrow = true;
        remainingFixed.add(Point(p1.x, p1.y));
        i = i + 4;
        showCnt++;
      } else if (showCnt >= maxNumber) {
        i = solutionPath.length;
      }
    }

    // ⭐ 最後計算「經過所有固定箭頭」的最短合法路徑
    solutionPath = findShortestPathThroughFixedArrows(remainingFixed);

    // --- 設定玩家待放箭頭（排除固定箭頭） ---
    tilesToPlace = [];
    for (int i = 0; i < solutionPath.length - 1; i++) {
      Point<int> p1 = solutionPath[i];
      Point<int> p2 = solutionPath[i + 1];

      ModelGameMonominoTile tile1 = board[p1.x][p1.y];
      EnumMonominoTileDirection dir = _getDirection(p1, p2);
      if (!tile1.isFixedArrow) {
        // 1. 加入真正需要的方向
        tilesToPlace.add(dir);
        tile1.direction = EnumMonominoTileDirection.empty; // 玩家放置
      } else {
        tile1.direction = dir;
      }
    }

    tilesToPlace.shuffle(rnd);

    // --- 隨機增加迷惑障礙（死路） ---
    final solutionCells = solutionPath.toSet();
    int extraObstacles = (rows * cols * 20 ~/ 100);
    int attempts = 0;
    int placed = 0;

    while (placed < extraObstacles && attempts < extraObstacles * 5) {
      attempts++;
      int r = rnd.nextInt(rows);
      int c = rnd.nextInt(cols);

      ModelGameMonominoTile tile = board[r][c];
      Point<int> p = Point(r, c);
      if (!tile.isFixedArrow &&
          !tile.isStartP &&
          !tile.isGoalP &&
          !tile.isObstacle &&
          !solutionCells.contains(p)) {
        tile.isObstacle = true;
        placed++;
      }
    }
  }

  EnumMonominoTileDirection _getDirection(Point<int> from, Point<int> to) {
    if (to.x > from.x) return EnumMonominoTileDirection.down;
    if (to.x < from.x) return EnumMonominoTileDirection.up;
    if (to.y > from.y) return EnumMonominoTileDirection.right;
    return EnumMonominoTileDirection.left;
  }

  List<Point<int>> _buildPathFromParent(Point<int> goal) {
    List<Point<int>> path = [];
    Point<int>? current = goal;

    while (current != null) {
      path.add(current);
      current = parent[current];
    }
    return path.reversed.toList();
  }

  List<Point<int>> findShortestPathThroughFixedArrows(
    List<Point<int>> fixedPoints,
  ) {
    if (fixedPoints.isEmpty) return solutionPath;

    List<Point<int>> finalPath = [];
    Set<Point<int>> used = {}; // 用於避免重複走格子
    Point<int> current = start;

    List<Point<int>> pointsToVisit = [...fixedPoints, goal];

    for (Point<int> target in pointsToVisit) {
      List<Point<int>> segment = bfsShortestPath(current, target, used);

      if (segment.isEmpty) {
        // 找不到 → fallback 原 DFS 路徑
        return solutionPath;
      }

      if (finalPath.isEmpty) {
        finalPath.addAll(segment);
      } else {
        finalPath.addAll(segment.skip(1));
      }

      // 將這段路徑加入已使用格子
      used.addAll(segment);

      current = target;
    }

    return finalPath;
  }

  List<Point<int>> bfsShortestPath(
    Point<int> start,
    Point<int> goal,
    Set<Point<int>> used,
  ) {
    Queue<_BFSNode> queue = Queue();
    Map<Point<int>, Point<int>?> parent = {};
    queue.add(_BFSNode(start, null, 0));
    parent[start] = null;

    List<Point<int>> dirs = [
      Point(0, 1),
      Point(0, -1),
      Point(1, 0),
      Point(-1, 0),
    ];

    while (queue.isNotEmpty) {
      _BFSNode node = queue.removeFirst();
      Point<int> cur = node.point;

      if (cur == goal) {
        List<Point<int>> path = [];
        Point<int>? p = cur;
        while (p != null) {
          path.add(p);
          p = parent[p];
        }
        return path.reversed.toList();
      }

      for (var d in dirs) {
        Point<int> nxt = Point(cur.x + d.x, cur.y + d.y);

        if (nxt.x < 0 || nxt.x >= rows || nxt.y < 0 || nxt.y >= cols) continue;
        if (used.contains(nxt)) continue; // ⭐ 避免走已用格子
        if (board[nxt.x][nxt.y].isObstacle) continue;

        int newStraight = (node.lastDelta != null && node.lastDelta == d)
            ? node.straightCount + 1
            : 1;

        if (!parent.containsKey(nxt)) {
          parent[nxt] = cur;
          queue.add(_BFSNode(nxt, d, newStraight));
        }
      }
    }

    return []; // 無路徑
  }

  bool checkPath(List<Point<int>> newRemainingFixed) {
    int r = start.x;
    int c = start.y;
    Set<String> visited = {};

    while (true) {
      // 到達終點
      if (r == goal.x && c == goal.y) {
        return newRemainingFixed.isEmpty; // 必須經過所有固定箭頭
      }

      String key = "$r,$c";
      if (visited.contains(key)) return false; // 迴圈
      visited.add(key);

      ModelGameMonominoTile tile = board[r][c];

      // 如果是固定箭頭，從集合移除
      if (tile.isFixedArrow) {
        newRemainingFixed.remove(Point(r, c));
      }

      // 根據方向移動
      switch (tile.direction) {
        case EnumMonominoTileDirection.up:
          r--;
          break;
        case EnumMonominoTileDirection.down:
          r++;
          break;
        case EnumMonominoTileDirection.left:
          c--;
          break;
        case EnumMonominoTileDirection.right:
          c++;
          break;
        case EnumMonominoTileDirection.empty:
          return false; // 無箭頭就斷路
      }

      // 邊界檢查
      if (r < 0 || r >= rows || c < 0 || c >= cols) return false;
    }
  }

  void resetBoard() {
    for (var row in board) {
      for (var tile in row) {
        if (!tile.isObstacle && !tile.isFixedArrow) {
          tile.direction = EnumMonominoTileDirection.empty;
        }
      }
    }
  }

  void highlightPath(List<Point<int>> path) {
    for (final p in path) {
      board[p.x][p.y].isHighlighted = true;
    }
  }

  void clearHighlight() {
    for (var row in board) {
      for (var tile in row) {
        tile.isHighlighted = false;
      }
    }
  }
}

/// Owns placement rules, inventory and steps; no service or widget dependencies.
class ModelMonominoSession {
  final ModelGameMonominoLevel level;
  final List<EnumMonominoTileDirection> _remaining = [];
  final Map<EnumMonominoTileDirection, int> _counts = {};
  late final List<EnumMonominoTileDirection> remainingTiles =
      UnmodifiableListView(_remaining);
  late final Map<EnumMonominoTileDirection, int> remainingCounts =
      UnmodifiableMapView(_counts);
  int _usedSteps = 0;
  int get usedSteps => _usedSteps;
  int get completionScore =>
      ((level.tilesToPlace.length - _remaining.length) * 10 - _usedSteps * 5)
          .clamp(1, 9999);

  ModelMonominoSession(this.level) {
    reset();
  }

  void reset() {
    level.resetBoard();
    level.clearHighlight();
    _usedSteps = 0;
    _remaining
      ..clear()
      ..addAll(level.tilesToPlace);
    _counts.clear();
    for (final direction in _remaining) {
      _counts[direction] = (_counts[direction] ?? 0) + 1;
    }
  }

  bool _inside(int row, int col) =>
      row >= 0 && row < level.rows && col >= 0 && col < level.cols;

  void _returnTile(EnumMonominoTileDirection direction) {
    if (direction == EnumMonominoTileDirection.empty) return;
    _remaining.add(direction);
    _counts[direction] = (_counts[direction] ?? 0) + 1;
  }

  bool place(
    int row,
    int col,
    int? fromRow,
    int? fromCol,
    EnumMonominoTileDirection? direction,
  ) {
    if (!_inside(row, col) ||
        (fromRow == null) != (fromCol == null) ||
        (fromRow == row && fromCol == col)) {
      return false;
    }
    final target = level.board[row][col];
    if (target.isObstacle || target.isFixedArrow) return false;
    ModelGameMonominoTile? source;
    if (fromRow != null && fromCol != null) {
      if (!_inside(fromRow, fromCol)) return false;
      source = level.board[fromRow][fromCol];
      if (source.isObstacle ||
          source.isFixedArrow ||
          source.direction == EnumMonominoTileDirection.empty) {
        return false;
      }
      direction = source.direction;
    } else if (direction == null ||
        direction == EnumMonominoTileDirection.empty ||
        (_counts[direction] ?? 0) == 0) {
      return false;
    }
    _returnTile(target.direction);
    if (source == null) {
      _remaining.remove(direction);
      final remaining = _counts[direction]! - 1;
      if (remaining == 0) {
        _counts.remove(direction);
      } else {
        _counts[direction] = remaining;
      }
    } else {
      source.direction = EnumMonominoTileDirection.empty;
    }
    target.direction = direction;
    _usedSteps++;
    return true;
  }
}
