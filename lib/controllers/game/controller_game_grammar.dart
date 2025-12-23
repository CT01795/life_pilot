import 'dart:async';

import 'package:flutter/material.dart';
import 'package:life_pilot/models/game/model_game_grammar.dart';
import 'package:life_pilot/services/game/service_game.dart';

class ControllerGameGrammar extends ChangeNotifier {
  final String userName;
  final ServiceGame service;
  final String gameId;
  final ModelGameGrammar model;
  bool? isRightAnswer;
  int answeredCount = 0; // 紀錄答了幾題

  ModelGameGrammarQuestion? currentQuestion;
  bool isFinished = false;
  bool isLoading = false;
  bool showCorrectAnswer = false; // 是否要顯示正確答案
  Timer? _nextQuestionTimer; // Timer 控制自動下一題

  ControllerGameGrammar({
    required this.userName,
    required this.service,
    required this.gameId, // 初始化
    required this.model,
  });

  Future<void> startBattle(int level) async {
    answeredCount = 0;
    model.monster = ModelGameGrammarMonster('Monster', 50 + level * 10, 10);
    await loadNextQuestion();
  }

  Future<void> loadNextQuestion() async {
    isRightAnswer = null;
    _nextQuestionTimer?.cancel(); // 先取消之前的 Timer
    if (model.monster!.hp <= 0 || model.player.hp <= 0) {
      //isBattleOver
      isFinished = true;
      notifyListeners();
      await _saveScore();
      return;
    }

    isLoading = true;
    showCorrectAnswer = false;
    notifyListeners();

    currentQuestion = await service.fetchGrammarQuestion(userName);
    currentQuestion?.options.shuffle();
    model.currentQuestion = currentQuestion;

    isLoading = false;
    notifyListeners();
  }

  Future<void> answer(String answer) async {
    if (currentQuestion == null || showCorrectAnswer) return;
    answeredCount++;
    isRightAnswer = answer == currentQuestion!.correctAnswer;
    if (isRightAnswer ?? false) {
      model.monster!.hp -= model.player.attack;
    } else {
      model.player.hp -= model.monster!.attack;
      showCorrectAnswer = true; // 顯示正確答案
    }
    notifyListeners();

    // async submitAnswer 不阻塞 UI
    unawaited(service.submitGrammarAnswer(
      userName: userName,
      questionId: currentQuestion!.questionId,
      answer: answer,
      isRightAnswer: isRightAnswer ?? false,
    ));

    final delay = (isRightAnswer ?? false) ? 1 : 2;
    _nextQuestionTimer = Timer(Duration(seconds: delay), () {
      loadNextQuestion();
    });
  }

  Future<void> _saveScore() async {
    await service.saveUserGameScore(
      newUserName: userName,
      newScore: model.player.hp.toDouble(),
      newGameId: gameId, // 使用傳入的 gameId
    );
  }

  @override
  void dispose() {
    _nextQuestionTimer?.cancel();
    super.dispose();
  }
}
