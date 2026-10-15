import 'dart:async';
import 'package:life_pilot/game/service_game_speech.dart';
import 'package:life_pilot/game/service_game.dart';
import 'package:life_pilot/game/speaking/model_game_speaking.dart';
import 'package:life_pilot/utils/value_parser.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:life_pilot/utils/safe_change_notifier.dart';

class ControllerGameSpeaking extends SafeChangeNotifier {
  final String userName;
  final ServiceGame service;
  final String gameId;
  final int gameLevel;
  final String questionBank;
  final ServiceGameSpeech _speech;
  final int maxQuestions;
  ModelSpeakingRound? _round;
  ModelGameSpeaking? get currentQuestion => _round?.question;
  int score = 0;
  int scoreMinus = 0;
  bool isFinished = false;
  bool isLoading = false;
  Object? loadError;
  Timer? _nextQuestionTimer; // Timer 控制自動下一題

  int get repeatCounts => _round?.attempts ?? 0;
  bool? get isRightAnswer => _round?.isCorrect;
  int _answeredCount = 0;
  int get answeredCount => _answeredCount;
  bool get canAnswer =>
      !notifierDisposed &&
      !isLoading &&
      !isBusy &&
      !isFinished &&
      loadError == null &&
      _round != null &&
      !_round!.isComplete;
  bool isBusy = false;

  ControllerGameSpeaking({
    required this.userName,
    required this.service,
    required this.gameId, // 初始化
    required this.gameLevel,
    this.questionBank = 'admin',
    this.maxQuestions = 999,
    ServiceGameSpeech? speech,
  }) : _speech = speech ?? ServiceGameSpeech();

  Future<void> loadNextQuestion() async {
    if (notifierDisposed || isLoading || isBusy || isFinished) return;
    _nextQuestionTimer?.cancel(); // 先取消之前的 Timer
    loadError = null;
    isLoading = true;
    _notifyIfActive();
    if (score >= 100) {
      try {
        await _saveScore(true);
        if (notifierDisposed) return;
        isFinished = true;
      } catch (error, stackTrace) {
        logger.e(
          'Save speaking score failed',
          error: error,
          stackTrace: stackTrace,
        );
        if (!notifierDisposed) loadError = error;
      }
      if (!notifierDisposed) {
        isLoading = false;
        _notifyIfActive();
      }
      return;
    }

    _round = null;
    final question = await _fetchQuestionSafely();
    if (notifierDisposed) return;

    _round = question == null ? null : ModelSpeakingRound(question);
    isLoading = false;
    _notifyIfActive();
    if (question != null) unawaited(speak(question.correctAnswer));
  }

  Future<ModelGameSpeaking?> _fetchQuestionSafely() async {
    try {
      return await service.fetchSpeakingQuestion(
        userName,
        gameLevel,
        questionBank: questionBank,
      );
    } catch (error, stackTrace) {
      logger.e(
        'Load speaking question failed',
        error: error,
        stackTrace: stackTrace,
      );
      if (!notifierDisposed) loadError = error;
      return null;
    }
  }

  Future<void> speak(String text) async {
    if (!notifierDisposed) await _speech.speak(text);
  }

  /// True only when this input was accepted for the current question.
  bool answer(String answer) {
    if (!canAnswer) return false;
    final question = currentQuestion!;
    final result = _round!.answer(answer);
    if (result == null) return false;
    score += result.points;
    if (result.completesQuestion) {
      _answeredCount++;
      isBusy = true;
      _nextQuestionTimer?.cancel();
      _nextQuestionTimer = Timer(
        Duration(seconds: result.isCorrect ? 1 : 2),
        () {
          if (notifierDisposed) return;
          isBusy = false;
          if (answeredCount >= maxQuestions) {
            isFinished = true;
            _notifyIfActive();
          } else {
            unawaited(loadNextQuestion());
          }
        },
      );
      unawaited(
        _submitAnswerSafely(
          questionId: question.questionId,
          answer: question.correctAnswer,
        ),
      );
    }
    _notifyIfActive();
    return true;
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
      logger.e(
        'Submit speaking answer failed',
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

  void _notifyIfActive() {
    if (!notifierDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _nextQuestionTimer?.cancel();
    unawaited(_speech.dispose());
    super.dispose();
  }
}
