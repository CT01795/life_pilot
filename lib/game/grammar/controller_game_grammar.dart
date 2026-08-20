import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:life_pilot/game/google_tts_audio.dart';
import 'package:life_pilot/game/grammar/model_game_grammar.dart';
import 'package:life_pilot/game/service_game.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:life_pilot/utils/tts/tts_stub.dart'
    if (dart.library.html) 'package:life_pilot/utils/tts/tts_web.dart';

class ControllerGameGrammar extends ChangeNotifier {
  final String userName;
  final ServiceGame service;
  final String gameId;
  final int gameLevel;
  final ModelGameGrammar model;
  final GoogleTtsAudio _ttsAudio = GoogleTtsAudio();
  bool? isRightAnswer;
  int answeredCount = 0; // 紀錄答了幾題

  ModelGameGrammarQuestion? currentQuestion;
  bool isFinished = false;
  bool isLoading = false;
  Object? loadError;
  bool _isDisposed = false;
  bool showCorrectAnswer = false; // 是否要顯示正確答案
  Timer? _nextQuestionTimer; // Timer 控制自動下一題

  ControllerGameGrammar({
    required this.userName,
    required this.service,
    required this.gameId, // 初始化
    required this.gameLevel,
    required this.model,
  });

  Future<void> startBattle(int level) async {
    answeredCount = 0;
    model.monster = ModelGameGrammarMonster('Monster', 50 + level * 10, 10);
    await loadNextQuestion();
  }

  Future<void> loadNextQuestion() async {
    if (_isDisposed || isLoading) return;
    isRightAnswer = null;
    _nextQuestionTimer?.cancel(); // 先取消之前的 Timer
    if (model.monster!.hp <= 0 || model.player.hp <= 0) {
      //isBattleOver
      isLoading = true;
      loadError = null;
      _notifyIfActive();
      try {
        await _saveScore(model.player.hp >= 100);
        if (_isDisposed) return;
        isFinished = true;
      } catch (error, stackTrace) {
        logger.e('Save grammar score failed',
            error: error, stackTrace: stackTrace);
        if (!_isDisposed) loadError = error;
      }
      if (!_isDisposed) {
        isLoading = false;
        _notifyIfActive();
      }
      return;
    }

    isLoading = true;
    loadError = null;
    showCorrectAnswer = false;
    _notifyIfActive();

    currentQuestion = await _fetchQuestionSafely();
    if (_isDisposed) return;
    currentQuestion?.options.shuffle();
    model.currentQuestion = currentQuestion;

    isLoading = false;
    _notifyIfActive();
    if (currentQuestion != null) {
      unawaited(_speakSafely(currentQuestion!.question
          .replaceAll("______", currentQuestion!.correctAnswer)
          .replaceAll("<-->", ",")));
    }
  }

  Future<ModelGameGrammarQuestion?> _fetchQuestionSafely() async {
    try {
      return await service.fetchGrammarQuestion(userName, gameLevel);
    } catch (error, stackTrace) {
      logger.e('Load grammar question failed',
          error: error, stackTrace: stackTrace);
      if (!_isDisposed) loadError = error;
      return null;
    }
  }

  Future<void> _speakSafely(String text) async {
    try {
      await speak(text);
    } catch (error, stackTrace) {
      logger.e('Grammar audio failed', error: error, stackTrace: stackTrace);
    }
  }

  Future<void> speak(String text) async {
    if (text.isEmpty) return;

    if (kIsWeb) {
      await speakWeb(text);
      return;
    }

    await _ttsAudio.speak(
      text: text,
      languageCode: 'en-US',
    );
  }

  Future<void> answer(String answer) async {
    if (currentQuestion == null || isRightAnswer != null) return;
    answeredCount++;
    isRightAnswer = answer == currentQuestion!.correctAnswer;
    if (isRightAnswer ?? false) {
      model.monster!.hp -= model.player.attack;
    } else {
      model.player.hp -= model.monster!.attack;
      showCorrectAnswer = true; // 顯示正確答案
    }
    _notifyIfActive();

    // async submitAnswer 不阻塞 UI
    unawaited(_submitAnswerSafely(
      questionId: currentQuestion!.questionId,
      answer: answer,
      isRightAnswer: isRightAnswer ?? false,
    ));

    final delay = (isRightAnswer ?? false) ? 1 : 2;
    _nextQuestionTimer = Timer(Duration(seconds: delay), () {
      unawaited(loadNextQuestion());
    });
  }

  Future<void> _submitAnswerSafely({
    required String questionId,
    required String answer,
    required bool isRightAnswer,
  }) async {
    try {
      await service.submitGrammarAnswer(
        userName: userName,
        questionId: questionId,
        answer: answer,
        isRightAnswer: isRightAnswer,
      );
    } catch (error, stackTrace) {
      logger.e('Submit grammar answer failed',
          error: error, stackTrace: stackTrace);
    }
  }

  Future<void> _saveScore(bool isPass) async {
    await service.saveUserGameScore(
      newUserName: userName,
      newScore: model.player.hp.toDouble(),
      newGameId: gameId, // 使用傳入的 gameId
      newIsPass: isPass,
    );
  }

  void _notifyIfActive() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _nextQuestionTimer?.cancel();
    _ttsAudio.dispose();
    super.dispose();
  }
}
