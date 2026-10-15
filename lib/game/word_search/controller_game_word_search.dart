import 'dart:async';
import 'package:life_pilot/game/service_game_speech.dart';
import 'package:life_pilot/utils/safe_change_notifier.dart';
import 'package:life_pilot/game/service_game.dart';
import 'package:life_pilot/game/word_search/model_game_word_search.dart';
import 'package:life_pilot/utils/value_parser.dart';
import 'package:life_pilot/utils/logger.dart';

class ControllerGameWordSearch extends SafeChangeNotifier {
  final String userName;
  final ServiceGame service;
  final String gameId;
  final int gameLevel;
  final String questionBank;

  final WordSearchBoard board;
  ModelGameWordSearch currentQuestion;

  int score = 0;
  int scoreMinus = 0;
  bool isFinished = false;
  bool isLoading = false;
  Object? loadError;
  bool _hasQuestion = false;
  final ServiceGameSpeech _speech;
  String? lastAnswer; // 使用者選的答案
  bool showCorrectAnswer = false; // 是否要顯示正確答案
  Timer? _nextQuestionTimer; // Timer 控制自動下一題
  int answeredCount = 0;
  final int maxQuestions;

  bool get canAnswer =>
      !notifierDisposed &&
      !isLoading &&
      !isFinished &&
      _hasQuestion &&
      loadError == null &&
      lastAnswer == null;
  bool get canSubmit => canAnswer && board.currentSelection.isNotEmpty;

  ControllerGameWordSearch({
    required this.userName,
    required this.service,
    required this.gameId, // 初始化
    required this.gameLevel,
    this.questionBank = 'admin',
    required this.maxQuestions,
    required this.board,
    required this.currentQuestion,
    ServiceGameSpeech? speech,
  }) : _speech = speech ?? ServiceGameSpeech();

  Future<void> speak(String text) async {
    if (!notifierDisposed) await _speech.speakEnglish(text);
  }

  Future<void> loadNextQuestion() async {
    if (notifierDisposed || isLoading || isFinished) return;
    _nextQuestionTimer?.cancel(); // 先取消之前的 Timer
    if (score >= 100) {
      await _completeGame();
      return;
    }

    isLoading = true;
    _hasQuestion = false;
    board.clearSelection();
    loadError = null;
    lastAnswer = null;
    showCorrectAnswer = false;
    notifyListeners();

    final question = await _fetchQuestionSafely();
    if (notifierDisposed) return;
    isLoading = false;
    if (question == null) {
      _notifyIfActive();
      return;
    }
    currentQuestion = question;
    board.generate(question.question);
    _hasQuestion = true;

    notifyListeners();
    unawaited(speak(currentQuestion.question));
  }

  Future<ModelGameWordSearch?> _fetchQuestionSafely() async {
    try {
      return await service.fetchWordSearchQuestion(
        userName,
        gameLevel,
        questionBank: questionBank,
      );
    } catch (error, stackTrace) {
      logger.e(
        'Load word search question failed',
        error: error,
        stackTrace: stackTrace,
      );
      if (!notifierDisposed) loadError = error;
      return null;
    }
  }

  void onSelectCell(LetterCell cell) {
    if (canAnswer && board.select(cell)) notifyListeners();
  }

  void submitSelection() {
    if (!canSubmit) return;
    final selectedWord = board.selectedWord;
    board.completeSelection(
      correct: selectedWord == currentQuestion.searchWord,
    );
    answer(selectedWord);
  }

  void answer(String answer) {
    if (!canAnswer) return;
    final question = currentQuestion;

    lastAnswer = answer;
    answeredCount++;
    final isRightAnswer = answer == question.searchWord;
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
    // 先完成所有狀態變更，再通知畫面，避免收到尚未完成的狀態。
    if (answeredCount >= maxQuestions) {
      _nextQuestionTimer?.cancel();
      isFinished = true;
    } else {
      _nextQuestionTimer = Timer(Duration(seconds: seconds), () {
        unawaited(loadNextQuestion());
      });
    }
    unawaited(_submitAnswerSafely(question, isRightAnswer));
    notifyListeners();
  }

  Future<void> _submitAnswerSafely(
    ModelGameWordSearch question,
    bool isRightAnswer,
  ) async {
    try {
      await service.submitWordSearchAnswer(
        userName: userName,
        questionId: question.questionId,
        answer: question.question,
        isRightAnswer: isRightAnswer,
      );
    } catch (error, stackTrace) {
      logger.e(
        'Submit word search answer failed',
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
    if (notifierDisposed || isLoading || isFinished) return;
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
        'Save word search score failed',
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

  @override
  void dispose() {
    _nextQuestionTimer?.cancel();
    unawaited(_speech.dispose());
    super.dispose();
  }
}
