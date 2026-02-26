import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:life_pilot/game/translation/model_game_translation.dart';
import 'package:life_pilot/game/service_game.dart';

class ControllerGameTranslation extends ChangeNotifier {
  final String userName;
  final ServiceGame service;
  final String gameId;

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
  final FlutterTts flutterTts = FlutterTts();

  ControllerGameTranslation({
    required this.userName,
    required this.service,
    required this.gameId, // 初始化
    required this.maxQuestions
  });

  Future<void> speak(String text) async {
    try {
      flutterTts.stop();
    } catch (_) {}
    final containsChinese = RegExp(r'[\u4e00-\u9fff]').hasMatch(text);
    if (containsChinese) {
      await flutterTts.setLanguage("zh-TW");
      await flutterTts.setSpeechRate(0.4);
      await flutterTts.setVolume(1.0);
    } else {
      await flutterTts.setLanguage("en-US");
      await flutterTts.setSpeechRate(0.6);
      await flutterTts.setVolume(1.0);
    }
    flutterTts.speak(text.split('/')[0]);
  }


  Future<void> loadNextQuestion() async {
    _nextQuestionTimer?.cancel(); // 先取消之前的 Timer
    if (score >= 100) {
      isFinished = true;
      await _saveScore();
      notifyListeners();
      return;
    }

    isLoading = true;
    lastAnswer = null;
    showCorrectAnswer = false;
    notifyListeners();

    currentQuestion = await service.fetchTranslationQuestion(userName);

    isLoading = false;
    notifyListeners();
  }

  void answer(String answer) {
    if (currentQuestion == null || lastAnswer != null) return;

    lastAnswer = answer;
    answeredCount++;
    final isRightAnswer = answer == currentQuestion!.correctAnswer 
      || (currentQuestion!.question == "爸爸" && (answer == "father" || answer.toLowerCase() == "daddy" || answer.toLowerCase() == "dad"))
      || (currentQuestion!.question == "沙發" && (answer == "sofa" || answer == "couch"))
      || (currentQuestion!.question == "媽媽" && (answer == "mom" || answer == "mother" || answer.toLowerCase() == "mummy" || answer.toLowerCase() == "mommy"))
      || (currentQuestion!.question == "腳踏車" && (answer == "bike" || answer == "bicycle"))
      || (currentQuestion!.question == "摩托車" && (answer == "motorcycle" || answer == "motorbike"))
      || (currentQuestion!.question == "薯條" && (answer == "fries" || answer == "chips" || answer.replaceAll(" ", '').toLowerCase() == "frenchfries"))
      || (currentQuestion!.question == "腳踏車" && (answer == "bike" || answer == "bicycle"))
      || (currentQuestion!.question == "miss" && (answer == "錯過或想念" || answer == "未婚的女人"));
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
    service.submitTranslationAnswer(
      userName: userName,
      questionId: currentQuestion!.questionId,
      answer: answer,
      isRightAnswer: isRightAnswer,
    );
  }

  Future<void> _saveScore() async {
    await service.saveUserGameScore(
      newUserName: userName,
      newScore: (score + scoreMinus).toDouble(),
      newGameId: gameId, // 使用傳入的 gameId
    );
  }

  Color getButtonColor(String option) {
    if (lastAnswer == null) return Color(0xFFE3F2FD);
    if (option == lastAnswer) {
      return option == currentQuestion!.correctAnswer ? Color(0xFFC8E6C9) : Color(0xFFFFCDD2);
    } else if (option == currentQuestion!.correctAnswer && showCorrectAnswer) {
      return Color(0xFFC8E6C9);
    }
    return Color(0xFFE3F2FD);
  }

  Color getBorderColor(String option) {
    if (lastAnswer == null) return Color(0xFF1976D2);
    if (option == lastAnswer) {
      return option == currentQuestion!.correctAnswer ? Color(0xFF388E3C) : Color(0xFFD32F2F);
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
    flutterTts.stop();
    super.dispose();
  }
}
