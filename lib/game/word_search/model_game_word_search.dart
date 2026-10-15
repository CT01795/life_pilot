import 'dart:math';
import 'dart:collection';

class ModelGameWordSearch {
  final String questionId;
  final String question;
  String get searchWord => question.replaceAll(' ', '');
  bool? found;

  ModelGameWordSearch({
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

  LetterCell({required this.row, required this.col, required this.letter});
}

class WordSearchBoard {
  int _size;
  int get size => _size;
  late List<List<LetterCell>> _grid;
  List<List<LetterCell>> get grid => _grid;
  final List<LetterCell> _selection = [];
  late final List<LetterCell> currentSelection = UnmodifiableListView(
    _selection,
  );
  List<int>? _currentDirection;
  static const directions = [
    [0, 1],
    [1, 0],
    [1, 1],
    [-1, 1],
  ];

  WordSearchBoard(int size) : _size = size {
    if (size <= 0) throw ArgumentError.value(size, 'size');
    _grid = _createGrid(size);
  }

  static List<List<LetterCell>> _createGrid(int size) => List.unmodifiable(
    List.generate(
      size,
      (r) => List<LetterCell>.unmodifiable(
        List.generate(size, (c) => LetterCell(row: r, col: c, letter: '')),
      ),
    ),
  );

  void generate(String question, {Random? random}) {
    final word = question.replaceAll(' ', '');
    final generator = random ?? Random();
    final newSize = max(word.length + 3, 8);
    final letters = <int, String>{};
    final direction = directions[generator.nextInt(directions.length)];
    final start = chooseWordPlacementStart(
      random: generator,
      boardSize: newSize,
      wordLength: word.length,
      rowDirection: direction[0],
      columnDirection: direction[1],
    );
    for (var i = 0; i < word.length; i++) {
      final row = start.row + direction[0] * i;
      final col = start.col + direction[1] * i;
      letters[row * newSize + col] = word[i];
    }
    const alphabet = 'abcdefghijklmnopqrstuvwxyz';
    final nextGrid = List<List<LetterCell>>.unmodifiable(
      List.generate(
        newSize,
        (r) => List<LetterCell>.unmodifiable(
          List.generate(
            newSize,
            (c) => LetterCell(
              row: r,
              col: c,
              letter:
                  letters[r * newSize + c] ?? alphabet[generator.nextInt(26)],
            ),
          ),
        ),
      ),
    );
    clearSelection();
    _size = newSize;
    _grid = nextGrid;
  }

  String get selectedWord => _selection.map((cell) => cell.letter).join();

  /// Ignores stale/foreign cells; a non-straight move starts a new selection.
  bool select(LetterCell cell) {
    if (cell.row < 0 ||
        cell.row >= size ||
        cell.col < 0 ||
        cell.col >= size ||
        !identical(_grid[cell.row][cell.col], cell) ||
        (_selection.isNotEmpty && identical(_selection.last, cell))) {
      return false;
    }
    if (_selection.isNotEmpty) {
      final last = _selection.last;
      final dr = cell.row - last.row;
      final dc = cell.col - last.col;
      final direction = [dr.sign, dc.sign];
      final adjacent =
          dr.abs() <= 1 &&
          dc.abs() <= 1 &&
          directions.any((d) => d[0] == direction[0] && d[1] == direction[1]);
      final straight =
          _currentDirection == null ||
          (_currentDirection![0] == direction[0] &&
              _currentDirection![1] == direction[1]);
      if (!adjacent || !straight) {
        clearSelection();
      } else {
        _currentDirection ??= direction;
      }
    }
    cell.selected = true;
    _selection.add(cell);
    return true;
  }

  void completeSelection({required bool correct}) {
    if (correct) {
      for (final cell in _selection) {
        cell.correct = true;
      }
    }
    clearSelection();
  }

  void clearSelection() {
    for (final c in _selection) {
      c.selected = false;
    }
    _selection.clear();
    _currentDirection = null;
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
  final maxRow = rowDirection > 0 ? boardSize - placementLength : boardSize - 1;
  final minCol = columnDirection < 0 ? placementLength - 1 : 0;
  final maxCol = columnDirection > 0
      ? boardSize - placementLength
      : boardSize - 1;

  return (
    row: minRow + random.nextInt(maxRow - minRow + 1),
    col: minCol + random.nextInt(maxCol - minCol + 1),
  );
}
