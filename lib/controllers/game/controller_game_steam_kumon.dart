import 'dart:math';

import 'package:flutter/material.dart';
import 'package:life_pilot/models/game/model_game_steam_kumon.dart';
import 'package:life_pilot/services/game/service_game.dart';

class ControllerGameSteamKumon extends ChangeNotifier {
  final String userName;
  final ServiceGame service;
  final String gameId;
  final int gameLevel;
  late Level level;
  int score = 0;
  List<TileDirection> remainingTiles = [];

  ControllerGameSteamKumon(
      {required this.userName,
      required this.service,
      required this.gameId, // 初始化
      required this.gameLevel
  }) {
    // 初始化 level
    level = _generateLevel(gameLevel);
    startLevel();
  }

  // 根據 gameLevel 生成不同大小/難度的 Level
  Level _generateLevel(int levelNumber) {
    // 簡單規則：等級越高，行列數增加，積木數增加
    int baseSize = 4; // 最低關卡 4x4
    int size = baseSize + (levelNumber - 1); // e.g. level 1 -> 4x4, level 2 -> 5x5
    return Level(rows: size, cols: size);
  }

  void startLevel() {
    remainingTiles = List.from(level.tilesToPlace);
  }

  void resetLevel() {
    level.resetBoard();
    remainingTiles = List.from(level.tilesToPlace);
  }

  void placeTile(int row, int col, TileDirection? dir) {
    Tile tile = level.board[row][col];
  if (!tile.fixed) {
    // 如果原本有方向，回到 remainingTiles
    if (tile.direction != TileDirection.empty) {
      remainingTiles.add(tile.direction);
    }
    // 設新方向
    tile.direction = dir ?? TileDirection.empty;

    // 移除新的方向
    if (dir != null) remainingTiles.remove(dir);
  }
}

  Future<bool> checkPath(int usedSteps) async {
    bool ok = level.checkPath();
    if(ok){
      calculateScore(usedSteps);    
      await _saveScore(score, true);
    }
    return ok;
  }

  void calculateScore(int usedSteps) {
    // 正確放置積木數 * 10 - 使用步數
    int correctTiles = level.tilesToPlace.length - remainingTiles.length;
    score += (correctTiles * 10 - usedSteps).clamp(0, 9999); // 防止負分
  }

  void highlightPath(List<Point<int>> path) {
    level.highlightPath(path);
  }

  void clearHighlight() {
    level.clearHighlight();
  }

  // 寫入 PostgreSQL 範例
  Future<void> _saveScore(int score, bool isPass) async {
    await service.saveUserGameScore(
      newUserName: userName,
      newScore: score.toDouble(),
      newGameId: gameId, // 使用傳入的 gameId
      newIsPass: isPass,
    );
  }
}
