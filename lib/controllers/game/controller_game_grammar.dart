import 'dart:async';

import 'package:flutter/material.dart';
import 'package:life_pilot/models/game/model_game_grammar.dart';
import 'package:life_pilot/services/game/service_game_grammar.dart';

class ControllerGameGrammar extends ChangeNotifier {
  final String userName;
  final ServiceGameGrammar service;
  final String gameId;
  final ModelGameGrammar model;

  ModelGameGrammarQuestion? currentQuestion;
  bool isFinished = false;
  bool isLoading = false;
  String? lastAnswer; // 使用者選的答案
  bool showCorrectAnswer = false; // 是否要顯示正確答案
  Timer? _nextQuestionTimer; // Timer 控制自動下一題
  int level = 1;

  ControllerGameGrammar({
    required this.userName,
    required this.service,
    required this.gameId, // 初始化
    required this.model,
  });

  void setLevel(int inputLevel) {
    level = inputLevel;
  }

  Future<void> startBattle() async {
    model.monster = ModelGameGrammarMonster('Monster', 50 + level * 10, 10);
    await loadNextQuestion();
  }

  Future<void> loadNextQuestion() async {
    _nextQuestionTimer?.cancel(); // 先取消之前的 Timer
    if (model.monster!.hp <= 0 || model.player.hp <= 0) {
      //isBattleOver
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
    model.currentQuestion = currentQuestion;

    isLoading = false;
    notifyListeners();
  }

  void answer(String answer) {
    if (currentQuestion == null || lastAnswer != null) return;

    lastAnswer = answer;
    final isRightAnswer = answer == currentQuestion!.correctAnswer;
    int seconds = 1;
    if (isRightAnswer) {
      model.monster!.hp -= model.player.attack;
      seconds = 1;
    } else {
      model.player.hp -= model.monster!.attack;
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
      score: model.player.hp.toDouble(),
      gameId: gameId, // 使用傳入的 gameId
    );
  }
}
