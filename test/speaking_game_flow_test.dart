import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/game/service_game.dart';
import 'package:life_pilot/game/service_game_speech.dart';
import 'package:life_pilot/game/speaking/controller_game_speaking.dart';
import 'package:life_pilot/game/speaking/model_game_speaking.dart';
import 'package:life_pilot/game/speaking/page_game_speaking.dart';
import 'package:life_pilot/l10n/app_localizations.dart';

ModelGameSpeaking question() => ModelGameSpeaking(
  questionId: 'q',
  question: 'Say hello',
  correctAnswer: 'Hello world.',
  type: 'speaking',
);

class Speech extends ServiceGameSpeech {
  final texts = <String>[];
  int disposals = 0;
  @override
  Future<void> speak(String text) async {
    texts.add(text);
  }

  @override
  Future<void> dispose() async {
    disposals++;
  }
}

class Service extends ServiceGame {
  int loads = 0;
  int saves = 0;
  bool fail = false;
  bool failSave = false;
  Completer<ModelGameSpeaking>? pending;
  final submissions = <(String, String, bool)>[];
  @override
  Future<ModelGameSpeaking> fetchSpeakingQuestion(
    String userName,
    int level, {
    String questionBank = 'admin',
  }) async {
    loads++;
    if (fail) throw StateError('offline');
    return pending == null ? question() : pending!.future;
  }

  @override
  Future<void> submitSpeakingAnswer({
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
    if (failSave) throw StateError('save failed');
  }
}

class Auth extends ControllerAuth {
  @override
  String get currentAccount => 'user@example.com';
}

void main() {
  group('speaking round model', () {
    test('normalization preserves existing case space and period rules', () {
      expect(question().matchesAnswer('HELLOworld'), true);
      expect(question().matchesAnswer('hello world.'), true);
      expect(question().matchesAnswer('hello, world'), false);
    });
    test('empty answer does not consume an attempt', () {
      final round = ModelSpeakingRound(question());
      expect(round.answer(''), null);
      expect(round.attempts, 0);
    });
    test('first wrong answer allows one retry without points', () {
      final round = ModelSpeakingRound(question());
      final result = round.answer('wrong')!;
      expect(result.isCorrect, false);
      expect(result.completesQuestion, false);
      expect(result.points, 0);
      expect(round.attempts, 1);
    });
    test('correct answer completes question for four points', () {
      final round = ModelSpeakingRound(question());
      expect(round.answer('hello world')!.points, 4);
      expect(round.isComplete, true);
      expect(round.isCorrect, true);
    });
    test('second wrong answer retains existing completion reward', () {
      final round = ModelSpeakingRound(question());
      round.answer('wrong');
      final result = round.answer('still wrong')!;
      expect(result.isCorrect, false);
      expect(result.completesQuestion, true);
      expect(result.points, 4);
    });
    test('completed round rejects duplicate answers', () {
      final round = ModelSpeakingRound(question());
      round.answer('hello world');
      expect(round.answer('hello world'), null);
      expect(round.attempts, 1);
    });
  });

  late Service service;
  late Speech speech;
  late ControllerGameSpeaking controller;
  setUp(() {
    service = Service();
    speech = Speech();
    controller = ControllerGameSpeaking(
      userName: 'user',
      service: service,
      gameId: 'game',
      gameLevel: 1,
      speech: speech,
    );
  });
  tearDown(() {
    if (!controller.notifierDisposed) controller.dispose();
  });

  test('pending load blocks answers and deduplicates requests', () async {
    service.pending = Completer();
    final pending = controller.loadNextQuestion();
    expect(controller.answer('hello world'), false);
    await controller.loadNextQuestion();
    expect(service.loads, 1);
    service.pending!.complete(question());
    await pending;
    expect(controller.canAnswer, true);
    expect(speech.texts, ['Hello world.']);
  });
  test('ready notification already includes the new question', () async {
    final states = <(bool, String?)>[];
    controller.addListener(
      () => states.add((
        controller.isLoading,
        controller.currentQuestion?.questionId,
      )),
    );
    await controller.loadNextQuestion();
    expect(states, [(true, null), (false, 'q')]);
  });
  test('duplicate answers cannot score or submit while busy', () async {
    await controller.loadNextQuestion();
    expect(controller.answer('hello world'), true);
    expect(controller.answer('hello world'), false);
    await controller.loadNextQuestion();
    expect(controller.score, 4);
    expect(controller.answeredCount, 1);
    expect(service.loads, 1);
    expect(service.submissions, [('q', 'Hello world.', true)]);
  });
  test('two wrong attempts count one completed question', () async {
    await controller.loadNextQuestion();
    controller.answer('wrong');
    expect(controller.answeredCount, 0);
    expect(controller.canAnswer, true);
    controller.answer('wrong again');
    expect(controller.answeredCount, 1);
    expect(controller.score, 4);
    expect(controller.isRightAnswer, false);
    expect(service.submissions.length, 1);
  });
  test('late load cannot replace disposed question or play audio', () async {
    service.pending = Completer();
    final pending = controller.loadNextQuestion();
    controller.dispose();
    service.pending!.complete(question());
    await pending;
    expect(controller.currentQuestion, null);
    expect(controller.answer('hello world'), false);
    expect(speech.texts, isEmpty);
    expect(speech.disposals, 1);
  });
  test('failed load clears old round and retry restores interaction', () async {
    await controller.loadNextQuestion();
    service.fail = true;
    await controller.loadNextQuestion();
    expect(controller.currentQuestion, null);
    expect(controller.canAnswer, false);
    service.fail = false;
    await controller.loadNextQuestion();
    expect(controller.loadError, null);
    expect(controller.canAnswer, true);
  });
  test(
    'failed save is retryable and finished game is not saved twice',
    () async {
      controller.score = 100;
      service.failSave = true;
      await controller.loadNextQuestion();
      expect(controller.loadError, isNotNull);
      service.failSave = false;
      await controller.loadNextQuestion();
      await controller.loadNextQuestion();
      expect(controller.isFinished, true);
      expect(service.saves, 2);
    },
  );
  testWidgets(
    'correct answer advances after one second with clean round state',
    (tester) async {
      await controller.loadNextQuestion();
      controller.answer('hello world');
      await tester.pump(const Duration(milliseconds: 999));
      expect(service.loads, 1);
      await tester.pump(const Duration(milliseconds: 1));
      expect(service.loads, 2);
      expect(controller.repeatCounts, 0);
      expect(controller.isRightAnswer, null);
    },
  );
  testWidgets(
    'second wrong answer waits two seconds; disposal cancels transition',
    (tester) async {
      await controller.loadNextQuestion();
      controller.answer('wrong');
      controller.answer('wrong');
      await tester.pump(const Duration(seconds: 1));
      expect(service.loads, 1);
      controller.dispose();
      await tester.pump(const Duration(seconds: 2));
      expect(service.loads, 1);
    },
  );
  testWidgets('practice completes ten questions without View-owned counters', (
    tester,
  ) async {
    controller.dispose();
    controller = ControllerGameSpeaking(
      userName: 'user',
      service: service,
      gameId: 'game',
      gameLevel: 1,
      maxQuestions: 10,
      speech: speech,
    );
    await controller.loadNextQuestion();
    for (var i = 0; i < 10; i++) {
      expect(controller.answer('hello world'), true);
      await tester.pump(const Duration(seconds: 1));
    }
    expect(controller.isFinished, true);
    expect(controller.answeredCount, 10);
    expect(service.loads, 10);
    expect(service.submissions.length, 10);
  });

  Future<void> openPage(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<ControllerAuth>(
        create: (_) => Auth(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PageGameSpeaking(
            gameId: 'game',
            gameLevel: 1,
            service: Service(),
            speech: Speech(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('answer reveal cannot write into the next question', (
    tester,
  ) async {
    await openPage(tester);
    final dynamic state = tester.state(find.byType(PageGameSpeaking));
    await tester.enterText(find.byType(TextField), 'wrong');
    unawaited(state.onAnswer() as Future<void>);
    await tester.pump(const Duration(milliseconds: 100));
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(
      field.controller!.selection.baseOffset,
      field.controller!.text.length,
    );
    await (state.controller as ControllerGameSpeaking).loadNextQuestion();
    await tester.pump(const Duration(seconds: 2));
    expect(field.controller!.text, isEmpty);
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'leaving while revealing an answer does not update disposed text',
    (tester) async {
      await openPage(tester);
      final dynamic state = tester.state(find.byType(PageGameSpeaking));
      await tester.enterText(find.byType(TextField), 'wrong');
      unawaited(state.onAnswer() as Future<void>);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), null);
    },
  );
}
