// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:life_pilot/game/google_tts_audio.dart';
import 'package:life_pilot/game/service_game.dart';
import 'package:life_pilot/game/social/model_game_social.dart';
import 'package:life_pilot/utils/tts/tts_stub.dart'
    if (dart.library.html) 'package:life_pilot/utils/tts/tts_web.dart';

class ControllerGameSocial extends ChangeNotifier {
  final String userName;
  final ServiceGame service;
  final String gameId;
  final int gameLevel;

  ModelGameSocial? currentQuestion;
  int score = 0; // +1 / -1
  int scoreMinus = 0; // +1 / -1
  bool isFinished = false;
  bool isLoading = false;
  String? lastAnswer; // 使用者選的答案
  bool showCorrectAnswer = false; // 是否要顯示正確答案
  Timer? _nextQuestionTimer; // Timer 控制自動下一題
  int answeredCount = 0;
  int maxQuestions = 10;

  ControllerGameSocial(
      {required this.userName,
      required this.service,
      required this.gameId, // 初始化
      required this.gameLevel,
      required this.maxQuestions});

  final GoogleTtsAudio _ttsAudio = GoogleTtsAudio();
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

  Future<void> loadNextQuestion() async {
    _nextQuestionTimer?.cancel(); // 先取消之前的 Timer
    if (score >= 100) {
      isFinished = true;
      await _saveScore(score >= 100);
      notifyListeners();
      return;
    }

    isLoading = true;
    lastAnswer = null;
    showCorrectAnswer = false;
    notifyListeners();

    currentQuestion = await service.fetchSocialQuestion(userName, gameLevel);

    isLoading = false;
    notifyListeners();
    speak(currentQuestion!.scene);
  }

  Map<String, Set<String>> synonyms = {};
  Future<void> answer(String answer) async {
    if (currentQuestion == null || lastAnswer != null) return;

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
    notifyListeners();

    // 用 Timer 2 秒後跳下一題
    _nextQuestionTimer = Timer(Duration(seconds: seconds), () {
      loadNextQuestion();
    });

    if (answeredCount >= maxQuestions) {
      isFinished = true;
    }
    unawaited(service.submitSocialAnswer(
      userName: userName,
      questionId: currentQuestion!.id,
      answer: answer,
      isRightAnswer: isRightAnswer,
    ));
  }

  Future<void> _saveScore(bool isPass) async {
    await service.saveUserGameScore(
      newUserName: userName,
      newScore: (score + scoreMinus).toDouble(),
      newGameId: gameId, // 使用傳入的 gameId
      newIsPass: isPass,
    );
  }

  Color getButtonColor(String option) {
    if (lastAnswer == null) return Color(0xFFE3F2FD);
    int inputScore = getScore(option);
    if (option == lastAnswer) {
      return inputScore >= 0 ? Color(0xFFC8E6C9) : Color(0xFFFFCDD2);
    } else if (inputScore >= 0 && showCorrectAnswer) {
      return Color(0xFFC8E6C9);
    }
    return Color(0xFFE3F2FD);
  }

  int getScore(String option) {
    for (int i = 0; i < currentQuestion!.options.length; i++) {
      if (currentQuestion!.options[i] == option) {
        return currentQuestion!.scores[i];
      }
    }
    return -1;
  }

  Color getBorderColor(String option) {
    if (lastAnswer == null) return Color(0xFF1976D2);
    int inputScore = getScore(option);
    if (option == lastAnswer) {
      return inputScore >= 0 ? Color(0xFF388E3C) : Color(0xFFD32F2F);
    } else if (inputScore >= 0 && showCorrectAnswer) {
      return Color(0xFF388E3C);
    }
    return Color(0xFF1976D2);
  }

  Icon? getStatusIcon(String option) {
    if (lastAnswer == null) return null;
    int inputScore = getScore(option);
    if (option == lastAnswer) {
      return inputScore >= 0
          ? Icon(Icons.check_rounded, color: Color(0xFF2E7D32), size: 32)
          : Icon(Icons.clear_rounded, color: Color(0xFFD32F2F), size: 32);
    } else if (inputScore >= 0 && showCorrectAnswer) {
      return Icon(Icons.check_rounded, color: Color(0xFF2E7D32), size: 32);
    }
    return null;
  }

  @override
  void dispose() {
    _nextQuestionTimer?.cancel();
    _ttsAudio.dispose();
    super.dispose();
  }
}
