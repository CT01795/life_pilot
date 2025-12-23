import 'dart:async';

import 'package:flutter/material.dart';
import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/models/game/model_game_speaking.dart';
import 'package:life_pilot/services/game/service_game.dart';

class ControllerGameSpeaking extends ChangeNotifier {
  final String userName;
  final ServiceGame service;
  final String gameId;

  ModelGameSpeaking? currentQuestion;
  int score = 0; // +1 / -1
  int scoreMinus = 0; // +1 / -1
  bool isFinished = false;
  bool isLoading = false;
  Timer? _nextQuestionTimer; // Timer 控制自動下一題

  ControllerGameSpeaking({
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

    currentQuestion = await service.fetchSpeakingQuestion(userName);

    isLoading = false;
    notifyListeners();
  }

  int answer(String answer, int counts) {
    if (currentQuestion == null) return 0;
    if (answer.isEmpty) {
      return counts;
    } else {
      counts = counts + 1;
    }
    String right = currentQuestion!.correctAnswer.toLowerCase();
    String my = answer.toLowerCase();
    final isRightAnswer = right == my ||
        right.replaceAll(" ", constEmpty).replaceAll(".", constEmpty) ==
            my.replaceAll(" ", constEmpty).replaceAll(".", constEmpty);
    int seconds = 1;
    if (isRightAnswer) {
      score += 4;
      seconds = 1;
    } else {
      seconds = 2;
    }
    notifyListeners();
    if (!isRightAnswer && counts < 2) {
      return counts;
    }

    // 用 Timer 2 秒後跳下一題
    _nextQuestionTimer = Timer(Duration(seconds: seconds), () {
      loadNextQuestion();
    });

    service.submitSpeakingAnswer(
      userName: userName,
      questionId: currentQuestion!.questionId,
      answer: currentQuestion!.correctAnswer,
      isRightAnswer: true,
    );
    return 0;
  }

  Future<void> _saveScore() async {
    await service.saveUserGameScore(
      newUserName: userName,
      newScore: (score + scoreMinus).toDouble(),
      newGameId: gameId, // 使用傳入的 gameId
    );
  }
}
