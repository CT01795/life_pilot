import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/game/service_game.dart';
import 'package:life_pilot/game/service_game_speech.dart';
import 'package:life_pilot/game/social/controller_game_social.dart';
import 'package:life_pilot/game/social/model_game_social.dart';
import 'package:life_pilot/game/social/widgets_social_option.dart';
import 'package:life_pilot/l10n/app_localizations.dart';

ModelGameSocial _question() => ModelGameSocial(
  id: 'question',
  scene: 'A scene',
  options: ['good', 'neutral', 'bad'],
  scores: [10, 0, -5],
  correctAnswer: 'good',
);

class _Speech extends ServiceGameSpeech {
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

class _Service extends ServiceGame {
  int loads = 0;
  int saves = 0;
  bool fail = false;
  bool failSave = false;
  final submissions = <(String, String, bool)>[];
  Completer<ModelGameSocial>? pending;
  @override
  Future<ModelGameSocial> fetchSocialQuestion(
    String userName,
    int level, {
    String questionBank = 'admin',
  }) async {
    loads++;
    if (pending != null) return pending!.future;
    if (fail) throw StateError('offline');
    return _question();
  }

  @override
  Future<void> submitSocialAnswer({
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

Widget _app(Widget child, {String language = 'en'}) => MaterialApp(
  locale: Locale(language),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  late _Service service;
  late _Speech speech;
  late ControllerGameSocial controller;
  setUp(() {
    service = _Service();
    speech = _Speech();
    controller = ControllerGameSocial(
      userName: 'user',
      service: service,
      gameId: 'game',
      gameLevel: 1,
      maxQuestions: 10,
      speech: speech,
    );
  });
  tearDown(() {
    if (!controller.notifierDisposed) controller.dispose();
  });

  test(
    'question snapshots options and scores and preserves first duplicate scoring',
    () {
      final options = ['same', 'same', 'bad'];
      final scores = [10, -5, -10];
      final q = ModelGameSocial(
        id: 'id',
        scene: 'scene',
        options: options,
        scores: scores,
        correctAnswer: 'same',
      );
      options.clear();
      scores.clear();
      expect(q.scoreFor('same'), 10);
      expect(q.scoreFor('bad'), -10);
      expect(q.scoreFor('missing'), -1);
      expect(() => q.options.clear(), throwsUnsupportedError);
      expect(() => q.scores.clear(), throwsUnsupportedError);
    },
  );

  test('missing option scores use the existing unknown-answer penalty', () {
    final q = ModelGameSocial(
      id: 'id',
      scene: 'scene',
      options: ['a', 'b'],
      scores: [10],
      correctAnswer: 'a',
    );
    expect(q.scoreFor('b'), -1);
  });

  test(
    'correct and neutral options retain nonnegative scoring and duplicate-answer guard',
    () async {
      await controller.loadNextQuestion();
      expect(speech.texts, ['A scene']);
      expect(controller.feedbackFor('good'), SocialOptionFeedback.neutral);
      await controller.answer('neutral');
      await controller.answer('good');
      expect(controller.score, 0);
      expect(controller.answeredCount, 1);
      expect(service.submissions, [('question', 'neutral', true)]);
      expect(controller.feedbackFor('neutral'), SocialOptionFeedback.correct);
      expect(controller.feedbackFor('good'), SocialOptionFeedback.neutral);
    },
  );

  test(
    'wrong answer reveals nonnegative alternatives without changing score rules',
    () async {
      await controller.loadNextQuestion();
      await controller.answer('bad');
      expect(controller.score, -5);
      expect(controller.scoreMinus, -5);
      expect(controller.showCorrectAnswer, isTrue);
      expect(controller.feedbackFor('bad'), SocialOptionFeedback.incorrect);
      expect(controller.feedbackFor('good'), SocialOptionFeedback.correct);
      expect(controller.feedbackFor('neutral'), SocialOptionFeedback.correct);
      expect(service.submissions.single, ('question', 'bad', false));
    },
  );

  test(
    'loading blocks answers to a stale question and duplicate fetches',
    () async {
      controller.currentQuestion = _question();
      service.pending = Completer<ModelGameSocial>();
      final load = controller.loadNextQuestion();
      await controller.loadNextQuestion();
      await controller.answer('good');
      expect(service.loads, 1);
      expect(service.submissions, isEmpty);
      service.pending!.complete(_question());
      await load;
      expect(controller.canAnswer, isTrue);
    },
  );

  test(
    'failed question load can retry without platform audio dependencies',
    () async {
      service.fail = true;
      await controller.loadNextQuestion();
      expect(controller.loadError, isA<StateError>());
      expect(controller.isLoading, isFalse);
      expect(controller.canAnswer, isFalse);
      service.fail = false;
      await controller.retry();
      expect(controller.loadError, isNull);
      expect(controller.canAnswer, isTrue);
    },
  );

  test(
    'disposing during a question fetch leaves state and speech untouched',
    () async {
      final old = _question();
      controller.currentQuestion = old;
      service.pending = Completer<ModelGameSocial>();
      final load = controller.loadNextQuestion();
      controller.dispose();
      service.pending!.complete(_question());
      await load;
      expect(controller.currentQuestion, same(old));
      expect(speech.texts, isEmpty);
      await controller.answer('good');
      await controller.speak('late');
      expect(service.submissions, isEmpty);
      expect(speech.disposals, 1);
    },
  );

  test(
    'question-count completion stops subsequent questions and answers',
    () async {
      controller.maxQuestions = 1;
      await controller.loadNextQuestion();
      await controller.answer('good');
      expect(controller.isFinished, isTrue);
      await controller.loadNextQuestion();
      await controller.answer('good');
      expect(service.loads, 1);
      expect(service.submissions.length, 1);
    },
  );

  test(
    'score completion failure remains retryable and successful finish cannot resave through next question',
    () async {
      controller.score = 100;
      service.failSave = true;
      await controller.loadNextQuestion();
      expect(controller.loadError, isA<StateError>());
      expect(controller.isFinished, isFalse);
      service.failSave = false;
      await controller.retry();
      expect(controller.isFinished, isTrue);
      await controller.loadNextQuestion();
      await controller.retry();
      expect(service.saves, 2);
    },
  );

  testWidgets('correct answers keep the one-second next-question delay', (
    tester,
  ) async {
    await controller.loadNextQuestion();
    await controller.answer('good');
    await tester.pump(const Duration(milliseconds: 999));
    expect(service.loads, 1);
    await tester.pump(const Duration(milliseconds: 1));
    expect(service.loads, 2);
    controller.dispose();
  });

  testWidgets('wrong answers keep two seconds; disposal cancels the timer', (
    tester,
  ) async {
    await controller.loadNextQuestion();
    await controller.answer('bad');
    await tester.pump(const Duration(seconds: 1));
    expect(service.loads, 1);
    controller.dispose();
    await tester.pump(const Duration(seconds: 2));
    expect(service.loads, 1);
  });

  test(
    'unused speech service can be disposed without initializing native audio',
    () async {
      final speech = ServiceGameSpeech();
      await speech.speak('');
      await speech.dispose();
      await speech.dispose();
      await speech.speak('after disposal');
    },
  );

  for (final language in ['zh', 'en', 'ja', 'ko']) {
    testWidgets(
      '$language option fits phone width and separates speech from answering',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var answers = 0;
        var plays = 0;
        await tester.pumpWidget(
          _app(
            WidgetsSocialOption(
              option:
                  'A long option that should wrap naturally on narrow screens',
              feedback: SocialOptionFeedback.incorrect,
              selected: true,
              canAnswer: true,
              onAnswer: () => answers++,
              onSpeak: () => plays++,
            ),
            language: language,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byIcon(Icons.clear_rounded), findsOneWidget);
        await tester.tap(find.byType(Container));
        expect(answers, 1);
        expect(plays, 0);
        await tester.tap(
          find.text(
            'A long option that should wrap naturally on narrow screens',
          ),
        );
        expect(plays, 1);
        expect(answers, 1);
      },
    );
  }
}
