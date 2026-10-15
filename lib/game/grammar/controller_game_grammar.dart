import 'dart:async';
import 'package:life_pilot/game/service_game_speech.dart';
import 'package:life_pilot/game/grammar/model_game_grammar.dart';
import 'package:life_pilot/utils/value_parser.dart';
import 'package:life_pilot/game/service_game.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:life_pilot/utils/safe_change_notifier.dart';

class ControllerGameGrammar extends SafeChangeNotifier {
  final String userName;
  final ServiceGame service;
  final String gameId;
  final int gameLevel;
  final String questionBank;
  final ModelGameGrammar model;
  final ServiceGameSpeech _speech;
  final int maxQuestions;
  bool? get isRightAnswer => model.isRightAnswer;
  int get answeredCount => model.answeredCount;
  ModelGameGrammarQuestion? get currentQuestion => model.currentQuestion;
  bool get canAnswer =>
      !notifierDisposed && !isLoading && !isFinished && model.canAnswer;
  bool isFinished = false;
  bool isLoading = false;
  Object? loadError;
  bool showCorrectAnswer = false; // 是否要顯示正確答案
  Timer? _nextQuestionTimer; // Timer 控制自動下一題

  ControllerGameGrammar({
    required this.userName,
    required this.service,
    required this.gameId, // 初始化
    required this.gameLevel,
    this.questionBank = 'admin',
    required this.model,
    this.maxQuestions = 999,
    ServiceGameSpeech? speech,
  }) : _speech = speech ?? ServiceGameSpeech();

  Future<void> startBattle(int level) async {
    if (notifierDisposed || isLoading) return;
    _nextQuestionTimer?.cancel();
    isFinished = false;
    model.startBattle(level);
    await loadNextQuestion();
  }

  Future<void> loadNextQuestion() async {
    if (notifierDisposed || isLoading || isFinished || model.monster == null) {
      return;
    }
    _nextQuestionTimer?.cancel(); // 先取消之前的 Timer
    if (model.isBattleOver) {
      //isBattleOver
      isLoading = true;
      loadError = null;
      _notifyIfActive();
      try {
        await _saveScore(model.player.hp >= 100);
        if (notifierDisposed) return;
        isFinished = true;
      } catch (error, stackTrace) {
        logger.e(
          'Save grammar score failed',
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

    isLoading = true;
    loadError = null;
    showCorrectAnswer = false;
    model.prepareQuestion();
    _notifyIfActive();

    final question = await _fetchQuestionSafely();
    if (notifierDisposed) return;
    if (question != null) {
      model.currentQuestion = ModelGameGrammarQuestion(
        questionId: question.questionId,
        question: question.question,
        options: [...question.options]..shuffle(),
        correctAnswer: question.correctAnswer,
        type: question.type,
        isRight: question.isRight,
      );
    }

    isLoading = false;
    _notifyIfActive();
    if (currentQuestion != null) {
      unawaited(speak(currentQuestion!.spokenQuestion));
    }
  }

  Future<ModelGameGrammarQuestion?> _fetchQuestionSafely() async {
    try {
      return await service.fetchGrammarQuestion(
        userName,
        gameLevel,
        questionBank: questionBank,
      );
    } catch (error, stackTrace) {
      logger.e(
        'Load grammar question failed',
        error: error,
        stackTrace: stackTrace,
      );
      if (!notifierDisposed) loadError = error;
      return null;
    }
  }

  Future<void> speak(String text) async {
    if (!notifierDisposed) await _speech.speakEnglish(text);
  }

  Future<void> answer(String answer) async {
    if (!canAnswer) return;
    final question = currentQuestion!;
    final correct = model.answer(answer);
    if (correct == null) return;
    showCorrectAnswer = !correct;
    if (answeredCount >= maxQuestions) isFinished = true;
    _notifyIfActive();

    // async submitAnswer 不阻塞 UI
    unawaited(
      _submitAnswerSafely(
        questionId: question.questionId,
        answer: answer,
        isRightAnswer: correct,
      ),
    );

    if (isFinished || notifierDisposed) return;
    final delay = correct ? 1 : 2;
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
      logger.e(
        'Submit grammar answer failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _saveScore(bool isPass) async {
    await service.saveUserGameScore(
      newUserName: userName,
      newScore: parseDoubleValue(model.player.hp),
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
