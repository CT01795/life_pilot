// 拼圖 Piece 模型
class ModelGamePuzzleMap {
  final String assetPath;
  ModelGamePuzzleMap({required this.assetPath});
}

class ModelGamePuzzlePiece {
  int correctIndex;
  int currentIndex;
  ModelGamePuzzlePiece({required this.correctIndex, required this.currentIndex});
}