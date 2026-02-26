import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:life_pilot/game/puzzle_map/model_game_puzzle_map.dart';
import 'package:life_pilot/game/service_game.dart';

class ControllerGamePuzzleMap extends ChangeNotifier {
  final String userName;
  final ServiceGame service;
  final String gameId;
  final int gameLevel;
  late int rows;
  late int cols;
  int score = 0;
  late List<ModelGamePuzzlePiece> pieces;
  final Map<int, Offset> dragOffsets = {};
  bool _scoreSaved = false;
  DateTime _lastNotify = DateTime.now();

  ControllerGamePuzzleMap(
      {required this.userName,
      required this.service,
      required this.gameId, // 初始化
      required this.gameLevel});

  int get rowsCount => rows;
  int get colsCount => cols;

  void setGridSize(
      int imgWidth, int imgHeight, int shortSideCount) {
    double tileSize;
    if (imgWidth > imgHeight) {
      // 高是短邊
      tileSize = imgHeight / shortSideCount;
      rows = shortSideCount; // 垂直
      cols = (imgWidth / tileSize).round(); // 水平
    } else {
      // 寬是短邊
      tileSize = imgWidth / shortSideCount;
      cols = shortSideCount; // 水平
      rows = (imgHeight / tileSize).round(); // 垂直
    }

    if (rows * cols < 10) {
      cols = cols + 1;
      rows = rows + 1;
    }

    pieces = List.generate(
      rows * cols,
      (i) => ModelGamePuzzlePiece(correctIndex: i, currentIndex: i),
    );

    pieces.shuffle();
    for (int i = 0; i < pieces.length; i++) {
      pieces[i].currentIndex = i;
    }

    dragOffsets.clear(); // 清掉舊的拖動偏移
    notifyListeners();
  }

  Future<bool> checkResult() async {
    bool ok = pieces.every((p) => p.correctIndex == p.currentIndex);
    if (ok && !_scoreSaved) {
      _calculateScore();
      await service.saveUserGameScore(
        newUserName: userName,
        newScore: score.toDouble(),
        newGameId: gameId, // 使用傳入的 gameId
        newIsPass: true,
      );
      _scoreSaved = true;
    }
    return ok;
  }

  void _calculateScore() {
    score = rows * cols * 10;
  }

  void updateDrag(ModelGamePuzzlePiece piece, Offset delta) {
    if(piece.currentIndex == piece.correctIndex) return;
    dragOffsets[piece.currentIndex] =
        (dragOffsets[piece.currentIndex] ?? Offset.zero) + delta;
    if (DateTime.now().difference(_lastNotify).inMilliseconds > 16) { //notifyListeners 節流
      _lastNotify = DateTime.now();
      notifyListeners();
    }
  }

  void endDrag(
    ModelGamePuzzlePiece piece,
    double tileWidth,
    double tileHeight,
  ) {
    if(piece.currentIndex == piece.correctIndex) return;
    final totalOffset = dragOffsets[piece.currentIndex] ?? Offset.zero;
    _moveGroup([piece], totalOffset, tileWidth, tileHeight);
    notifyListeners();
  }

  void _moveGroup(List<ModelGamePuzzlePiece> group, Offset totalOffset,
      double tileWidth, double tileHeight) {
    if (group.isEmpty) return;

    final newIndices = <ModelGamePuzzlePiece, int>{};

    for (var p in group) {
      final col = p.currentIndex % cols;
      final row = p.currentIndex ~/ cols;

      final newCol = ((col * tileWidth + totalOffset.dx + tileWidth * 0.15) /
              tileWidth) //給手指 15% 的安全邊距
          .floor()
          .clamp(0, cols - 1);
      final newRow = ((row * tileHeight + totalOffset.dy) / tileHeight)
          .floor()
          .clamp(0, rows - 1);

      newIndices[p] = newRow * cols + newCol;
    }

    // 群組內 newIndex 不可重複
    final indexSet = <int>{};
    for (final index in newIndices.values) {
      if (!indexSet.add(index)) {
        _resetDragOffsets(group);
        return;
      }
    }

    final positionMap = {for (var p in pieces) p.currentIndex: p};

    // 撞到正確拼圖 → 整組取消
    for (var entry in newIndices.entries) {
      final target = positionMap[entry.value];
      if (target != null &&
          !group.contains(target) &&
          target.currentIndex == target.correctIndex &&
          entry.value != entry.key.currentIndex) {
        //✔ 真的要移到別人的格子 → 擋 ✔ 只是貼邊、沒換 index → 放行
        _resetDragOffsets(group);
        return;
      }
    }

    final finalIndices = <ModelGamePuzzlePiece, int>{};

    for (var entry in newIndices.entries) {
      final p = entry.key;
      final newIndex = entry.value;
      final target = positionMap[newIndex];

      if (target != null && !group.contains(target)) {
        finalIndices[target] = p.currentIndex;
      }

      finalIndices[p] = newIndex;
    }

    finalIndices.forEach((piece, index) {
      piece.currentIndex = index;
      dragOffsets[index] = Offset.zero;
    });
  }

  void _resetDragOffsets(List<ModelGamePuzzlePiece> group) {
    for (var p in group) {
      dragOffsets[p.currentIndex] = Offset.zero;
    }
  }
}
