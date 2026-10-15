import 'dart:math';

// 拼圖 Piece 模型
class ModelGamePuzzleMap {
  final String assetPath;
  ModelGamePuzzleMap({required this.assetPath});
}

class ModelGamePuzzlePiece {
  final int correctIndex;
  int currentIndex;
  ModelGamePuzzlePiece({
    required this.correctIndex,
    required this.currentIndex,
  });
}

/// Logical grid and movement rules, independent of widgets and services.
class ModelPuzzleBoard {
  final int rows;
  final int cols;
  final List<ModelGamePuzzlePiece> pieces;
  final List<ModelGamePuzzlePiece> _byCorrectIndex;

  ModelPuzzleBoard._(this.rows, this.cols, this.pieces, this._byCorrectIndex);

  factory ModelPuzzleBoard.fromImage(
    int width,
    int height,
    int shortSideCount, {
    Random? random,
  }) {
    if (width <= 0 || height <= 0 || shortSideCount <= 0) {
      throw ArgumentError('Image dimensions and grid count must be positive');
    }
    final tileSize = min(width, height) / shortSideCount;
    var rows = width > height ? shortSideCount : (height / tileSize).round();
    var cols = width > height ? (width / tileSize).round() : shortSideCount;
    if (rows * cols < 10) {
      rows++;
      cols++;
    }
    final byId = List.generate(
      rows * cols,
      (i) => ModelGamePuzzlePiece(correctIndex: i, currentIndex: i),
    );
    final shuffled = [...byId]..shuffle(random);
    for (var i = 0; i < shuffled.length; i++) {
      shuffled[i].currentIndex = i;
    }
    return ModelPuzzleBoard._(
      rows,
      cols,
      List.unmodifiable(shuffled),
      List.unmodifiable(byId),
    );
  }

  bool contains(ModelGamePuzzlePiece piece) =>
      piece.correctIndex >= 0 &&
      piece.correctIndex < _byCorrectIndex.length &&
      identical(_byCorrectIndex[piece.correctIndex], piece) &&
      piece.currentIndex >= 0 &&
      piece.currentIndex < pieces.length;
  bool canMove(ModelGamePuzzlePiece piece) =>
      contains(piece) && piece.currentIndex != piece.correctIndex;
  bool get isSolved => pieces.every((p) => p.correctIndex == p.currentIndex);
  int get completionScore => rows * cols * 10;

  /// Retains the original horizontal 15% finger margin and edge clamping.
  bool moveBy(
    ModelGamePuzzlePiece piece, {
    required double dx,
    required double dy,
    required double tileWidth,
    required double tileHeight,
  }) {
    if (!canMove(piece) ||
        !dx.isFinite ||
        !dy.isFinite ||
        !tileWidth.isFinite ||
        !tileHeight.isFinite ||
        tileWidth <= 0 ||
        tileHeight <= 0) {
      return false;
    }
    final col = piece.currentIndex % cols;
    final row = piece.currentIndex ~/ cols;
    final newCol = ((col * tileWidth + dx + tileWidth * 0.15) / tileWidth)
        .floor()
        .clamp(0, cols - 1);
    final newRow = ((row * tileHeight + dy) / tileHeight).floor().clamp(
      0,
      rows - 1,
    );
    return moveTo(piece, newRow * cols + newCol);
  }

  bool moveTo(ModelGamePuzzlePiece piece, int index) {
    if (!canMove(piece) ||
        index < 0 ||
        index >= pieces.length ||
        index == piece.currentIndex) {
      return false;
    }
    ModelGamePuzzlePiece? target;
    for (final candidate in pieces) {
      if (candidate.currentIndex == index) {
        target = candidate;
        break;
      }
    }
    if (target == null || target.currentIndex == target.correctIndex) {
      return false;
    }
    target.currentIndex = piece.currentIndex;
    piece.currentIndex = index;
    return true;
  }
}
