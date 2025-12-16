import 'package:life_pilot/models/game/model_game_puzzle_map.dart';
import 'package:life_pilot/services/game/service_game.dart';

class ControllerGamePuzzleMap {
  final String userName;
  final ServiceGame service;
  final String gameId;
  final int gameLevel;
  late int gridSize;
  int score = 0;
  late List<ModelGamePuzzlePiece> pieces;

  ControllerGamePuzzleMap(
      {required this.userName,
      required this.service,
      required this.gameId, // 初始化
      required this.gameLevel});

  void setGridSize(int inputSize) {
    gridSize = inputSize;
    pieces = List.generate(
      gridSize * gridSize,
      (i) => ModelGamePuzzlePiece(correctIndex: i, currentIndex: i),
    );

    pieces.shuffle();
    for (int i = 0; i < pieces.length; i++) {
      pieces[i].currentIndex = i;
    }
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
    score = gridSize * 10;
  }
}
