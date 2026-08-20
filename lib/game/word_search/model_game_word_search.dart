import 'dart:math';

class ModelGameWordSearch {
  final String questionId;
  final String question;
  bool? found;

  ModelGameWordSearch ({
    required this.questionId,
    required this.question,
    this.found,
  });
}

class LetterCell {
  final int row;
  final int col;
  final String letter;

  bool selected = false;
  bool correct = false;

  LetterCell({
    required this.row,
    required this.col,
    required this.letter,
  });
}

class WordSearchBoard {
  int size;
  late List<List<LetterCell>> grid;
  List<LetterCell> currentSelection = [];

  WordSearchBoard(this.size) {
    grid = List.generate(
      size,
      (r) => List.generate(
        size,
        (c) => LetterCell(row: r, col: c, letter: ''),
      ),
    );
  }

  void clearSelection() {
    for (final c in currentSelection) {
      c.selected = false;
    }
    currentSelection.clear();
  }
}

({int row, int col}) chooseWordPlacementStart({
  required Random random,
  required int boardSize,
  required int wordLength,
  required int rowDirection,
  required int columnDirection,
}) {
  if (boardSize <= 0 || wordLength < 0 || wordLength > boardSize) {
    throw ArgumentError('Word placement does not fit the board');
  }
  if (![-1, 0, 1].contains(rowDirection) ||
      ![-1, 0, 1].contains(columnDirection) ||
      (rowDirection == 0 && columnDirection == 0)) {
    throw ArgumentError('Word placement direction is invalid');
  }

  final placementLength = max(wordLength, 1);
  final minRow = rowDirection < 0 ? placementLength - 1 : 0;
  final maxRow = rowDirection > 0
      ? boardSize - placementLength
      : boardSize - 1;
  final minCol = columnDirection < 0 ? placementLength - 1 : 0;
  final maxCol = columnDirection > 0
      ? boardSize - placementLength
      : boardSize - 1;

  return (
    row: minRow + random.nextInt(maxRow - minRow + 1),
    col: minCol + random.nextInt(maxCol - minCol + 1),
  );
}
