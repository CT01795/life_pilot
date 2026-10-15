// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:life_pilot/utils/safe_change_notifier.dart';
import 'package:life_pilot/game/service_game.dart';
import 'package:life_pilot/game/service_game_speech.dart';
import 'package:life_pilot/game/social/model_game_social.dart';
import 'package:life_pilot/utils/value_parser.dart';
import 'package:life_pilot/utils/logger.dart';

class ControllerGameSocial extends SafeChangeNotifier {
  final String userName;
  final ServiceGame service;
  final String gameId;
  final int gameLevel;
  final String questionBank;

  ModelGameSocial? currentQuestion;
  int score = 0; // +1 / -1
  int scoreMinus = 0; // +1 / -1
  bool isFinished = false;
  bool isLoading = false;
  Object? loadError;
  String? lastAnswer; // 使用者選的答案
  bool showCorrectAnswer = false; // 是否要顯示正確答案
  Timer? _nextQuestionTimer; // Timer 控制自動下一題
  int answeredCount = 0;
  int maxQuestions = 10;

  ControllerGameSocial({
    required this.userName,
    required this.service,
    required this.gameId, // 初始化
    required this.gameLevel,
    this.questionBank = 'admin',
    required this.maxQuestions,
    ServiceGameSpeech? speech,
  }) : _speech = speech ?? ServiceGameSpeech();

  final ServiceGameSpeech _speech;

  Future<void> speak(String text) async {
    if (notifierDisposed) return;
    await _speech.speak(text);
  }

  bool get canAnswer =>
      !notifierDisposed &&
      !isLoading &&
      !isFinished &&
      currentQuestion != null &&
      lastAnswer == null;

  Future<void> loadNextQuestion() async {
    if (notifierDisposed || isLoading || isFinished) return;
    _nextQuestionTimer?.cancel(); // 先取消之前的 Timer
    if (score >= 100) {
      await _completeGame();
      return;
    }

    isLoading = true;
    loadError = null;
    lastAnswer = null;
    showCorrectAnswer = false;
    _notifyIfActive();

    final question = await _fetchQuestionSafely();
    if (notifierDisposed) return;
    currentQuestion = question;

    isLoading = false;
    _notifyIfActive();
    if (currentQuestion != null) {
      unawaited(_speakSafely(currentQuestion!.scene));
    }
  }

  Future<ModelGameSocial?> _fetchQuestionSafely() async {
    try {
      return await service.fetchSocialQuestion(
        userName,
        gameLevel,
        questionBank: questionBank,
      );
    } catch (error, stackTrace) {
      logger.e(
        'Load social question failed',
        error: error,
        stackTrace: stackTrace,
      );
      if (!notifierDisposed) loadError = error;
      return null;
    }
  }

  Future<void> _speakSafely(String text) async {
    try {
      await speak(text);
    } catch (error, stackTrace) {
      logger.e('Social audio failed', error: error, stackTrace: stackTrace);
    }
  }

  Map<String, Set<String>> synonyms = {};
  Future<void> answer(String answer) async {
    if (!canAnswer) return;

    int inputScore = getScore(answer);

    lastAnswer = answer;
    answeredCount++;
    final isRightAnswer = inputScore >= 0;

    int seconds = 1;
    if (isRightAnswer) {
      score += inputScore;
      seconds = 1;
    } else {
      score += inputScore;
      scoreMinus += inputScore;
      seconds = 2;
      showCorrectAnswer = true; // 顯示正確答案
    }
    _notifyIfActive();

    // 用 Timer 2 秒後跳下一題
    _nextQuestionTimer = Timer(Duration(seconds: seconds), () {
      unawaited(loadNextQuestion());
    });

    if (answeredCount >= maxQuestions) {
      _nextQuestionTimer?.cancel();
      isFinished = true;
      _notifyIfActive();
    }
    unawaited(
      _submitAnswerSafely(
        questionId: currentQuestion!.id,
        answer: answer,
        isRightAnswer: isRightAnswer,
      ),
    );
  }

  Future<void> _submitAnswerSafely({
    required String questionId,
    required String answer,
    required bool isRightAnswer,
  }) async {
    try {
      await service.submitSocialAnswer(
        userName: userName,
        questionId: questionId,
        answer: answer,
        isRightAnswer: isRightAnswer,
      );
    } catch (error, stackTrace) {
      logger.e(
        'Submit social answer failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _completeGame() async {
    if (notifierDisposed || isLoading || isFinished) return;
    _nextQuestionTimer?.cancel();
    isLoading = true;
    loadError = null;
    _notifyIfActive();
    try {
      await _saveScore(score >= 100);
      if (notifierDisposed) return;
      isFinished = true;
    } catch (error, stackTrace) {
      logger.e(
        'Save social score failed',
        error: error,
        stackTrace: stackTrace,
      );
      if (!notifierDisposed) loadError = error;
    } finally {
      if (!notifierDisposed) {
        isLoading = false;
        _notifyIfActive();
      }
    }
  }

  Future<void> retry() {
    return score >= 100 ? _completeGame() : loadNextQuestion();
  }

  Future<void> _saveScore(bool isPass) async {
    await service.saveUserGameScore(
      newUserName: userName,
      newScore: parseDoubleValue(score + scoreMinus),
      newGameId: gameId, // 使用傳入的 gameId
      newIsPass: isPass,
    );
  }

  void _notifyIfActive() {
    if (!notifierDisposed) notifyListeners();
  }

  int getScore(String option) => currentQuestion?.scoreFor(option) ?? -1;

  SocialOptionFeedback feedbackFor(String option) {
    if (lastAnswer == null) return SocialOptionFeedback.neutral;
    final correct = getScore(option) >= 0;
    if (option == lastAnswer) {
      return correct
          ? SocialOptionFeedback.correct
          : SocialOptionFeedback.incorrect;
    }
    return correct && showCorrectAnswer
        ? SocialOptionFeedback.correct
        : SocialOptionFeedback.neutral;
  }

  @override
  void dispose() {
    _nextQuestionTimer?.cancel();
    unawaited(_speech.dispose());
    super.dispose();
  }
}
