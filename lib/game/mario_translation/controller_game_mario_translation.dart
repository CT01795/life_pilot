// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:life_pilot/game/google_tts_audio.dart';
import 'package:life_pilot/game/mario_translation/model_game_mario_translation.dart';
import 'package:life_pilot/game/service_game.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:life_pilot/utils/tts/tts_stub.dart'
    if (dart.library.html) 'package:life_pilot/utils/tts/tts_web.dart';

class ControllerGameMarioTranslation extends ChangeNotifier {
  final String userName;
  final ServiceGame service;
  final String gameId;
  final int gameLevel;
  final String questionBank;

  ModelGameMarioTranslation? currentQuestion;
  int score = 0; // +1 / -1
  int scoreMinus = 0; // +1 / -1
  bool isFinished = false;
  bool isLoading = false;
  String? lastAnswer; // 使用者選的答案
  bool showCorrectAnswer = false; // 是否要顯示正確答案
  int answeredCount = 0;
  int maxQuestions = 10;

  ControllerGameMarioTranslation(
      {required this.userName,
      required this.service,
      required this.gameId, // 初始化
      required this.gameLevel,
      this.questionBank = 'admin',
      required this.maxQuestions});

  final GoogleTtsAudio _ttsAudio = GoogleTtsAudio();
  Future<void> speak(String text) async {
    try {
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
    } catch (error, stackTrace) {
      logger.e('Mario translation audio failed',
          error: error, stackTrace: stackTrace);
    }
  }

  Future<void> loadNextQuestion() async {
    if (score >= 100 || score < -20) {
      isFinished = true;
      await _saveScore(score >= 100);
      notifyListeners();
      return;
    }

    isLoading = true;
    lastAnswer = null;
    showCorrectAnswer = false;
    notifyListeners();

    currentQuestion = await service.fetchMarioTranslationQuestion(
      userName,
      gameLevel,
      questionBank: questionBank,
    );

    isLoading = false;
    notifyListeners();
    speak(currentQuestion!.question);
  }

  Map<String, Set<String>> synonyms = {};
  bool isAnswering = false;
  Future<bool> answer(String answer) async {
    try {
      if (currentQuestion == null || isAnswering) return false;
      isAnswering = true;
      if (synonyms.isEmpty) {
        synonyms = await _loadSynonymsSafely();
      }

      lastAnswer = answer;
      answeredCount++;
      final q = currentQuestion!.question.toLowerCase();
      final normalized = answer.toLowerCase();
      final isRightAnswer =
          normalized == currentQuestion!.correctAnswer.toLowerCase() ||
              synonyms[q]?.contains(normalized) == true;
      if (isRightAnswer) {
        score += 4;
      } else {
        score -= 4;
        scoreMinus -= 4;
        showCorrectAnswer = true; // 顯示正確答案
      }
      notifyListeners();

      if (answeredCount >= maxQuestions) {
        isFinished = true;
      }
      unawaited(_submitAnswerSafely(
        questionId: currentQuestion!.questionId,
        answer: answer,
        isRightAnswer: isRightAnswer,
      ));
      return isRightAnswer;
    } finally {
      isAnswering = false;
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

  @override
  void dispose() {
    _ttsAudio.dispose();
    super.dispose();
  }

  Future<Map<String, Set<String>>> _loadSynonymsSafely() async {
    try {
      return await service.getSynonyms();
    } catch (error, stackTrace) {
      logger.e('Load Mario translation synonyms failed',
          error: error, stackTrace: stackTrace);
      return {};
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
      logger.e('Submit Mario translation answer failed',
          error: error, stackTrace: stackTrace);
    }
  }
}
