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