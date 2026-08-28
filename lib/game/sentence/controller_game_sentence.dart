import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:life_pilot/game/google_tts_audio.dart';
import 'package:life_pilot/game/sentence/model_game_sentence.dart';
import 'package:life_pilot/game/service_game.dart';
import 'package:life_pilot/utils/safe_change_notifier.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:life_pilot/utils/tts/tts_stub.dart'
    if (dart.library.html) 'package:life_pilot/utils/tts/tts_web.dart';
import 'package:uuid/uuid.dart';

class ControllerGameSentence extends SafeChangeNotifier {
  final String userName;
  final ServiceGame service;
  final String gameId;
  final int gameLevel;
  final String questionBank;
  final GoogleTtsAudio _ttsAudio = GoogleTtsAudio();
  ModelGameSentence? currentQuestion;
  bool isFinished = false;
  bool isLoading = false;
  Object? loadError;
  bool _isDisposed = false;
  String? lastAnswer; // 使用者選的答案
  bool showCorrectAnswer = false; // 是否要顯示正確答案
  List<WordItem> options = []; // 底部文字方塊
  List<WordItem?> answerSlots = []; // 上方拖曳區
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
        logger.e('Save sentence score failed',
            error: error, stackTrace: stackTrace);
        if (!_isDisposed) loadError = error;
      }
      if (!_isDisposed) {
        isLoading = false;
        _notifyIfActive();
      }
      return;
    }

    lastAnswer = null;
    isRightAnswer = null;
    showCorrectAnswer = false;
    currentQuestion = await _fetchQuestionSafely();
    if (_isDisposed) return;
    // 🔹 初始化答案槽 & 選項
    if (currentQuestion != null) {
      answerSlots = List.filled(currentQuestion!.options.length, null);
      options = List.generate(currentQuestion!.options.length,
          (i) => WordItem(id: Uuid().v4(), text: currentQuestion!.options[i]))
        ..shuffle();
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
      logger.e('Load sentence question failed',
          error: error, stackTrace: stackTrace);
      if (!_isDisposed) loadError = error;
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

  // 🔹 將單字移動到答案槽
  void moveWordToSlot(int slotIndex, WordItem word) {
    final indexInUpper = answerSlots.indexWhere((e) => e?.id == word.id);
    if (indexInUpper != -1) {
      // 上方交換
      final temp = answerSlots[slotIndex];
      answerSlots[slotIndex] = word;
      answerSlots[indexInUpper] = temp;
    } else {
      // 下方 → 上方
      if (answerSlots[slotIndex] != null) {
        options.add(answerSlots[slotIndex]!);
      }
      answerSlots[slotIndex] = word;
      final index = options.indexWhere((e) => e.id == word.id);
      if (index != -1) options.removeAt(index);
    }
    _notifyIfActive();
  }

  void removeWordFromSlot(int slotIndex) {
    final word = answerSlots[slotIndex];
    if (word != null) {
      options.add(word);
      answerSlots[slotIndex] = null;
      _notifyIfActive();
    }
  }

  // 🔹 答題判斷
  bool get canCheckAnswer =>
      currentQuestion != null &&
      lastAnswer == null &&
      answerSlots.isNotEmpty &&
      answerSlots.every((word) => word != null);

  bool checkAnswer() {
    if (!canCheckAnswer) return false;

    final userAnswer = currentQuestion!.buildUserAnswer(answerSlots);

    lastAnswer = userAnswer;
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
    _notifyIfActive();

    // 用 Timer 2 秒後跳下一題
    _nextQuestionTimer = Timer(Duration(seconds: seconds), () {
      unawaited(loadNextQuestion());
    });

    unawaited(_submitAnswerSafely(
      questionId: currentQuestion!.questionId,
      answer: userAnswer,
      isRightAnswer: isRightAnswer ?? false,
    ));

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
      logger.e('Submit sentence answer failed',
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
