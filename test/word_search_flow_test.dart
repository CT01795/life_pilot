import 'dart:async';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/game/service_game.dart';
import 'package:life_pilot/game/service_game_speech.dart';
import 'package:life_pilot/game/word_search/controller_game_word_search.dart';
import 'package:life_pilot/game/word_search/model_game_word_search.dart';

List<LetterCell> findWord(WordSearchBoard board, String word) {
  for (final row in board.grid) {
    for (final start in row) {
      for (final direction in WordSearchBoard.directions) {
        final cells = <LetterCell>[];
        for (var i = 0; i < word.length; i++) {
          final r = start.row + direction[0] * i;
          final c = start.col + direction[1] * i;
          if (r < 0 || r >= board.size || c < 0 || c >= board.size) break;
          cells.add(board.grid[r][c]);
        }
        if (cells.map((c) => c.letter).join() == word) return cells;
      }
    }
  }
  throw StateError('word missing');
}

class Speech extends ServiceGameSpeech {
  final texts = <String>[];
  int disposals = 0;
  @override
  Future<void> speakEnglish(String text) async {
    texts.add(text);
  }

  @override
  Future<void> dispose() async {
    disposals++;
  }
}

class Service extends ServiceGame {
  int loads = 0;
  int saves = 0;
  bool fail = false;
  Completer<ModelGameWordSearch>? pending;
  final submissions = <(String, String, bool)>[];
  @override
  Future<ModelGameWordSearch> fetchWordSearchQuestion(
    String userName,
    int level, {
    String questionBank = 'admin',
  }) async {
    loads++;
    if (fail) throw StateError('offline');
    return pending == null
        ? ModelGameWordSearch(questionId: 'q', question: 'hello world')
        : pending!.future;
  }

  @override
  Future<void> submitWordSearchAnswer({
    required String userName,
    required String questionId,
    required String answer,
    required bool isRightAnswer,
  }) async {
    submissions.add((questionId, answer, isRightAnswer));
  }

  @override
  Future<void> saveUserGameScore({
    required String newUserName,
    required double newScore,
    required String? newGameId,
    bool? newIsPass,
  }) async {
    saves++;
  }
}

void main() {
  group('word search board model', () {
    test(
      'generated words fit and all cells are filled across random seeds',
      () {
        for (var seed = 0; seed < 100; seed++) {
          final board = WordSearchBoard(8)
            ..generate('hello world', random: Random(seed));
          expect(board.size, 13);
          expect(findWord(board, 'helloworld').length, 10);
          expect(
            board.grid.expand((r) => r).every((c) => c.letter.isNotEmpty),
            true,
          );
        }
      },
    );
    test('same random seed produces same board', () {
      final a = WordSearchBoard(8)..generate('cat', random: Random(1));
      final b = WordSearchBoard(8)..generate('cat', random: Random(1));
      expect(
        a.grid.map((r) => r.map((c) => c.letter).join()),
        b.grid.map((r) => r.map((c) => c.letter).join()),
      );
    });
    test('grid rows and selection cannot be modified externally', () {
      final board = WordSearchBoard(8);
      expect(() => board.grid.clear(), throwsUnsupportedError);
      expect(() => board.grid.first.clear(), throwsUnsupportedError);
      expect(() => board.currentSelection.clear(), throwsUnsupportedError);
    });
    test('all original four directions can be selected', () {
      for (final direction in WordSearchBoard.directions) {
        final board = WordSearchBoard(8);
        for (var i = 0; i < 3; i++) {
          expect(
            board.select(
              board.grid[3 + direction[0] * i][1 + direction[1] * i],
            ),
            true,
          );
        }
        expect(board.currentSelection.length, 3);
      }
    });
    test('direction change and gaps restart selection', () {
      final board = WordSearchBoard(8);
      board.select(board.grid[0][0]);
      board.select(board.grid[0][1]);
      board.select(board.grid[1][1]);
      expect(board.currentSelection, [board.grid[1][1]]);
      expect(board.grid[0][0].selected, false);
      board.select(board.grid[6][6]);
      expect(board.currentSelection, [board.grid[6][6]]);
      board.clearSelection();
      board.select(board.grid[0][0]);
      board.select(board.grid[0][1]);
      board.select(board.grid[0][0]);
      expect(board.currentSelection, [board.grid[0][0]]);
      expect(board.grid[0][1].selected, false);
    });
    test('duplicate stale foreign and out-of-range cells are ignored', () {
      final board = WordSearchBoard(8);
      final stale = board.grid[0][0];
      expect(board.select(stale), true);
      expect(board.select(stale), false);
      board.generate('cat', random: Random(1));
      expect(board.select(stale), false);
      expect(board.select(LetterCell(row: 0, col: 0, letter: 'x')), false);
      expect(board.select(LetterCell(row: -1, col: 0, letter: 'x')), false);
      expect(board.currentSelection, isEmpty);
    });
    test('wrong selection is cleared without marking correct', () {
      final board = WordSearchBoard(8);
      final cell = board.grid[0][0];
      board.select(cell);
      board.completeSelection(correct: false);
      expect(cell.selected, false);
      expect(cell.correct, false);
      expect(board.currentSelection, isEmpty);
    });
    test('correct selection stays marked until a new board is generated', () {
      final board = WordSearchBoard(8)..generate('cat', random: Random(1));
      final cells = findWord(board, 'cat');
      for (final cell in cells) {
        board.select(cell);
      }
      expect(board.selectedWord, 'cat');
      board.completeSelection(correct: true);
      expect(cells.every((c) => c.correct && !c.selected), true);
      board.generate('cat', random: Random(1));
      expect(board.grid.expand((r) => r).any((c) => c.correct), false);
    });
    test('invalid board sizes are rejected', () {
      expect(() => WordSearchBoard(0), throwsArgumentError);
    });
  });

  late Service service;
  late Speech speech;
  late ControllerGameWordSearch controller;
  setUp(() {
    service = Service();
    speech = Speech();
    controller = ControllerGameWordSearch(
      userName: 'user',
      service: service,
      gameId: 'game',
      gameLevel: 1,
      maxQuestions: 10,
      board: WordSearchBoard(8),
      currentQuestion: ModelGameWordSearch(questionId: '', question: ''),
      speech: speech,
    );
  });
  tearDown(() {
    if (!controller.notifierDisposed) controller.dispose();
  });
  test(
    'cannot answer placeholder question or submit empty selection',
    () async {
      controller.answer('');
      controller.submitSelection();
      expect(controller.answeredCount, 0);
      await controller.loadNextQuestion();
      controller.submitSelection();
      expect(controller.answeredCount, 0);
    },
  );
  test('load notifies only loading and ready states and plays once', () async {
    var notifications = 0;
    controller.addListener(() => notifications++);
    await controller.loadNextQuestion();
    expect(notifications, 2);
    expect(controller.canAnswer, true);
    expect(speech.texts, ['hello world']);
  });
  test('pending load blocks selection answers and duplicate loads', () async {
    service.pending = Completer();
    final pending = controller.loadNextQuestion();
    controller.onSelectCell(controller.board.grid[0][0]);
    controller.answer('helloworld');
    await controller.loadNextQuestion();
    expect(service.loads, 1);
    expect(controller.answeredCount, 0);
    service.pending!.complete(
      ModelGameWordSearch(questionId: 'q', question: 'cat'),
    );
    await pending;
  });
  test(
    'correct selection updates board and score before a single notification',
    () async {
      await controller.loadNextQuestion();
      final cells = findWord(controller.board, 'helloworld');
      for (final cell in cells) {
        controller.onSelectCell(cell);
      }
      var notifications = 0;
      controller.addListener(() {
        notifications++;
        expect(controller.board.currentSelection, isEmpty);
        expect(cells.every((c) => c.correct), true);
        expect(controller.score, 4);
      });
      controller.submitSelection();
      controller.submitSelection();
      expect(notifications, 1);
      expect(service.submissions, [('q', 'hello world', true)]);
    },
  );
  test('wrong selection preserves penalty without green cells', () async {
    await controller.loadNextQuestion();
    final cell = controller.board.grid[0][0];
    controller.onSelectCell(cell);
    controller.submitSelection();
    expect(controller.score, -4);
    expect(controller.scoreMinus, -4);
    expect(controller.showCorrectAnswer, true);
    expect(cell.correct, false);
  });
  test('late load after disposal cannot replace question or board', () async {
    service.pending = Completer();
    final pending = controller.loadNextQuestion();
    controller.dispose();
    service.pending!.complete(
      ModelGameWordSearch(questionId: 'late', question: 'cat'),
    );
    await pending;
    controller.answer('cat');
    expect(controller.currentQuestion.questionId, '');
    expect(controller.board.size, 8);
    expect(controller.answeredCount, 0);
    expect(speech.texts, isEmpty);
    expect(speech.disposals, 1);
  });
  test(
    'load failure blocks stale board and retry restores interaction',
    () async {
      await controller.loadNextQuestion();
      service.fail = true;
      await controller.loadNextQuestion();
      controller.answer('helloworld');
      expect(controller.canAnswer, false);
      expect(controller.answeredCount, 0);
      service.fail = false;
      await controller.retry();
      expect(controller.canAnswer, true);
    },
  );
  test(
    'question limit is visible to listeners and prevents further work',
    () async {
      await controller.loadNextQuestion();
      controller.answeredCount = 9;
      final finished = <bool>[];
      controller.addListener(() => finished.add(controller.isFinished));
      controller.answer('helloworld');
      expect(finished, [true]);
      await controller.loadNextQuestion();
      controller.answer('helloworld');
      expect(service.loads, 1);
      expect(controller.answeredCount, 10);
    },
  );
  test('completed game cannot save score twice', () async {
    controller.score = 100;
    await controller.loadNextQuestion();
    await controller.retry();
    expect(service.saves, 1);
    expect(controller.isFinished, true);
  });
  testWidgets('correct answer advances after one second', (tester) async {
    await controller.loadNextQuestion();
    controller.answer('helloworld');
    await tester.pump(const Duration(milliseconds: 999));
    expect(service.loads, 1);
    await tester.pump(const Duration(milliseconds: 1));
    expect(service.loads, 2);
  });
  testWidgets('wrong answer waits two seconds and disposal cancels timer', (
    tester,
  ) async {
    await controller.loadNextQuestion();
    controller.answer('wrong');
    await tester.pump(const Duration(seconds: 1));
    expect(service.loads, 1);
    controller.dispose();
    await tester.pump(const Duration(seconds: 2));
    expect(service.loads, 1);
  });
}
