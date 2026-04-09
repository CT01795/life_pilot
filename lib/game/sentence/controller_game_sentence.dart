import 'dart:async';

import 'package:flutter/material.dart';
import 'package:life_pilot/game/sentence/model_game_sentence.dart';
import 'package:life_pilot/game/service_game.dart';
import 'package:uuid/uuid.dart';

class ControllerGameSentence extends ChangeNotifier {
  final String userName;
  final ServiceGame service;
  final String gameId;
  final int gameLevel;

  ModelGameSentence? currentQuestion;
  bool isFinished = false;
  bool isLoading = false;
  String? lastAnswer; // 使用者選的答案
  bool showCorrectAnswer = false; // 是否要顯示正確答案
  List<WordItem> options = []; // 底部文字方塊
  List<WordItem?> answerSlots = []; // 上方拖曳區
  bool? isRightAnswer;

  int score = 0; // +1 / -1
  int scoreMinus = 0; // +1 / -1
  Timer? _nextQuestionTimer; // Timer 控制自動下一題

  ControllerGameSentence({
    required this.userName,
    required this.service,
    required this.gameId, // 初始化
    required this.gameLevel,
  });

  Future<void> loadNextQuestion() async {
    _nextQuestionTimer?.cancel(); // 先取消之前的 Timer
    if (score >= 100) {
      isFinished = true;
      await _saveScore(score >= 100);
      notifyListeners();
      return;
    }

    isLoading = true;
    lastAnswer = null;
    isRightAnswer = null;
    showCorrectAnswer = false;
    notifyListeners();

    currentQuestion = await service.fetchSentenceQuestion(userName, gameLevel);
    // 🔹 初始化答案槽 & 選項
    if (currentQuestion != null) {
      answerSlots = List.filled(currentQuestion!.options.length, null);
      options = List.generate(currentQuestion!.options.length,
          (i) => WordItem(id: Uuid().v4(), text: currentQuestion!.options[i]))
        ..shuffle();
    }

    isLoading = false;
    notifyListeners();
  }

  // 🔹 將單字移動到答案槽
  void moveWordToSlot(int slotIndex, WordItem word) {
    final indexInUpper = answerSlots.indexWhere((e) => e?.id == word.id);
    if (indexInUpper != -1) {
      // 上方交換
      final temp = answerSlots[slotIndex];
      answerSlots[slotIndex] = word;
      answerSlots[indexInUpper] = temp;
    } else {
      // 下方 → 上方
      if (answerSlots[slotIndex] != null) {
        options.add(answerSlots[slotIndex]!);
      }
      answerSlots[slotIndex] = word;
      final index = options.indexWhere((e) => e.id == word.id);
      if (index != -1) options.removeAt(index);
    }
    notifyListeners();
  }

  void removeWordFromSlot(int slotIndex) {
    final word = answerSlots[slotIndex];
    if (word != null) {
      options.add(word);
      answerSlots[slotIndex] = null;
      notifyListeners();
    }
  }

  // 🔹 答題判斷
  void checkAnswer() {
    if (currentQuestion == null || lastAnswer != null) return;

    final userAnswer = currentQuestion!.buildUserAnswer(answerSlots);

    lastAnswer = userAnswer;
    isRightAnswer = userAnswer == currentQuestion!.correctAnswer;
    int seconds = 1;
    if (isRightAnswer == true) {
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

    service.submitSentenceAnswer(
      userName: userName,
      questionId: currentQuestion!.questionId,
      answer: userAnswer,
      isRightAnswer: isRightAnswer ?? false,
    );
  }

  Future<void> _saveScore(bool isPass) async {
    await service.saveUserGameScore(
      newUserName: userName,
      newScore: (score + scoreMinus).toDouble(),
      newGameId: gameId, // 使用傳入的 gameId
      newIsPass: isPass,
    );
  }

  @override
  void dispose() {
    _nextQuestionTimer?.cancel();
    super.dispose();
  }
}
