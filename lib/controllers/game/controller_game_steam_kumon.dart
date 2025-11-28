import 'dart:math';

import 'package:flutter/material.dart';
import 'package:life_pilot/models/game/model_game_steam_kumon.dart';
import 'package:life_pilot/services/game/service_game.dart';

class ControllerGameSteamKumon extends ChangeNotifier {
  final String userName;
  final ServiceGame service;
  final String gameId;
  final int gameLevel;
  late List<Point<int>> remainingFixed;

  late Level level;
  int score = 0;
  int usedSteps = 0;
  List<TileDirection> remainingTiles = [];

  ControllerGameSteamKumon(
      {required this.userName,
      required this.service,
      required this.gameId, // 初始化
      required this.gameLevel}) {
    // 初始化 level
    level = _generateLevel(gameLevel);
    startLevel();
    remainingFixed = List.from(level.remainingFixed);
  }

  void startLevel() {
    remainingTiles = List.from(level.tilesToPlace);
    notifyListeners();
  }

  // 根據 gameLevel 生成不同大小/難度的 Level
  Level _generateLevel(int levelNumber) {
    // 簡單規則：等級越高，行列數增加，積木數增加
    int baseSize = 6; // 最低關卡 4x4
    int size =
        baseSize + (levelNumber - 1); // e.g. level 1 -> 4x4, level 2 -> 5x5
    return Level(levelNumber: levelNumber, rows: size, cols: size);
  }

  void resetLevel() {
    level.resetBoard();
    remainingFixed = List.from(level.remainingFixed);
    remainingTiles = List.from(level.tilesToPlace);
    usedSteps = 0;
    notifyListeners();
  }

  void placeTile(int row, int col, TileDirection? dir) {
    Tile tile = level.board[row][col];
    if (!tile.isObstacle && !tile.isFixedArrow) {
      // 如果原本有方向，回到 remainingTiles
      if (tile.direction != TileDirection.empty) {
        remainingTiles.add(tile.direction);
      }
      // 設新方向
      tile.direction = dir ?? TileDirection.empty;

      // 移除新的方向
      if (dir != null) remainingTiles.remove(dir);
      usedSteps++;
      notifyListeners();
    }
  }

  Future<bool> checkPath() async {
    bool ok = level.checkPath(remainingFixed);
    if (ok) {
      _calculateScore();
      await service.saveUserGameScore(
        newUserName: userName,
        newScore: score.toDouble(),
        newGameId: gameId, // 使用傳入的 gameId
        newIsPass: true,
      );
    }
    return ok;
  }

  void _calculateScore() {
    int correctTiles = level.tilesToPlace.length - remainingTiles.length;
    score += (correctTiles * 10 - usedSteps).clamp(0, 9999);
  }

  void showHint() {
    level.highlightPath(level.getSolutionPath());
    notifyListeners();
  }

  void clearHint() {
    level.clearHighlight();
    notifyListeners();
  }

  Map<TileDirection, int> getRemainingCount() {
    Map<TileDirection, int> counts = {};
    for (var dir in remainingTiles) {
      counts[dir] = (counts[dir] ?? 0) + 1;
    }
    return counts;
  }
}
