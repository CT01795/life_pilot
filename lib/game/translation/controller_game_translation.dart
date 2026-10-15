import 'dart:async';
import 'package:life_pilot/game/translation/service_translation_speech.dart';
import 'package:life_pilot/utils/safe_change_notifier.dart';
import 'package:life_pilot/game/service_game.dart';
import 'package:life_pilot/game/translation/model_game_translation.dart';
import 'package:life_pilot/utils/value_parser.dart';
import 'package:life_pilot/utils/logger.dart';

class ControllerGameTranslation extends SafeChangeNotifier {
  final String userName;
  final ServiceGame service;
  final String gameId;
  final int gameLevel;
  final String gameName;
  final String questionBank;

  ModelGameTranslation? currentQuestion;
  int score = 0;
  int scoreMinus = 0;
  bool isFinished = false;
  bool isLoading = false;
  bool isAnswering = false;
  Object? loadError;
  final ServiceTranslationSpeech _speech;
  bool? _lastAnswerCorrect;
  String? lastAnswer; // 使用者選的答案
  bool showCorrectAnswer = false; // 是否要顯示正確答案
  Timer? _nextQuestionTimer; // Timer 控制自動下一題
  int answeredCount = 0;
  final int maxQuestions;

  ControllerGameTranslation({
    required this.userName,
    required this.service,
    required this.gameId, // 初始化
    required this.gameLevel,
    required this.gameName,
    this.questionBank = 'admin',
    required this.maxQuestions,
    ServiceTranslationSpeech? speech,
  }) : _speech = speech ?? ServiceTranslationSpeech();

  Future<void> speak(String text, String group, bool isQuestion) async {
    if (!notifierDisposed) await _speech.speak(text, group, isQuestion);
  }

  bool get canAnswer =>
      !notifierDisposed &&
      !isLoading &&
      !isAnswering &&
      !isFinished &&
      currentQuestion != null &&
      lastAnswer == null;

  Future<void> loadNextQuestion() async {
    if (notifierDisposed || isLoading || isAnswering || isFinished) return;
    _nextQuestionTimer?.cancel(); // 先取消之前的 Timer
    if (score >= 100) {
      await _completeGame();
      return;
    }

    isLoading = true;
    loadError = null;
    lastAnswer = null;
    _lastAnswerCorrect = null;
    showCorrectAnswer = false;
    _notifyIfActive();

    final question = await _fetchQuestionSafely();
    if (notifierDisposed) return;
    currentQuestion = question;

    isLoading = false;
    _notifyIfActive();
    if (currentQuestion == null) return;
    unawaited(speak(currentQuestion!.question, currentQuestion!.group, true));
  }

  Future<ModelGameTranslation?> _fetchQuestionSafely() async {
    try {
      return await service.fetchTranslationQuestion(
        userName,
        gameLevel,
        gameName,
        questionBank: questionBank,
      );
    } catch (error, stackTrace) {
      logger.e(
        'Load translation question failed',
        error: error,
        stackTrace: stackTrace,
      );
      if (!notifierDisposed) loadError = error;
      return null;
    }
  }

  final Map<String, Set<String>> _synonyms = {};
  Future<void> answer(String answer) async {
    if (!canAnswer) return;
    final question = currentQuestion!;
    isAnswering = true;
    _notifyIfActive();

    try {
      final key = question.question.toLowerCase();
      final normalized = answer.toLowerCase();
      var isRightAnswer = normalized == question.correctAnswer.toLowerCase();
      if (!isRightAnswer) {
        var alternatives = _synonyms[key];
        if (alternatives == null) {
          alternatives = await service.getSynonyms(key);
          if (notifierDisposed || !identical(currentQuestion, question)) return;
          _synonyms[key] = Set.unmodifiable(alternatives);
        }
        isRightAnswer = alternatives.contains(normalized);
      }
      if (notifierDisposed || !identical(currentQuestion, question)) return;
      lastAnswer = answer;
      _lastAnswerCorrect = isRightAnswer;
      answeredCount++;

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
      _notifyIfActive();

      // 答對停留一秒，答錯停留兩秒以查看正確答案。
      if (answeredCount >= maxQuestions) {
        _nextQuestionTimer?.cancel();
        isFinished = true;
      } else {
        _nextQuestionTimer = Timer(Duration(seconds: seconds), () {
          unawaited(loadNextQuestion());
        });
      }
      unawaited(
        _submitAnswerSafely(
          questionId: question.questionId,
          answer: answer,
          isRightAnswer: isRightAnswer,
        ),
      );
    } catch (error, stackTrace) {
      logger.e(
        'Answer translation question failed',
        error: error,
        stackTrace: stackTrace,
      );
      if (!notifierDisposed) loadError = error;
    } finally {
      if (!notifierDisposed) {
        isAnswering = false;
        _notifyIfActive();
      }
    }
  }

  Future<void> _submitAnswerSafely({
    required String questionId,
    required String answer,
    required bool isRightAnswer,
  }) async {
    try {
      await service.submitTranslationAnswer(
        userName: userName,
        questionId: questionId,
        answer: answer,
        isRightAnswer: isRightAnswer,
      );
    } catch (error, stackTrace) {
      logger.e(
        'Submit translation answer failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _saveScore(bool isPass) async {
    await service.saveUserGameScore(
      newUserName: userName,
      newScore: parseDoubleValue(score + scoreMinus),
      newGameId: gameId, // 使用傳入的 gameId
      newIsPass: isPass,
    );
  }

  Future<void> _completeGame() async {
    if (notifierDisposed || isLoading || isAnswering || isFinished) return;
    _nextQuestionTimer?.cancel();
    isLoading = true;
    loadError = null;
    _notifyIfActive();
    try {
      await _saveScore(true);
      if (notifierDisposed) return;
      isFinished = true;
    } catch (error, stackTrace) {
      logger.e(
        'Save translation score failed',
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

  void _notifyIfActive() {
    if (!notifierDisposed) notifyListeners();
  }

  TranslationOptionFeedback feedbackFor(String option) {
    if (lastAnswer == null) return TranslationOptionFeedback.neutral;
    if (option == lastAnswer) {
      return _lastAnswerCorrect == true
          ? TranslationOptionFeedback.correct
          : TranslationOptionFeedback.incorrect;
    }
    if (showCorrectAnswer && option == currentQuestion?.correctAnswer) {
      return TranslationOptionFeedback.correct;
    }
    return TranslationOptionFeedback.neutral;
  }

  @override
  void dispose() {
    _nextQuestionTimer?.cancel();
    unawaited(_speech.dispose());
    super.dispose();
  }
}
