import 'dart:async';

import 'package:flutter/material.dart';
import 'package:life_pilot/models/game/model_game_sentence_say.dart';
import 'package:life_pilot/services/game/service_game_sentence_say.dart';

class ControllerGameSentenceSay extends ChangeNotifier {
  final String userName;
  final ServiceGameSentenceSay service;
  final String gameId;

  ModelGameSentenceSay? currentQuestion;
  int score = 0; // +1 / -1
  int scoreMinus = 0; // +1 / -1
  bool isFinished = false;
  bool isLoading = false;
  Timer? _nextQuestionTimer; // Timer 控制自動下一題

  ControllerGameSentenceSay({
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
    notifyListeners();

    currentQuestion = await service.fetchQuestion(userName);

    isLoading = false;
    notifyListeners();
  }

  int answer(String answer, int counts) {
    if (currentQuestion == null) return 0;
    final isRightAnswer = answer == currentQuestion!.correctAnswer;
    int seconds = 1;
    if (isRightAnswer) {
      score += 4;
      seconds = 1;
    } else {
      counts++;
    }
    notifyListeners();
    if (!isRightAnswer && counts < 3) {
      return counts;
    }

    // 用 Timer 2 秒後跳下一題
    _nextQuestionTimer = Timer(Duration(seconds: seconds), () {
      loadNextQuestion();
    });

    service.submitAnswer(
      userName: userName,
      questionId: currentQuestion!.questionId,
      answer: currentQuestion!.correctAnswer,
      isRightAnswer: true,
    );
    return 0;
  }

  Future<void> _saveScore() async {
    await service.saveUserGameScore(
      userName: userName,
      score: (score + scoreMinus).toDouble(),
      gameId: gameId, // 使用傳入的 gameId
    );
  }
}
