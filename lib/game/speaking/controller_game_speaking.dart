import 'dart:async';

import 'package:life_pilot/game/speaking/model_game_speaking.dart';
import 'package:life_pilot/game/service_game.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:life_pilot/utils/tts/tts_stub.dart'
    if (dart.library.html) 'package:life_pilot/utils/tts/tts_web.dart';

class ControllerGameSpeaking extends ChangeNotifier {
  final String userName;
  final ServiceGame service;
  final String gameId;
  final int gameLevel;
  final player = AudioPlayer();

  Map<String, Uint8List> audioCache = {};
  ModelGameSpeaking? currentQuestion;
  int score = 0; // +1 / -1
  int scoreMinus = 0; // +1 / -1
  bool isFinished = false;
  bool isLoading = false;
  Timer? _nextQuestionTimer; // Timer 控制自動下一題

  int repeatCounts = 0;
  bool? isRightAnswer;
  bool isBusy = false;

  ControllerGameSpeaking({
    required this.userName,
    required this.service,
    required this.gameId, // 初始化
    required this.gameLevel,
  });

  Future<void> loadNextQuestion() async {
    _nextQuestionTimer?.cancel(); // 先取消之前的 Timer
    if (score >= 100) {
      isFinished = true;
      await _saveScore(score >= 100);
      notifyListeners();
      return;
    }

    isLoading = true;
    notifyListeners();

    currentQuestion = await service.fetchSpeakingQuestion(userName, gameLevel);

    isLoading = false;
    notifyListeners();
    speak(currentQuestion!.correctAnswer);
  }

  Future<void> speak(String text) async {
    if (text.isEmpty) return;

    final containsChinese = RegExp(r'[\u4e00-\u9fff]').hasMatch(text);
    if (kIsWeb) {
      await speakWeb(text);
      return;
    }

    if (audioCache.containsKey(text)) {
      await player.play(BytesSource(audioCache[text]!));
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
      audioCache[text] = response.bodyBytes;
      await player.play(BytesSource(audioCache[text]!));
    }
  }

  void answer(String answer) {
    if (currentQuestion == null) return;
    if (answer.isEmpty) {
      return;
    }
    repeatCounts++;

    String right = currentQuestion!.correctAnswer.toLowerCase();
    String my = answer.toLowerCase();
    isRightAnswer = right == my ||
        right.replaceAll(" ", '').replaceAll(".", '') ==
            my.replaceAll(" ", '').replaceAll(".", '');
    int seconds = 1;
    if (isRightAnswer == true) {
      score += 4;
      seconds = 1;
    } else {
      seconds = 2;
    }

    if (isRightAnswer != true && repeatCounts < 2) {
      notifyListeners();
      return;
    } else if (isRightAnswer != true && repeatCounts == 2) {
      score += 4;
    }

    isBusy = true;
    notifyListeners();

    // 用 Timer 2 秒後跳下一題
    _nextQuestionTimer = Timer(Duration(seconds: seconds), () {
      repeatCounts = 0;
      isBusy = false;
      loadNextQuestion();
    });

    unawaited(service.submitSpeakingAnswer(
      userName: userName,
      questionId: currentQuestion!.questionId,
      answer: currentQuestion!.correctAnswer,
      isRightAnswer: true,
    ));
    notifyListeners();
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
