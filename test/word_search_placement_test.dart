import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/game/word_search/model_game_word_search.dart';

void main() {
  test('word placement always starts inside the valid range', () {
    const boardSize = 103;
    const wordLength = 100;
    final directions = [
      (row: 0, col: 1),
      (row: 1, col: 0),
      (row: 1, col: 1),
      (row: -1, col: 1),
    ];

    for (final direction in directions) {
      final random = Random(42);
      for (var attempt = 0; attempt < 100; attempt++) {
        final start = chooseWordPlacementStart(
          random: random,
          boardSize: boardSize,
          wordLength: wordLength,
          rowDirection: direction.row,
          columnDirection: direction.col,
        );
        final endRow = start.row + direction.row * (wordLength - 1);
        final endCol = start.col + direction.col * (wordLength - 1);

        expect(start.row, inInclusiveRange(0, boardSize - 1));
        expect(start.col, inInclusiveRange(0, boardSize - 1));
        expect(endRow, inInclusiveRange(0, boardSize - 1));
        expect(endCol, inInclusiveRange(0, boardSize - 1));
      }
    }
  });

  test('word placement rejects a word larger than the board', () {
    expect(
      () => chooseWordPlacementStart(
        random: Random(1),
        boardSize: 8,
        wordLength: 9,
        rowDirection: 0,
        columnDirection: 1,
      ),
      throwsArgumentError,
    );
  });
}
