import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/game/service_game.dart';
import 'package:life_pilot/game/translation/controller_game_translation.dart';
import 'package:life_pilot/game/translation/model_game_translation.dart';
import 'package:life_pilot/game/translation/service_translation_speech.dart';

ModelGameTranslation question() => ModelGameTranslation(
  questionId: 'q',
  question: '你好',
  group: '中翻英',
  options: ['Hello', 'Hi', 'Bye'],
  correctAnswer: 'Hello',
);

class Speech extends ServiceTranslationSpeech {
  final calls = <(String, String, bool)>[];
  int disposals = 0;
  @override
  Future<void> speak(String text, String group, bool isQuestion) async {
    calls.add((text, group, isQuestion));
  }

  @override
  Future<void> dispose() async {
    disposals++;
  }
}

class Service extends ServiceGame {
  int loads = 0;
  int synonymLoads = 0;
  int saves = 0;
  bool fail = false;
  Completer<ModelGameTranslation>? pendingQuestion;
  Completer<Set<String>>? pendingSynonyms;
  final submissions = <(String, String, bool)>[];
  @override
  Future<ModelGameTranslation> fetchTranslationQuestion(
    String userName,
    int level,
    String gameName, {
    String questionBank = 'admin',
  }) async {
    loads++;
    if (fail) throw StateError('offline');
    return pendingQuestion == null ? question() : pendingQuestion!.future;
  }

  @override
  Future<Set<String>> getSynonyms(String question) async {
    synonymLoads++;
    return pendingSynonyms == null ? {'hi'} : pendingSynonyms!.future;
  }

  @override
  Future<void> submitTranslationAnswer({
    required String userName,
    required String questionId,
    required String answer,
    required bool isRightAnswer,
  }) async {
    submissions.add((questionId, answer, isRightAnswer));
  }

  @override
  Future<void> saveUserGameScore({
    required String newUserName,
    required double newScore,
    required String? newGameId,
    bool? newIsPass,
  }) async {
    saves++;
  }
}

void main() {
  late Service service;
  late Speech speech;
  late ControllerGameTranslation controller;
  setUp(() {
    service = Service();
    speech = Speech();
    controller = ControllerGameTranslation(
      userName: 'user',
      service: service,
      gameId: 'game',
      gameLevel: 1,
      gameName: 'Translation (CH-EN)',
      maxQuestions: 10,
      speech: speech,
    );
  });
  tearDown(() {
    if (!controller.notifierDisposed) controller.dispose();
  });

  test('loads once and forwards translation direction to speech', () async {
    service.pendingQuestion = Completer();
    final pending = controller.loadNextQuestion();
    await controller.loadNextQuestion();
    expect(service.loads, 1);
    expect(controller.canAnswer, false);
    service.pendingQuestion!.complete(question());
    await pending;
    expect(controller.canAnswer, true);
    expect(speech.calls, [('你好', '中翻英', true)]);
  });

  test('standard answer skips synonym request and duplicate scoring', () async {
    await controller.loadNextQuestion();
    await controller.answer('HELLO');
    await controller.answer('Hello');
    expect(service.synonymLoads, 0);
    expect(controller.score, 4);
    expect(controller.answeredCount, 1);
    expect(service.submissions, [('q', 'HELLO', true)]);
    expect(controller.feedbackFor('HELLO'), TranslationOptionFeedback.correct);
  });

  test('accepted synonym shows correct feedback', () async {
    await controller.loadNextQuestion();
    await controller.answer('Hi');
    expect(controller.score, 4);
    expect(controller.feedbackFor('Hi'), TranslationOptionFeedback.correct);
    expect(controller.showCorrectAnswer, false);
  });

  test('wrong answer preserves penalty and reveals standard answer', () async {
    await controller.loadNextQuestion();
    await controller.answer('Bye');
    expect(controller.score, -4);
    expect(controller.scoreMinus, -4);
    expect(controller.feedbackFor('Bye'), TranslationOptionFeedback.incorrect);
    expect(controller.feedbackFor('Hello'), TranslationOptionFeedback.correct);
    expect(controller.feedbackFor('Hi'), TranslationOptionFeedback.neutral);
  });

  test(
    'pending synonym lookup blocks next question and repeated answers',
    () async {
      await controller.loadNextQuestion();
      service.pendingSynonyms = Completer();
      final pending = controller.answer('Hi');
      await controller.answer('Bye');
      await controller.loadNextQuestion();
      expect(service.loads, 1);
      expect(service.synonymLoads, 1);
      service.pendingSynonyms!.complete({'hi'});
      await pending;
      expect(controller.answeredCount, 1);
    },
  );

  test(
    'late question cannot update disposed controller or play audio',
    () async {
      service.pendingQuestion = Completer();
      final pending = controller.loadNextQuestion();
      controller.dispose();
      service.pendingQuestion!.complete(question());
      await pending;
      expect(controller.currentQuestion, null);
      expect(speech.calls, isEmpty);
      expect(speech.disposals, 1);
    },
  );

  test('late synonyms cannot score or submit after disposal', () async {
    await controller.loadNextQuestion();
    service.pendingSynonyms = Completer();
    final pending = controller.answer('Hi');
    controller.dispose();
    service.pendingSynonyms!.complete({'hi'});
    await pending;
    expect(controller.score, 0);
    expect(controller.answeredCount, 0);
    expect(service.submissions, isEmpty);
    await controller.answer('Hello');
    expect(controller.score, 0);
  });

  test('failed load can retry without retaining stale question', () async {
    await controller.loadNextQuestion();
    service.fail = true;
    await controller.loadNextQuestion();
    expect(controller.loadError, isNotNull);
    expect(controller.currentQuestion, null);
    expect(controller.canAnswer, false);
    service.fail = false;
    await controller.retry();
    expect(controller.loadError, null);
    expect(controller.canAnswer, true);
  });

  test('finished game cannot fetch or save again', () async {
    controller.score = 100;
    await controller.loadNextQuestion();
    await controller.loadNextQuestion();
    await controller.retry();
    expect(controller.isFinished, true);
    expect(service.saves, 1);
    expect(service.loads, 0);
  });

  test('synonyms are reused within this game', () async {
    await controller.loadNextQuestion();
    await controller.answer('Hi');
    await controller.loadNextQuestion();
    await controller.answer('Hi');
    expect(service.synonymLoads, 1);
    expect(controller.score, 8);
  });
}
