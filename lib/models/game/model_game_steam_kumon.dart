import 'dart:collection';
import 'dart:math';

enum TileDirection { up, down, left, right, empty }

class Tile {
  TileDirection direction;
  bool fixed; // 起點/終點或障礙
  bool isStart;
  bool isGoal;
  bool isHighlighted = false;
  bool isFixedArrow = false;

  Tile(
      {this.direction = TileDirection.empty,
      this.fixed = false,
      this.isStart = false,
      this.isGoal = false});
}

class Level {
  final int rows;
  final int cols;
  late List<List<Tile>> board;
  late List<TileDirection> tilesToPlace;
  late Point<int> start;
  late Point<int> goal;
  List<Point<int>> solutionPath = [];
  Set<Point<int>> highlighted = {};

  Level({required this.rows, required this.cols}) {
    _generateLevel();
  }

  void _generateLevel() {
    board = List.generate(rows, (_) => List.generate(cols, (_) => Tile()));
    start = Point(0, 0);
    goal = Point(rows - 1, cols - 1);

    // 初始化全部障礙
    for (var row in board) {
      for (var tile in row) {
        tile.fixed = true;
      }
    }

    board[start.x][start.y].fixed = false;
    board[start.x][start.y].isStart = true;
    board[goal.x][goal.y].fixed = true;
    board[goal.x][goal.y].isGoal = true;

    Random rnd = Random();

    // --- 使用 DFS 生成迷宮，避免直線通道 ---
    List<Point<int>> directions = [
      Point(0, 1), // 右
      Point(0, -1), // 左
      Point(1, 0), // 下
      Point(-1, 0), // 上
    ];

    List<Point<int>> stack = [start];
    Set<Point<int>> visited = {start};
    Point<int>? lastDelta;
    int straightCount = 0;

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
      } else {
        // 過濾長直線
        List<int> filteredIndices = [];
        for (int i = 0; i < neighborDeltas.length; i++) {
          if (lastDelta == null ||
              neighborDeltas[i] != lastDelta ||
              straightCount < 2) {
            filteredIndices.add(i);
          }
        }

        int idx = filteredIndices.isNotEmpty
            ? filteredIndices[rnd.nextInt(filteredIndices.length)]
            : rnd.nextInt(neighbors.length);
        Point<int> next = neighbors[idx];

        if (lastDelta != null && neighborDeltas[idx] == lastDelta) {
          straightCount++;
        } else {
          straightCount = 1;
        }

        lastDelta = neighborDeltas[idx];
        visited.add(next);
        board[next.x][next.y].fixed = false;
        stack.add(next);
      }
    }

    // --- 計算最短路徑 ---
    solutionPath = _findShortestPath(start, goal);

    // --- 放置固定箭頭 ---
    int arrowCount = max(solutionPath.length ~/ 12, 1);
    for (int i = 1;
        i < solutionPath.length - 1;
        i += (solutionPath.length ~/ arrowCount)) {
      Point<int> mustPass = solutionPath[i];
      Point<int> next = solutionPath[i + 1];
      TileDirection dir = _getDirection(mustPass, next);

      Tile tile = board[mustPass.x][mustPass.y];
      tile.direction = dir;
      tile.fixed = true;
      tile.isFixedArrow = true;
    }

    // --- 設定玩家待放箭頭（排除固定箭頭） ---
    tilesToPlace = [];
    for (int i = 0; i < solutionPath.length - 1; i++) {
      Point<int> p1 = solutionPath[i];
      Point<int> p2 = solutionPath[i + 1];

      Tile tile1 = board[p1.x][p1.y];
      if (tile1.fixed || tile1.isFixedArrow) continue;

      TileDirection dir = _getDirection(p1, p2);
      tilesToPlace.add(dir);
      Tile tile2 = board[p2.x][p2.y];
      if (!tile2.isFixedArrow && !tile2.fixed)
        tile2.direction = TileDirection.empty; // 玩家放置
    }

    tilesToPlace.shuffle();

    // --- 隨機增加迷惑障礙（死路） ---
    int extraObstacles = (rows * cols * 35 ~/ 100);
    for (int i = 0; i < extraObstacles; i++) {
      int r = rnd.nextInt(rows);
      int c = rnd.nextInt(cols);
      Point<int> p = Point(r, c);
      if (!solutionPath.contains(p) && !board[r][c].fixed) {
        board[r][c].fixed = true;
      }
    }
  }

  TileDirection _getDirection(Point<int> from, Point<int> to) {
    if (to.x > from.x) return TileDirection.down;
    if (to.x < from.x) return TileDirection.up;
    if (to.y > from.y) return TileDirection.right;
    return TileDirection.left;
  }

  // BFS 或 DFS 找最短路徑
  List<Point<int>> _findShortestPath(Point<int> start, Point<int> goal) {
    Queue<List<Map<String, dynamic>>> queue = Queue();
    Set<String> visited = {};

    // 每個節點記錄: {'pos': Point<int>, 'lastDir': TileDirection?}
    queue.add([
      {'pos': start, 'lastDir': null}
    ]);

    while (queue.isNotEmpty) {
      List<Map<String, dynamic>> path = queue.removeFirst();
      Point<int> current = path.last['pos'];
      TileDirection? lastDir = path.last['lastDir'];
      String key = "${current.x},${current.y},${lastDir ?? 'null'}";
      if (visited.contains(key)) continue;
      visited.add(key);

      if (current == goal) {
        return path.map((e) => e['pos'] as Point<int>).toList();
      }

      List<Map<String, dynamic>> neighbors = [
        {'delta': Point(0, 1), 'dir': TileDirection.right},
        {'delta': Point(0, -1), 'dir': TileDirection.left},
        {'delta': Point(1, 0), 'dir': TileDirection.down},
        {'delta': Point(-1, 0), 'dir': TileDirection.up},
      ];

      for (var n in neighbors) {
        Point<int> delta = n['delta'];
        TileDirection dir = n['dir'];
        Point<int> next = Point(current.x + delta.x, current.y + delta.y);

        if (next.x < 0 || next.x >= rows || next.y < 0 || next.y >= cols)
          continue;
        if (board[next.x][next.y].fixed) continue;

        // 禁止連續兩步方向相同
        if (lastDir != null && lastDir == dir) continue;

        queue.add([
          ...path,
          {'pos': next, 'lastDir': dir}
        ]);
      }
    }

    return [start, goal];
  }

  bool checkPath() {
    int r = start.x;
    int c = start.y;
    Set<String> visited = {};
    bool passedFixedArrow = false; // 是否經過固定箭頭

    while (true) {
      if (r == goal.x && c == goal.y) {
        return passedFixedArrow; // 到達終點且必須經過固定箭頭
      }
      String key = "$r,$c";
      if (visited.contains(key)) return false;
      visited.add(key);

      Tile tile = board[r][c];

      // 檢查是否是固定箭頭
      if (tile.fixed && tile.direction != TileDirection.empty) {
        passedFixedArrow = true;
      }

      // 根據方向移動
      switch (tile.direction) {
        case TileDirection.up:
          r--;
          break;
        case TileDirection.down:
          r++;
          break;
        case TileDirection.left:
          c--;
          break;
        case TileDirection.right:
          c++;
          break;
        case TileDirection.empty:
          return false; // 無箭頭就斷路
      }

      if (r < 0 || r >= rows || c < 0 || c >= cols) return false;
    }
  }

  void resetBoard() {
    for (var row in board) {
      for (var tile in row) {
        if (!tile.fixed) tile.direction = TileDirection.empty;
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
