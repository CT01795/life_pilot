import 'dart:collection';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:life_pilot/models/game/model_game_steam_polyomino.dart';
import 'package:life_pilot/services/game/service_game.dart';

class ControllerGameSteamPolyomino extends ChangeNotifier {
  final String userName;
  final ServiceGame service;
  final String gameId;
  final int gameLevel;
  late PolyominoLevelData levelData;
  late List<List<PolyominoTile>> grid;
  final List<PolyominoPipeBlock> placedBlocks = [];

  ControllerGameSteamPolyomino(
      {required this.userName,
      required this.service,
      required this.gameId, // 初始化
      required this.gameLevel,
      required PolyominoLevelData level}) {
    levelData = level;
    _initGrid();
    _markStartGoal();
  }

  void _initGrid() {
    grid = List.generate(
      levelData.rows,
      (_) => List.generate(levelData.cols, (_) => PolyominoTile()),
    );
  }

  void _markStartGoal() {
    // 設定 start/goal 類型
    final start = levelData.start;
    final goal = levelData.goal;
    grid[levelData.start.y][levelData.start.x].type = PolyominoTileType.start;
    grid[levelData.goal.y][levelData.goal.x].type = PolyominoTileType.goal;

    final path = levelData.path;
    final next = path[1];
    _setDir(grid[start.y][start.x], start, next);

    final prev = path[path.length - 2];
    _setDir(grid[goal.y][goal.x], goal, prev);
  }

  void _setDir(PolyominoTile tile, Point<int> cur, Point<int> target) {
    // 計算 start tile 的方向（只看下一格）
    tile.up = target.x == cur.x && target.y == cur.y - 1;
    tile.right = target.x == cur.x + 1 && target.y == cur.y;
    tile.down = target.x == cur.x && target.y == cur.y + 1;
    tile.left = target.x == cur.x - 1 && target.y == cur.y;
  }

  bool _inBounds(int x, int y) =>
      x >= 0 && x < levelData.cols && y >= 0 && y < levelData.rows;

  bool canPlaceBlock(PolyominoPipeBlock block, int gx, int gy) {
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
      if (tile.type == PolyominoTileType.start ||
          tile.type == PolyominoTileType.goal) {
        return false;
      }

      // 不能覆蓋其他方塊
      if (tile.type != PolyominoTileType.empty) return false;
    }
    return true;
  }

  bool placeBlock(PolyominoPipeBlock block, int gx, int gy) {
    bool isFind = false;
    // 曼哈頓距離優先搜尋
    // 原點可放 → 直接回
    if (canPlaceBlock(block, gx, gy)) {
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

          if (canPlaceBlock(block, tx, ty)) {
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

    block.originX = gx;
    block.originY = gy;

    for (int i = 0; i < block.cells.length; i++) {
      final c = block.cells[i];
      final nx = gx + c.x;
      final ny = gy + c.y;

      final tile = grid[ny][nx];
      tile.type = PolyominoTileType.pipe;
      tile.blockId = block.id;

      // ★ 修正 2：先清方向，避免殘留
      tile.up = tile.right = tile.down = tile.left = false;

      // 套入新方向
      tile.up = block.connections[i][0];
      tile.right = block.connections[i][1];
      tile.down = block.connections[i][2];
      tile.left = block.connections[i][3];
    }

    placedBlocks.add(block);
    return true;
  }

  void removeBlock(PolyominoPipeBlock block) {
    for (var c in block.cells) {
      final x = block.originX + c.x;
      final y = block.originY + c.y;
      final tile = grid[y][x];

      // ★ 修正 3：不能清除 start / goal
      if (tile.type == PolyominoTileType.start ||
          tile.type == PolyominoTileType.goal) {
        tile.blockId = null; // 移除 blockId 但保留方向
        continue;
      }

      tile.reset();
    }
    placedBlocks.remove(block);
  }

  Future<bool> isLevelComplete() async {
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

    // 2️⃣ 所有水管都要放完（不能留在 waiting）
    if (placedBlocks.length != levelData.availableBlocks.length) {
      return false;
    }

    await service.saveUserGameScore(
      newUserName: userName,
      newScore: levelData.availableBlocks.length * 10,
      newGameId: gameId, // 使用傳入的 gameId
      newIsPass: true,
    );
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
