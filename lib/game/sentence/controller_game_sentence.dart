import 'dart:async';

import 'package:life_pilot/game/sentence/model_game_sentence.dart';
import 'package:life_pilot/utils/value_parser.dart';
import 'package:life_pilot/game/service_game.dart';
import 'package:life_pilot/game/service_game_speech.dart';
import 'package:life_pilot/game/sentence/model_sentence_arrangement.dart';
import 'package:life_pilot/utils/safe_change_notifier.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:uuid/uuid.dart';

class ControllerGameSentence extends SafeChangeNotifier {
  final String userName;
  final ServiceGame service;
  final String gameId;
  final int gameLevel;
  final String questionBank;
  final ServiceGameSpeech _speech;
  final _arrangement = ModelSentenceArrangement();
  final int maxQuestions;
  int _answeredCount = 0;
  int get answeredCount => _answeredCount;
  ModelGameSentence? currentQuestion;
  bool isFinished = false;
  bool isLoading = false;
  Object? loadError;
  String? lastAnswer; // 使用者選的答案
  bool showCorrectAnswer = false; // 是否要顯示正確答案
  List<WordItem> get options => _arrangement.options;
  List<WordItem?> get answerSlots => _arrangement.slots;
  bool? isRightAnswer;

  int score = 0; // +1 / -1
  int scoreMinus = 0; // +1 / -1
  Timer? _nextQuestionTimer; // Timer 控制自動下一題

  ControllerGameSentence({
    required this.userName,
    required this.service,
    required this.gameId, // 初始化
    required this.gameLevel,
    this.questionBank = 'admin',
    this.maxQuestions = 999,
    ServiceGameSpeech? speech,
  }) : _speech = speech ?? ServiceGameSpeech();

  Future<void> loadNextQuestion() async {
    if (notifierDisposed || isLoading || isFinished) return;
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
          'Save sentence score failed',
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

    lastAnswer = null;
    isRightAnswer = null;
    showCorrectAnswer = false;
    final question = await _fetchQuestionSafely();
    if (notifierDisposed) return;
    currentQuestion = question;
    // 🔹 初始化答案槽 & 選項
    if (currentQuestion != null) {
      final words = List.generate(
        currentQuestion!.options.length,
        (i) => WordItem(id: Uuid().v4(), text: currentQuestion!.options[i]),
      )..shuffle();
      _arrangement.reset(words);
    } else {
      _arrangement.reset(const []);
    }

    isLoading = false;
    _notifyIfActive();
    if (currentQuestion != null) {
      unawaited(_speakSafely(currentQuestion!.correctAnswer));
    }
  }

  Future<ModelGameSentence?> _fetchQuestionSafely() async {
    try {
      return await service.fetchSentenceQuestion(
        userName,
        gameLevel,
        questionBank: questionBank,
      );
    } catch (error, stackTrace) {
      logger.e(
        'Load sentence question failed',
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
      logger.e('Sentence audio failed', error: error, stackTrace: stackTrace);
    }
  }

  Future<void> speak(String text) async {
    if (notifierDisposed) return;
    await _speech.speak(text);
  }

  bool get canArrange =>
      !notifierDisposed &&
      !isLoading &&
      !isFinished &&
      currentQuestion != null &&
      lastAnswer == null;

  bool canMoveWordToSlot(int index, WordItem word) =>
      canArrange && _arrangement.canMoveTo(index, word);

  bool canReturnWord(WordItem word) =>
      canArrange && _arrangement.slotOf(word) != null;

  void moveWordToSlot(int index, WordItem word) {
    if (canArrange && _arrangement.moveTo(index, word)) _notifyIfActive();
  }

  void removeWordFromSlot(int index) {
    if (canArrange && _arrangement.removeAt(index)) _notifyIfActive();
  }

  void returnWordToBank(WordItem word) {
    if (!canArrange) return;
    final index = _arrangement.slotOf(word);
    if (index != null) removeWordFromSlot(index);
  }

  bool get canCheckAnswer => canArrange && _arrangement.isComplete;

  bool checkAnswer() {
    if (!canCheckAnswer) return false;

    final userAnswer = currentQuestion!.buildUserAnswer(answerSlots);

    lastAnswer = userAnswer;
    _answeredCount++;
    isRightAnswer = userAnswer == currentQuestion!.correctAnswer;
    int seconds = 1;
    if (isRightAnswer == true) {
      score += 4;
      seconds = 1;
    } else {
      score -= 4;
      scoreMinus -= 4;
      seconds = 2;
      showCorrectAnswer = true; // 顯示正確答案
    }
    if (_answeredCount >= maxQuestions) {
      isFinished = true;
      _nextQuestionTimer?.cancel();
    } else {
      _nextQuestionTimer = Timer(Duration(seconds: seconds), () {
        unawaited(loadNextQuestion());
      });
    }
    _notifyIfActive();

    unawaited(
      _submitAnswerSafely(
        questionId: currentQuestion!.questionId,
        answer: userAnswer,
        isRightAnswer: isRightAnswer ?? false,
      ),
    );

    return true;
  }

  Future<void> _submitAnswerSafely({
    required String questionId,
    required String answer,
    required bool isRightAnswer,
  }) async {
    try {
      await service.submitSentenceAnswer(
        userName: userName,
        questionId: questionId,
        answer: answer,
        isRightAnswer: isRightAnswer,
      );
    } catch (error, stackTrace) {
      logger.e(
        'Submit sentence answer failed',
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
