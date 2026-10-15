import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/game/grammar/controller_game_grammar.dart';
import 'package:life_pilot/game/grammar/model_game_grammar.dart';
import 'package:life_pilot/game/service_game.dart';
import 'package:life_pilot/game/service_game_speech.dart';

ModelGameGrammarQuestion question({List<String>? options}) =>
    ModelGameGrammarQuestion(
      questionId: 'q',
      question: 'I ______ happy<-->today',
      options: options ?? ['am', 'is', 'are'],
      correctAnswer: 'am',
      type: 'grammar',
    );

class Speech extends ServiceGameSpeech {
  final texts = <String>[];
  int disposals = 0;
  @override
  Future<void> speakEnglish(String text) async {
    texts.add(text);
  }

  @override
  Future<void> dispose() async {
    disposals++;
  }
}

class Service extends ServiceGame {
  int loads = 0;
  bool fail = false;
  bool failSave = false;
  final source = question();
  Completer<ModelGameGrammarQuestion>? pending;
  final submissions = <(String, String, bool)>[];
  final saves = <(double, bool?)>[];
  @override
  Future<ModelGameGrammarQuestion> fetchGrammarQuestion(
    String userName,
    int level, {
    String questionBank = 'admin',
  }) async {
    loads++;
    if (fail) throw StateError('offline');
    return pending == null ? source : pending!.future;
  }

  @override
  Future<void> submitGrammarAnswer({
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
    if (failSave) throw StateError('save failed');
    saves.add((newScore, newIsPass));
  }
}

void main() {
  group('grammar battle model', () {
    test('question owns immutable options and completed speech text', () {
      final options = ['am', 'is'];
      final q = question(options: options);
      options.clear();
      expect(q.options, ['am', 'is']);
      expect(() => q.options.clear(), throwsUnsupportedError);
      expect(q.spokenQuestion, 'I am happy,today');
    });
    test('cannot answer before a battle or a question', () {
      final model = ModelGameGrammar();
      expect(model.answer('am'), null);
      model.startBattle(1);
      expect(model.answer('am'), null);
      expect(model.answeredCount, 0);
    });
    test('correct answer damages monster only once', () {
      final model = ModelGameGrammar()..startBattle(1);
      model.currentQuestion = question();
      expect(model.answer('am'), true);
      expect(model.monster!.hp, 40);
      expect(model.player.hp, 100);
      expect(model.answer('am'), null);
      expect(model.answeredCount, 1);
    });
    test('wrong answer damages player and next question clears feedback', () {
      final model = ModelGameGrammar()..startBattle(1);
      model.currentQuestion = question();
      expect(model.answer('is'), false);
      expect(model.player.hp, 90);
      expect(model.monster!.hp, 60);
      model.prepareQuestion();
      expect(model.isRightAnswer, null);
      expect(model.currentQuestion, null);
      expect(model.answeredCount, 1);
    });
    test('battle over rejects answers and restart resets battle state', () {
      final model = ModelGameGrammar()..startBattle(1);
      model.currentQuestion = question();
      model.player.hp = 0;
      expect(model.isBattleOver, true);
      expect(model.answer('am'), null);
      model.startBattle(2);
      expect(model.player.hp, 100);
      expect(model.monster!.hp, 70);
      expect(model.isBattleOver, false);
      expect(model.answeredCount, 0);
    });
  });

  late Service service;
  late Speech speech;
  late ControllerGameGrammar controller;
  setUp(() {
    service = Service();
    speech = Speech();
    controller = ControllerGameGrammar(
      userName: 'user',
      service: service,
      gameId: 'game',
      gameLevel: 1,
      model: ModelGameGrammar(),
      speech: speech,
    );
  });
  tearDown(() {
    if (!controller.notifierDisposed) controller.dispose();
  });

  test('load without battle is safe', () async {
    await controller.loadNextQuestion();
    await controller.answer('am');
    expect(service.loads, 0);
    expect(controller.canAnswer, false);
  });
  test('loading is deduplicated and service options are not mutated', () async {
    service.pending = Completer();
    final pending = controller.startBattle(1);
    await controller.startBattle(2);
    await controller.loadNextQuestion();
    await controller.answer('am');
    expect(service.loads, 1);
    expect(controller.model.monster!.hp, 60);
    service.pending!.complete(service.source);
    await pending;
    expect(service.source.options, ['am', 'is', 'are']);
    expect(
      controller.currentQuestion!.options,
      unorderedEquals(service.source.options),
    );
    expect(speech.texts, ['I am happy,today']);
  });
  test('correct answer submits once and prevents repeated damage', () async {
    await controller.startBattle(1);
    await controller.answer('am');
    await controller.answer('is');
    expect(controller.model.monster!.hp, 40);
    expect(controller.answeredCount, 1);
    expect(service.submissions, [('q', 'am', true)]);
  });
  test('wrong answer preserves penalty and correct answer display', () async {
    await controller.startBattle(1);
    await controller.answer('is');
    expect(controller.model.player.hp, 90);
    expect(controller.showCorrectAnswer, true);
    expect(service.submissions, [('q', 'is', false)]);
  });
  test('late load cannot change disposed model or play audio', () async {
    service.pending = Completer();
    final pending = controller.startBattle(1);
    controller.dispose();
    service.pending!.complete(question());
    await pending;
    await controller.answer('am');
    await controller.speak('test');
    expect(controller.currentQuestion, null);
    expect(controller.answeredCount, 0);
    expect(speech.texts, isEmpty);
    expect(speech.disposals, 1);
  });
  test('failed load clears old question and supports retry', () async {
    await controller.startBattle(1);
    service.fail = true;
    await controller.loadNextQuestion();
    expect(controller.currentQuestion, null);
    expect(controller.loadError, isNotNull);
    expect(controller.canAnswer, false);
    service.fail = false;
    await controller.loadNextQuestion();
    expect(controller.loadError, null);
    expect(controller.canAnswer, true);
  });
  test('battle completion saves once with existing pass rule', () async {
    await controller.startBattle(1);
    controller.model.monster!.hp = 0;
    await controller.loadNextQuestion();
    await controller.loadNextQuestion();
    expect(controller.isFinished, true);
    expect(service.saves, [(100.0, true)]);
    expect(service.loads, 1);
  });
  test('score save failure can retry without changing battle score', () async {
    await controller.startBattle(1);
    controller.model.player.hp = 0;
    service.failSave = true;
    await controller.loadNextQuestion();
    expect(controller.isFinished, false);
    expect(controller.loadError, isNotNull);
    service.failSave = false;
    await controller.loadNextQuestion();
    expect(controller.isFinished, true);
    expect(service.saves, [(0.0, false)]);
  });
  test('question limit is enforced by controller without a view', () async {
    controller.dispose();
    controller = ControllerGameGrammar(
      userName: 'user',
      service: service,
      gameId: 'game',
      gameLevel: 1,
      model: ModelGameGrammar(),
      maxQuestions: 1,
      speech: Speech(),
    );
    await controller.startBattle(1);
    await controller.answer('am');
    expect(controller.isFinished, true);
    expect(controller.canAnswer, false);
    await controller.loadNextQuestion();
    expect(service.loads, 1);
    expect(service.submissions.length, 1);
  });
  testWidgets('timer advances correct answer after one second', (tester) async {
    await controller.startBattle(1);
    await controller.answer('am');
    await tester.pump(const Duration(milliseconds: 999));
    expect(service.loads, 1);
    await tester.pump(const Duration(milliseconds: 1));
    expect(service.loads, 2);
    expect(controller.isRightAnswer, null);
  });
  testWidgets('wrong answer waits two seconds and disposal cancels timer', (
    tester,
  ) async {
    await controller.startBattle(1);
    await controller.answer('is');
    await tester.pump(const Duration(seconds: 1));
    expect(service.loads, 1);
    controller.dispose();
    await tester.pump(const Duration(seconds: 2));
    expect(service.loads, 1);
  });
}
