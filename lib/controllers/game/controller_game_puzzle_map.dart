import 'package:life_pilot/models/game/model_game_puzzle_map.dart';

class ControllerGamePuzzleMap {
  final int gridSize;
  late List<ModelGamePuzzlePiece> pieces;

  ControllerGamePuzzleMap({required this.gridSize}) {
    pieces = List.generate(
      gridSize * gridSize,
      (i) => ModelGamePuzzlePiece(correctIndex: i, currentIndex: i),
    );

    pieces.shuffle();
    for (int i = 0; i < pieces.length; i++) {
      pieces[i].currentIndex = i;
    }
  }

  bool checkResult() {
    return pieces.every((p) => p.correctIndex == p.currentIndex);
  }
}