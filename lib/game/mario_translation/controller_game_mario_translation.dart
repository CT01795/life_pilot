// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:life_pilot/game/mario_translation/model_game_mario_translation.dart';
import 'package:life_pilot/game/service_game.dart';
import 'package:life_pilot/utils/tts/tts_stub.dart'
    if (dart.library.html) 'package:life_pilot/utils/tts/tts_web.dart';

class ControllerGameMarioTranslation extends ChangeNotifier {
  final String userName;
  final ServiceGame service;
  final String gameId;
  final int gameLevel;

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

    currentQuestion =
        await service.fetchMarioTranslationQuestion(userName, gameLevel);

    isLoading = false;
    notifyListeners();
  }

  Map<String, Set<String>> synonyms = {};
  bool isAnswering = false;
  Future<void> answer(String answer) async {
    try {
      if (currentQuestion == null || isAnswering) return;
      isAnswering = true;
      if (synonyms.isEmpty) {
        synonyms = await service.getSynonyms();
      }

      lastAnswer = answer;
      answeredCount++;
      final q = currentQuestion!.question.toLowerCase();
      final normalized = answer.replaceAll(" ", "").toLowerCase();
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
      await service.submitTranslationAnswer(
        userName: userName,
        questionId: currentQuestion!.questionId,
        answer: answer,
        isRightAnswer: isRightAnswer,
      );
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
}
