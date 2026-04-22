import 'dart:async';

import 'package:life_pilot/game/grammar/model_game_grammar.dart';
import 'package:life_pilot/game/service_game.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:life_pilot/utils/tts/tts_stub.dart'
    if (dart.library.html) 'package:life_pilot/utils/tts/tts_web.dart';

class ControllerGameGrammar extends ChangeNotifier {
  final String userName;
  final ServiceGame service;
  final String gameId;
  final int gameLevel;
  final ModelGameGrammar model;
  final player = AudioPlayer();

  Map<String, Uint8List> audioCache = {};
  bool? isRightAnswer;
  int answeredCount = 0; // 紀錄答了幾題

  ModelGameGrammarQuestion? currentQuestion;
  bool isFinished = false;
  bool isLoading = false;
  bool showCorrectAnswer = false; // 是否要顯示正確答案
  Timer? _nextQuestionTimer; // Timer 控制自動下一題

  ControllerGameGrammar({
    required this.userName,
    required this.service,
    required this.gameId, // 初始化
    required this.gameLevel,
    required this.model,
  });

  Future<void> startBattle(int level) async {
    answeredCount = 0;
    model.monster = ModelGameGrammarMonster('Monster', 50 + level * 10, 10);
    await loadNextQuestion();
  }

  Future<void> loadNextQuestion() async {
    isRightAnswer = null;
    _nextQuestionTimer?.cancel(); // 先取消之前的 Timer
    if (model.monster!.hp <= 0 || model.player.hp <= 0) {
      //isBattleOver
      isFinished = true;
      notifyListeners();
      await _saveScore(model.player.hp >= 100);
      return;
    }

    isLoading = true;
    showCorrectAnswer = false;
    notifyListeners();

    currentQuestion = await service.fetchGrammarQuestion(userName, gameLevel);
    currentQuestion?.options.shuffle();
    model.currentQuestion = currentQuestion;

    isLoading = false;
    notifyListeners();
    speak(currentQuestion!.question
        .replaceAll("______", currentQuestion!.correctAnswer)
        .replaceAll("<-->", ","));
  }

  Future<void> speak(String text) async {
    if (text.isEmpty) return;

    if (kIsWeb) {
      await speakWeb(text);
      return;
    }

    if (audioCache.containsKey(text)) {
      await player.play(BytesSource(audioCache[text]!));
      return;
    }

    final url =
        "https://translate.google.com/translate_tts?ie=UTF-8&tl=en&client=tw-ob&q=${Uri.encodeComponent(text.split('/')[0])}";
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

  Future<void> answer(String answer) async {
    if (currentQuestion == null || showCorrectAnswer) return;
    answeredCount++;
    isRightAnswer = answer == currentQuestion!.correctAnswer;
    if (isRightAnswer ?? false) {
      model.monster!.hp -= model.player.attack;
    } else {
      model.player.hp -= model.monster!.attack;
      showCorrectAnswer = true; // 顯示正確答案
    }
    notifyListeners();

    // async submitAnswer 不阻塞 UI
    unawaited(service.submitGrammarAnswer(
      userName: userName,
      questionId: currentQuestion!.questionId,
      answer: answer,
      isRightAnswer: isRightAnswer ?? false,
    ));

    final delay = (isRightAnswer ?? false) ? 1 : 2;
    _nextQuestionTimer = Timer(Duration(seconds: delay), () {
      loadNextQuestion();
    });
  }

  Future<void> _saveScore(bool isPass) async {
    await service.saveUserGameScore(
      newUserName: userName,
      newScore: model.player.hp.toDouble(),
      newGameId: gameId, // 使用傳入的 gameId
      newIsPass: isPass,
    );
  }

  @override
  void dispose() {
    _nextQuestionTimer?.cancel();
    super.dispose();
  }
}
