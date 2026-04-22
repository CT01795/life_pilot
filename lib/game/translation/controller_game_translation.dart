// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:life_pilot/game/translation/model_game_translation.dart';
import 'package:life_pilot/game/service_game.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:life_pilot/utils/tts/tts_stub.dart'
    if (dart.library.html) 'package:life_pilot/utils/tts/tts_web.dart';

class ControllerGameTranslation extends ChangeNotifier {
  final String userName;
  final ServiceGame service;
  final String gameId;
  final int gameLevel;

  ModelGameTranslation? currentQuestion;
  int score = 0; // +1 / -1
  int scoreMinus = 0; // +1 / -1
  bool isFinished = false;
  bool isLoading = false;
  String? lastAnswer; // 使用者選的答案
  bool showCorrectAnswer = false; // 是否要顯示正確答案
  Timer? _nextQuestionTimer; // Timer 控制自動下一題
  int answeredCount = 0;
  int maxQuestions = 10;

  ControllerGameTranslation(
      {required this.userName,
      required this.service,
      required this.gameId, // 初始化
      required this.gameLevel,
      required this.maxQuestions});

  final player = AudioPlayer();

  final Map<String, Uint8List> _audioCache = {};
  Future<void> speak(String text) async {
    if (text.isEmpty) return;

    final containsChinese = RegExp(r'[\u4e00-\u9fff]').hasMatch(text);
    if (kIsWeb) {
      await speakWeb(text);
      return;
    }

    if (_audioCache.containsKey(text)) {
      await player.play(BytesSource(_audioCache[text]!));
      return;
    }
    String url = "";
    if (containsChinese) {
      url =
          "https://translate.google.com/translate_tts?ie=UTF-8&tl=zh&client=tw-ob&q=${Uri.encodeComponent(text.split('/')[0])}";
    } else {
      url =
          "https://translate.google.com/translate_tts?ie=UTF-8&tl=en&client=tw-ob&q=${Uri.encodeComponent(text.split('/')[0])}";
    }

    // 用 http.get 先取得 bytes，並加上 User-Agent
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36'
      },
    );

    if (response.statusCode == 200) {
      _audioCache[text] = response.bodyBytes;
      await player.play(BytesSource(_audioCache[text]!));
    }
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

    currentQuestion =
        await service.fetchTranslationQuestion(userName, gameLevel);

    isLoading = false;
    notifyListeners();
    speak(currentQuestion!.question);
  }

  Map<String, Set<String>> synonyms = {};
  Future<void> answer(String answer) async {
    if (currentQuestion == null || lastAnswer != null) return;

    if (synonyms.isEmpty) {
      synonyms = await service.getSynonyms();
    }

    lastAnswer = answer;
    answeredCount++;
    final q = currentQuestion!.question.toLowerCase();
    final normalized = answer.toLowerCase();
    final isRightAnswer =
        normalized == currentQuestion!.correctAnswer.toLowerCase() ||
            synonyms[q]?.contains(normalized) == true;

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
    notifyListeners();

    // 用 Timer 2 秒後跳下一題
    _nextQuestionTimer = Timer(Duration(seconds: seconds), () {
      loadNextQuestion();
    });

    if (answeredCount >= maxQuestions) {
      isFinished = true;
    }
    unawaited(service.submitTranslationAnswer(
      userName: userName,
      questionId: currentQuestion!.questionId,
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
    if (option == lastAnswer) {
      return option == currentQuestion!.correctAnswer
          ? Color(0xFFC8E6C9)
          : Color(0xFFFFCDD2);
    } else if (option == currentQuestion!.correctAnswer && showCorrectAnswer) {
      return Color(0xFFC8E6C9);
    }
    return Color(0xFFE3F2FD);
  }

  Color getBorderColor(String option) {
    if (lastAnswer == null) return Color(0xFF1976D2);
    if (option == lastAnswer) {
      return option == currentQuestion!.correctAnswer
          ? Color(0xFF388E3C)
          : Color(0xFFD32F2F);
    } else if (option == currentQuestion!.correctAnswer && showCorrectAnswer) {
      return Color(0xFF388E3C);
    }
    return Color(0xFF1976D2);
  }

  Icon? getStatusIcon(String option) {
    if (lastAnswer == null) return null;
    if (option == lastAnswer) {
      return option == currentQuestion!.correctAnswer
          ? Icon(Icons.check_rounded, color: Color(0xFF2E7D32), size: 32)
          : Icon(Icons.clear_rounded, color: Color(0xFFD32F2F), size: 32);
    } else if (option == currentQuestion!.correctAnswer && showCorrectAnswer) {
      return Icon(Icons.check_rounded, color: Color(0xFF2E7D32), size: 32);
    }
    return null;
  }

  @override
  void dispose() {
    _nextQuestionTimer?.cancel();
    super.dispose();
  }
}
