import 'dart:collection';
import 'dart:math';

import 'package:life_pilot/models/game/model_game_steam_polyomino.dart';

class GameController {
  late LevelData levelData;
  late List<List<Tile>> grid;
  final List<PipeBlock> placedBlocks = [];

  GameController({required LevelData level}) {
    levelData = level;
    _initGrid();
    _markStartGoal();
  }

  void _initGrid() {
    grid = List.generate(
      levelData.rows,
      (_) => List.generate(levelData.cols, (_) => Tile()),
    );
  }

  void _markStartGoal() {
    // 設定 start/goal 類型
    final start = levelData.start;
    final goal = levelData.goal;
    grid[levelData.start.y][levelData.start.x].type = TileType.start;
    grid[levelData.goal.y][levelData.goal.x].type = TileType.goal;

    final path = levelData.path;
    final next = path[1];
    _setDir(grid[start.y][start.x], start, next);

    final prev = path[path.length - 2];
    _setDir(grid[goal.y][goal.x], goal, prev);
  }

  void _setDir(Tile tile, Point<int> cur, Point<int> target) {
    // 計算 start tile 的方向（只看下一格）
    tile.up = target.x == cur.x && target.y == cur.y - 1;
    tile.right = target.x == cur.x + 1 && target.y == cur.y;
    tile.down = target.x == cur.x && target.y == cur.y + 1;
    tile.left = target.x == cur.x - 1 && target.y == cur.y;
  }

  bool _inBounds(int x, int y) =>
      x >= 0 && x < levelData.cols && y >= 0 && y < levelData.rows;

  bool canPlaceBlock(PipeBlock block, int gx, int gy) {
    if (gx < 0 ||
        gy < 0 ||
        gx + block.width > levelData.cols ||
        gy + block.height > levelData.rows) {
      return false;
    }
    for (var c in block.cells) {
      int nx = gx + c.x;
      int ny = gy + c.y;
      if (!_inBounds(nx, ny)) return false;
      if (grid[ny][nx].type != TileType.empty) return false;
    }
    return true;
  }

  bool placeBlock(PipeBlock block, int gx, int gy) {
    if (!canPlaceBlock(block, gx, gy)) return false;

    block.originX = gx;
    block.originY = gy;

    for (int i = 0; i < block.cells.length; i++) {
      final c = block.cells[i];
      final nx = gx + c.x;
      final ny = gy + c.y;

      final tile = grid[ny][nx];
      tile.type = TileType.pipe;
      tile.blockId = block.id;

      tile.up = block.connections[i][0];
      tile.right = block.connections[i][1];
      tile.down = block.connections[i][2];
      tile.left = block.connections[i][3];
    }

    placedBlocks.add(block);
    return true;
  }

  void removeBlock(PipeBlock block) {
    for (var c in block.cells) {
      grid[block.originY + c.y][block.originX + c.x].reset();
    }
    placedBlocks.remove(block);
  }

  bool isLevelComplete() {
    final visited = List.generate(
        levelData.rows, (_) => List.filled(levelData.cols, false));

    final q = Queue<Point<int>>();
    q.add(levelData.start);

    while (q.isNotEmpty) {
      final p = q.removeFirst();
      if (visited[p.y][p.x]) continue;
      visited[p.y][p.x] = true;

      final dirs = [
        const Point(0, -1),
        const Point(1, 0),
        const Point(0, 1),
        const Point(-1, 0),
      ];

      final t = grid[p.y][p.x];

      for (int i = 0; i < 4; i++) {
        final d = dirs[i];
        final nx = p.x + d.x;
        final ny = p.y + d.y;

        if (!_inBounds(nx, ny)) continue;
        final nt = grid[ny][nx];

        bool ok = false;
        if (i == 0) ok = t.up && nt.down;
        if (i == 1) ok = t.right && nt.left;
        if (i == 2) ok = t.down && nt.up;
        if (i == 3) ok = t.left && nt.right;

        if (ok) q.add(Point(nx, ny));
      }
    }

    if (!visited[levelData.goal.y][levelData.goal.x]) {
      return false; // 無法到達終點
    }

    // 2️⃣ 待用水管都要用完
    for (final block in levelData.availableBlocks) {
      if (block.originX == -1 || block.originY == -1) {
        return false; // 還有水管沒放
      }
    }

    return true; // 到達終點且待用水管全部放完
  }

  void highlightHint() {
    clearHint();

    final path = levelData.path;

    for (int i = 1; i < path.length - 1; i++) {
      final cur = path[i];
      final prev = path[i - 1];
      final next = path[i + 1];

      final tile = grid[cur.y][cur.x];
      tile.highlight = true;
      tile.hintDirs = [
        prev.y == cur.y - 1 || next.y == cur.y - 1, // up
        prev.x == cur.x + 1 || next.x == cur.x + 1, // right
        prev.y == cur.y + 1 || next.y == cur.y + 1, // down
        prev.x == cur.x - 1 || next.x == cur.x - 1, // left
      ];
    }
  }

  void clearHint() {
    for (var row in grid) {
      for (var t in row) {
        t.clearHint();
      }
    }
  }
}
