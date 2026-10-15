import 'dart:collection';
import 'dart:math';
import 'package:life_pilot/game/steam_polyomino/model_game_steam_polyomino.dart';

/// Owns placement, occupied cells and pipe connectivity; no persistence or UI.
class ModelPolyominoBoard {
  final ModelGamePolyominoLevelData levelData;
  late final List<List<ModelGamePolyominoTile>> grid;
  final List<ModelGamePolyominoPipeBlock> _placedBlocks = [];
  late final List<ModelGamePolyominoPipeBlock> placedBlocks =
      UnmodifiableListView(_placedBlocks);
  final Map<int, ModelGamePolyominoPipeBlock> _blocksById = {};
  final Map<int, List<Point<int>>> _occupiedCells = {};
  late final Set<int> _availableIds = levelData.availableBlocks
      .map((b) => b.id)
      .toSet();
  static const _directions = [
    Point(0, -1),
    Point(1, 0),
    Point(0, 1),
    Point(-1, 0),
  ];
  int _revision = 0;
  int get revision => _revision;
  ModelGamePolyominoPipeBlock? blockById(int id) => _blocksById[id];

  ModelPolyominoBoard(this.levelData) {
    if (levelData.rows <= 0 ||
        levelData.cols <= 0 ||
        levelData.path.length < 2 ||
        !_inBounds(levelData.start.x, levelData.start.y) ||
        !_inBounds(levelData.goal.x, levelData.goal.y) ||
        levelData.path.any((p) => !_inBounds(p.x, p.y)) ||
        _availableIds.length != levelData.availableBlocks.length) {
      throw ArgumentError('Invalid polyomino level');
    }
    _initGrid();
    _markStartGoal();
  }

  bool _validBlock(ModelGamePolyominoPipeBlock block) =>
      _availableIds.contains(block.id) &&
      !_blocksById.containsKey(block.id) &&
      block.cells.isNotEmpty &&
      block.cells.toSet().length == block.cells.length &&
      block.cells.every((c) => c.x >= 0 && c.y >= 0) &&
      block.connections.length == block.cells.length &&
      block.connections.every((c) => c.length == 4);

  void _initGrid() {
    grid = List.unmodifiable(
      List.generate(
        levelData.rows,
        (_) => List<ModelGamePolyominoTile>.unmodifiable(
          List.generate(levelData.cols, (_) => ModelGamePolyominoTile()),
        ),
      ),
    );
  }

  void _markStartGoal() {
    // 設定 start/goal 類型
    final start = levelData.start;
    final goal = levelData.goal;
    grid[levelData.start.y][levelData.start.x].type =
        EnumPolyominoTileType.start;
    grid[levelData.goal.y][levelData.goal.x].type = EnumPolyominoTileType.goal;

    final path = levelData.path;
    final next = path[1];
    _setDir(grid[start.y][start.x], start, next);

    final prev = path[path.length - 2];
    _setDir(grid[goal.y][goal.x], goal, prev);
  }

  void _setDir(ModelGamePolyominoTile tile, Point<int> cur, Point<int> target) {
    // 計算 start tile 的方向（只看下一格）
    tile.up = target.x == cur.x && target.y == cur.y - 1;
    tile.right = target.x == cur.x + 1 && target.y == cur.y;
    tile.down = target.x == cur.x && target.y == cur.y + 1;
    tile.left = target.x == cur.x - 1 && target.y == cur.y;
  }

  bool _inBounds(int x, int y) =>
      x >= 0 && x < levelData.cols && y >= 0 && y < levelData.rows;

  bool canPlaceBlock(ModelGamePolyominoPipeBlock block, int gx, int gy) {
    if (!_validBlock(block)) return false;
    return _canPlaceAt(block, gx, gy);
  }

  bool _canPlaceAt(ModelGamePolyominoPipeBlock block, int gx, int gy) {
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

      final tile = grid[ny][nx];

      // ★ 修正 1：禁止覆蓋 start / goal
      if (tile.type == EnumPolyominoTileType.start ||
          tile.type == EnumPolyominoTileType.goal) {
        return false;
      }

      // 不能覆蓋其他方塊
      if (tile.type != EnumPolyominoTileType.empty) return false;
    }
    return true;
  }

  bool placeBlock(ModelGamePolyominoPipeBlock block, int gx, int gy) {
    if (!_validBlock(block)) return false;
    bool isFind = false;
    // 曼哈頓距離優先搜尋
    // 原點可放 → 直接回
    if (_canPlaceAt(block, gx, gy)) {
      isFind = true;
    } else {
      for (int d = 1; d <= 3; d++) {
        List<Point<int>> candidates = [
          Point(gx, gy - d), // 上 d
          Point(gx - d, gy), // 左 d
          Point(gx - d, gy - d), // 左上
          Point(gx - d, gy - d - 1), // 上 d
          Point(gx - d - 1, gy - 1), // 左 d
        ];

        for (final p in candidates) {
          final tx = p.x;
          final ty = p.y;

          if (tx < 0 || ty < 0) {
            continue;
          }

          if (_canPlaceAt(block, tx, ty)) {
            gx = tx;
            gy = ty;
            isFind = true;
            break;
          }
        }
        if (isFind) {
          break;
        }
      }
    }
    if (!isFind) return false;

    _occupiedCells[block.id] = List.unmodifiable(
      block.cells.map((c) => Point(gx + c.x, gy + c.y)),
    );
    _blocksById[block.id] = block;
    block.originX = gx;
    block.originY = gy;

    for (int i = 0; i < block.cells.length; i++) {
      final c = block.cells[i];
      final nx = gx + c.x;
      final ny = gy + c.y;

      final tile = grid[ny][nx];
      tile.type = EnumPolyominoTileType.pipe;
      tile.blockId = block.id;

      // ★ 修正 2：先清方向，避免殘留
      tile.up = tile.right = tile.down = tile.left = false;

      // 套入新方向
      tile.up = block.connections[i][0];
      tile.right = block.connections[i][1];
      tile.down = block.connections[i][2];
      tile.left = block.connections[i][3];
    }

    _placedBlocks.add(block);
    _revision++;
    return true;
  }

  bool removeBlock(ModelGamePolyominoPipeBlock block) {
    if (!identical(_blocksById[block.id], block)) return false;
    for (final cell in _occupiedCells.remove(block.id)!) {
      final tile = grid[cell.y][cell.x];
      if (tile.type == EnumPolyominoTileType.pipe && tile.blockId == block.id) {
        tile.reset();
      }
    }
    _blocksById.remove(block.id);
    _placedBlocks.remove(block);
    _revision++;
    return true;
  }

  bool get isComplete {
    if (_placedBlocks.length != levelData.availableBlocks.length) return false;
    final visited = List.generate(
      levelData.rows,
      (_) => List.filled(levelData.cols, false),
    );
    final queue = Queue<Point<int>>()..add(levelData.start);
    visited[levelData.start.y][levelData.start.x] = true;
    while (queue.isNotEmpty) {
      final point = queue.removeFirst();
      if (point == levelData.goal) return true;
      final tile = grid[point.y][point.x];
      for (var i = 0; i < _directions.length; i++) {
        final d = _directions[i];
        final nx = point.x + d.x, ny = point.y + d.y;
        if (!_inBounds(nx, ny) || visited[ny][nx]) continue;
        final next = grid[ny][nx];
        final connected = switch (i) {
          0 => tile.up && next.down,
          1 => tile.right && next.left,
          2 => tile.down && next.up,
          _ => tile.left && next.right,
        };
        if (connected) {
          visited[ny][nx] = true;
          queue.add(Point(nx, ny));
        }
      }
    }
    return false;
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
