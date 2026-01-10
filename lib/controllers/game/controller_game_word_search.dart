import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:life_pilot/models/game/model_game_word_search.dart';
import 'package:life_pilot/services/game/service_game.dart';

class ControllerGameWordSearch extends ChangeNotifier {
  final String userName;
  final ServiceGame service;
  final String gameId;

  final WordSearchBoard board;
  ModelGameWordSearch currentQuestion;

  int score = 0; // +1 / -1
  int scoreMinus = 0; // +1 / -1
  bool isFinished = false;
  bool isLoading = false;
  String? lastAnswer; // 使用者選的答案
  bool showCorrectAnswer = false; // 是否要顯示正確答案
  Timer? _nextQuestionTimer; // Timer 控制自動下一題
  int answeredCount = 0;
  int maxQuestions = 10;

  List<List<int>> directions = [
    [0, 1],   // →
    [1, 0],   // ↓
    [1, 1],   // ↘
    [-1, 1],  // ↗
  ];

  List<int>? _currentDirection;

  ControllerGameWordSearch({
    required this.userName,
    required this.service,
    required this.gameId, // 初始化
    required this.maxQuestions,
    required this.board,
    required this.currentQuestion,
  });

  Future<void> loadNextQuestion() async {
    _nextQuestionTimer?.cancel(); // 先取消之前的 Timer
    if (score >= 100) {
      isFinished = true;
      await _saveScore();
      notifyListeners();
      return;
    }

    isLoading = true;
    lastAnswer = null;
    showCorrectAnswer = false;
    notifyListeners();

    currentQuestion = await service.fetchWordSearchQuestion(userName);
    _generateBoardFromQuestion();

    isLoading = false;
    notifyListeners();
  }

  void _generateBoardFromQuestion() {
    board.clearSelection();
    _currentDirection = null;
    lastAnswer = null;

    final word = currentQuestion.question.replaceAll(' ', '');
    final wordLength = word.length;

    // ⭐ 動態計算格子大小
    final newSize = max(wordLength + 3, 8);
    if (board.size != newSize) {
      board.size = newSize;
      // 重新生成 grid
      board.grid = List.generate(
        board.size,
        (r) => List.generate(
          board.size,
          (c) => LetterCell(row: r, col: c, letter: ''),
        ),
      );
    } else {
      // 清空格子
      for (var r = 0; r < board.size; r++) {
        for (var c = 0; c < board.size; c++) {
          board.grid[r][c] = LetterCell(row: r, col: c, letter: '');
        }
      }
    }

    final random = Random();

    // 隨機方向
    final dir = directions[random.nextInt(directions.length)];
    final dr = dir[0];
    final dc = dir[1];

    // 找合法起點
    int startRow, startCol;
    while (true) {
      startRow = random.nextInt(board.size);
      startCol = random.nextInt(board.size);
      if (_canPlace(word, startRow, startCol, dr, dc)) break;
    }

    // 放字
    for (int i = 0; i < word.length; i++) {
      final r = startRow + dr * i;
      final c = startCol + dc * i;
      board.grid[r][c] = LetterCell(row: r, col: c, letter: word[i]);
    }

    // 補亂數字母
    _fillRandomLetters(random);

    notifyListeners();
  }

  bool _canPlace(String word, int r, int c, int dr, int dc) {
    for (int i = 0; i < word.length; i++) {
      final nr = r + dr * i;
      final nc = c + dc * i;

      if (nr < 0 || nr >= board.size || nc < 0 || nc >= board.size) {
        return false;
      }
    }
    return true;
  }

  void _fillRandomLetters(Random random) {
    const letters = 'abcdefghijklmnopqrstuvwxyz';
    for (var r = 0; r < board.size; r++) {
      for (var c = 0; c < board.size; c++) {
        if (board.grid[r][c].letter.isEmpty) {
          board.grid[r][c] = LetterCell(
            row: r,
            col: c,
            letter: letters[random.nextInt(26)],
          );
        }
      }
    }
  }

  void onSelectCell(LetterCell cell) {
    if (lastAnswer != null) return;

    if (board.currentSelection.isEmpty) {
      cell.selected = true;
      board.currentSelection.add(cell);
      _currentDirection = null; // 重置方向
      notifyListeners();
      return;
    }

    final last = board.currentSelection.last;
    final dr = cell.row - last.row;
    final dc = cell.col - last.col;

    final dir = [dr.sign, dc.sign];

    // 🔹 如果不是合法方向，就清空舊選擇，從這個格子重新開始
    if (!directions.any((d) => d[0] == dir[0] && d[1] == dir[1]) ||
        dr.abs() > 1 ||
        dc.abs() > 1) {
      board.clearSelection();
      cell.selected = true;
      board.currentSelection.add(cell);
      _currentDirection = null;
      notifyListeners();
      return;
    }

    // 🔹 設定方向（如果還沒設定）
    if (_currentDirection == null) {
      _currentDirection = dir;
    } else {
      // 🔹 如果方向不一致，也重置選擇
      if (dir[0] != _currentDirection![0] || dir[1] != _currentDirection![1]) {
        board.clearSelection();
        cell.selected = true;
        board.currentSelection.add(cell);
        _currentDirection = null;
        notifyListeners();
        return;
      }
    }

    // 🔹 合法格子，加入 selection
    cell.selected = true;
    board.currentSelection.add(cell);
    notifyListeners();
  }

  void submitSelection() {
    final selectedWord =
        board.currentSelection.map((c) => c.letter).join();

    answer(selectedWord);

    for (final c in board.currentSelection) {
      c.correct = true;
    }

    board.clearSelection();
    _currentDirection = null;
  }

  void answer(String answer) {
    if (lastAnswer != null) return;

    lastAnswer = answer;
    answeredCount++;
    final isRightAnswer = answer == currentQuestion.question.replaceAll(' ', '');
    int seconds = 1;
    if (isRightAnswer) {
      score += 4;
      seconds = 1;
    } else {
      score -= 4;
      scoreMinus -= 4;
      seconds = 2;
      showCorrectAnswer = true; // 顯示正確答案
    }
    notifyListeners();

    // 用 Timer 2 秒後跳下一題
    _nextQuestionTimer = Timer(Duration(seconds: seconds), () {
      loadNextQuestion();
    });

    if (answeredCount >= maxQuestions) {
      isFinished = true;
    }
    service.submitWordSearchAnswer(
      userName: userName,
      questionId: currentQuestion.questionId,
      answer: currentQuestion.question,
      isRightAnswer: isRightAnswer,
    );
  }

  Future<void> _saveScore() async {
    await service.saveUserGameScore(
      newUserName: userName,
      newScore: (score + scoreMinus).toDouble(),
      newGameId: gameId, // 使用傳入的 gameId
    );
  }

  @override
  void dispose() {
    _nextQuestionTimer?.cancel();
    super.dispose();
  }
}
