import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:life_pilot/game/google_tts_audio.dart';
import 'package:life_pilot/game/service_game.dart';
import 'package:life_pilot/game/speaking/model_game_speaking.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:life_pilot/utils/safe_change_notifier.dart';
import 'package:life_pilot/utils/tts/tts_stub.dart'
    if (dart.library.html) 'package:life_pilot/utils/tts/tts_web.dart';

class ControllerGameSpeaking extends SafeChangeNotifier {
  final String userName;
  final ServiceGame service;
  final String gameId;
  final int gameLevel;
  final String questionBank;
  final GoogleTtsAudio _ttsAudio = GoogleTtsAudio();
  ModelGameSpeaking? currentQuestion;
  int score = 0; // +1 / -1
  int scoreMinus = 0; // +1 / -1
  bool isFinished = false;
  bool isLoading = false;
  Object? loadError;
  bool _isDisposed = false;
  Timer? _nextQuestionTimer; // Timer 控制自動下一題

  int repeatCounts = 0;
  bool? isRightAnswer;
  bool isBusy = false;

  ControllerGameSpeaking({
    required this.userName,
    required this.service,
    required this.gameId, // 初始化
    required this.gameLevel,
    this.questionBank = 'admin',
  });

  Future<void> loadNextQuestion() async {
    if (_isDisposed || isLoading) return;
    _nextQuestionTimer?.cancel(); // 先取消之前的 Timer
    loadError = null;
    isLoading = true;
    _notifyIfActive();
    if (score >= 100) {
      try {
        await _saveScore(true);
        if (_isDisposed) return;
        isFinished = true;
      } catch (error, stackTrace) {
        logger.e('Save speaking score failed',
            error: error, stackTrace: stackTrace);
        if (!_isDisposed) loadError = error;
      }
      if (!_isDisposed) {
        isLoading = false;
        _notifyIfActive();
      }
      return;
    }

    final question = await _fetchQuestionSafely();
    if (_isDisposed) return;

    isLoading = false;
    _notifyIfActive();
    if (question == null) return;
    currentQuestion = question;
    unawaited(_speakSafely(question.correctAnswer));
  }

  Future<ModelGameSpeaking?> _fetchQuestionSafely() async {
    try {
      return await service.fetchSpeakingQuestion(
        userName,
        gameLevel,
        questionBank: questionBank,
      );
    } catch (error, stackTrace) {
      logger.e('Load speaking question failed',
          error: error, stackTrace: stackTrace);
      if (!_isDisposed) loadError = error;
      return null;
    }
  }

  Future<void> _speakSafely(String text) async {
    try {
      await speak(text);
    } catch (error, stackTrace) {
      logger.e('Speaking audio failed', error: error, stackTrace: stackTrace);
    }
  }

  Future<void> speak(String text) async {
    if (text.isEmpty) return;

    if (kIsWeb) {
      await speakWeb(text);
      return;
    }

    final containsChinese = RegExp(r'[\u4e00-\u9fff]').hasMatch(text);
    await _ttsAudio.speak(
      text: text,
      languageCode: containsChinese ? 'zh' : 'en-US',
    );
  }

  void answer(String answer) {
    if (currentQuestion == null) return;
    if (answer.isEmpty) {
      return;
    }
    repeatCounts++;

    String right = currentQuestion!.correctAnswer.toLowerCase();
    String my = answer.toLowerCase();
    isRightAnswer = right == my ||
        right.replaceAll(" ", '').replaceAll(".", '') ==
            my.replaceAll(" ", '').replaceAll(".", '');
    int seconds = 1;
    if (isRightAnswer == true) {
      score += 4;
      seconds = 1;
    } else {
      seconds = 2;
    }

    if (isRightAnswer != true && repeatCounts < 2) {
      _notifyIfActive();
      return;
    } else if (isRightAnswer != true && repeatCounts == 2) {
      score += 4;
    }

    isBusy = true;
    _notifyIfActive();

    // 用 Timer 2 秒後跳下一題
    _nextQuestionTimer = Timer(Duration(seconds: seconds), () {
      repeatCounts = 0;
      isBusy = false;
      unawaited(loadNextQuestion());
    });

    unawaited(_submitAnswerSafely(
      questionId: currentQuestion!.questionId,
      answer: currentQuestion!.correctAnswer,
    ));
    _notifyIfActive();
  }

  Future<void> _submitAnswerSafely({
    required String questionId,
    required String answer,
  }) async {
    try {
      await service.submitSpeakingAnswer(
        userName: userName,
        questionId: questionId,
        answer: answer,
        isRightAnswer: true,
      );
    } catch (error, stackTrace) {
      logger.e('Submit speaking answer failed',
          error: error, stackTrace: stackTrace);
    }
  }

  Future<void> _saveScore(bool isPass) async {
    await service.saveUserGameScore(
      newUserName: userName,
      newScore: (score + scoreMinus).toDouble(),
      newGameId: gameId, // 使用傳入的 gameId
      newIsPass: isPass,
    );
  }

  void finishPractice() {
    _nextQuestionTimer?.cancel();
    isBusy = false;
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
