import 'package:life_pilot/models/game/model_game_puzzle_map.dart';
import 'package:life_pilot/services/game/service_game.dart';

class ControllerGamePuzzleMap {
  final String userName;
  final ServiceGame service;
  final String gameId;
  final int gameLevel;
  late int rows;
  late int cols;
  int score = 0;
  late List<ModelGamePuzzlePiece> pieces;

  ControllerGamePuzzleMap(
      {required this.userName,
      required this.service,
      required this.gameId, // 初始化
      required this.gameLevel});

  Map<String, int> setGridSize(
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
    return {
      "rows": rows,
      "cols": cols,
    };
  }

  Future<bool> checkResult() async {
    bool ok = pieces.every((p) => p.correctIndex == p.currentIndex);
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
    score = rows * cols * 10;
  }
}
