import 'dart:async';

import 'package:flutter/material.dart';
import 'package:life_pilot/models/game/model_game_translation.dart';
import 'package:life_pilot/services/game/service_game_translation.dart';

class ControllerGameTranslation extends ChangeNotifier {
  final String userName;
  final ServiceGameTranslation service;
  final String gameId;

  ModelGameTranslation? currentQuestion;
  int score = 0; // +1 / -1
  int scoreMinus = 0; // +1 / -1
  bool isFinished = false;
  bool isLoading = false;
  String? lastAnswer; // 使用者選的答案
  bool showCorrectAnswer = false; // 是否要顯示正確答案
  Timer? _nextQuestionTimer; // Timer 控制自動下一題

  ControllerGameTranslation({
    required this.userName,
    required this.service,
    required this.gameId, // 初始化
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

    currentQuestion = await service.fetchQuestion(userName);

    isLoading = false;
    notifyListeners();
  }

  void answer(String answer) {
    if (currentQuestion == null || lastAnswer != null) return;

    lastAnswer = answer;
    final isRightAnswer = answer == currentQuestion!.correctAnswer;
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

    service.submitAnswer(
      userName: userName,
      questionId: currentQuestion!.questionId,
      answer: answer,
      isRightAnswer: isRightAnswer,
    );
  }

  Future<void> _saveScore() async {
    await service.saveUserGameScore(
      userName: userName,
      score: (score + scoreMinus).toDouble(),
      gameId: gameId, // 使用傳入的 gameId
    );
  }
}
