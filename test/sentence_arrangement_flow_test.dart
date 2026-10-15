import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/game/service_game.dart';
import 'package:life_pilot/game/service_game_speech.dart';
import 'package:life_pilot/game/sentence/controller_game_sentence.dart';
import 'package:life_pilot/game/sentence/model_game_sentence.dart';
import 'package:life_pilot/game/sentence/model_sentence_arrangement.dart';
import 'package:life_pilot/game/sentence/page_game_sentence.dart';
import 'package:life_pilot/l10n/app_localizations.dart';

WordItem _word(String id, [String? text]) => WordItem(id: id, text: text ?? id);
ModelGameSentence _question() => ModelGameSentence(
  questionId: 'q',
  question: 'Build a sentence',
  options: ['Hello', 'world'],
  correctAnswer: 'Hello world',
  type: 'sentence',
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
  Completer<ModelGameSentence>? pending;
  final answers = <(String, String, bool)>[];
  @override
  Future<ModelGameSentence> fetchSentenceQuestion(
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
  Future<void> submitSentenceAnswer({
    required String userName,
    required String questionId,
    required String answer,
    required bool isRightAnswer,
  }) async {
    answers.add((questionId, answer, isRightAnswer));
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

class _Auth extends ControllerAuth {
  @override
  String get currentAccount => 'user@example.com';
}

void _fill(ControllerGameSentence controller, {bool reversed = false}) {
  final words = [...controller.options]
    ..sort((a, b) => a.text.compareTo(b.text));
  final ordered = reversed ? words.reversed.toList() : words;
  for (var i = 0; i < ordered.length; i++) {
    controller.moveWordToSlot(i, ordered[i]);
  }
}

void main() {
  group('arrangement Model', () {
    late ModelSentenceArrangement board;
    late WordItem a;
    late WordItem b;
    setUp(() {
      a = _word('a');
      b = _word('b');
      board = ModelSentenceArrangement()..reset([a, b]);
    });

    test(
      'placing words updates readiness and exposes stable read-only views',
      () {
        final options = board.options;
        expect(board.isComplete, isFalse);
        expect(board.moveTo(0, a), isTrue);
        expect(board.moveTo(1, b), isTrue);
        expect(board.isComplete, isTrue);
        expect(options, isEmpty);
        expect(board.slots, [a, b]);
        expect(() => board.options.clear(), throwsUnsupportedError);
        expect(() => board.slots[0] = null, throwsUnsupportedError);
      },
    );

    test(
      'replacing an occupied slot returns the displaced word to the bank',
      () {
        board.moveTo(0, a);
        board.moveTo(0, b);
        expect(board.slots, [b, null]);
        expect(board.options, [a]);
        expect(board.slotOf(a), isNull);
        expect(board.slotOf(b), 0);
        expect(board.isComplete, isFalse);
      },
    );

    test('slot-to-slot swaps preserve words and completeness', () {
      board.moveTo(0, a);
      board.moveTo(1, b);
      board.moveTo(1, a);
      expect(board.slots, [b, a]);
      expect(board.options, isEmpty);
      expect(board.slotOf(a), 1);
      expect(board.slotOf(b), 0);
      expect(board.isComplete, isTrue);
    });

    test('moving to an empty slot and removing preserve the filled count', () {
      board.moveTo(0, a);
      board.moveTo(1, a);
      expect(board.slots, [null, a]);
      expect(board.isComplete, isFalse);
      expect(board.removeAt(1), isTrue);
      expect(board.slots, [null, null]);
      expect(board.options.length, 2);
      expect(board.removeAt(1), isFalse);
    });

    test('invalid indices and foreign drags never mutate the arrangement', () {
      expect(board.moveTo(-1, a), isFalse);
      expect(board.moveTo(2, a), isFalse);
      expect(board.moveTo(0, _word('foreign')), isFalse);
      expect(board.removeAt(-1), isFalse);
      expect(board.removeAt(2), isFalse);
      expect(board.options, [a, b]);
      expect(board.slots, [null, null]);
      board.moveTo(0, _word('a', 'injected text'));
      expect(board.slots.first, same(a));
      expect(board.moveTo(0, a), isFalse);
    });

    test(
      'identical word text remains distinct by ID; reset rejects stale drags',
      () {
        final first = _word('1', 'go');
        final second = _word('2', 'go');
        board.reset([first, second]);
        board.moveTo(0, first);
        board.moveTo(1, second);
        expect(board.isComplete, isTrue);
        expect(board.slots.map((w) => w!.text), ['go', 'go']);
        board.reset([a, b]);
        expect(board.moveTo(0, first), isFalse);
        expect(board.slotOf(first), isNull);
      },
    );

    test(
      'duplicate IDs reject reset atomically; an empty board is not ready',
      () {
        expect(() => board.reset([a, _word('a')]), throwsArgumentError);
        expect(board.options, [a, b]);
        board.reset([]);
        expect(board.isComplete, isFalse);
      },
    );

    test(
      'random moves conserve every word and agree with a full readiness scan',
      () {
        final words = List.generate(8, (i) => _word('$i'));
        board.reset(words);
        final random = Random(2026);
        for (var i = 0; i < 500; i++) {
          if (random.nextBool()) {
            board.moveTo(
              random.nextInt(10) - 1,
              words[random.nextInt(words.length)],
            );
          } else {
            board.removeAt(random.nextInt(10) - 1);
          }
          final present = [
            ...board.options,
            ...board.slots.whereType<WordItem>(),
          ];
          expect(present.length, words.length);
          expect(
            present.map((word) => word.id).toSet(),
            words.map((word) => word.id).toSet(),
          );
          expect(
            board.isComplete,
            board.slots.isNotEmpty && board.slots.every((word) => word != null),
          );
        }
      },
    );
  });

  group('sentence Controller', () {
    late _Service service;
    late _Speech speech;
    late ControllerGameSentence controller;
    setUp(() {
      service = _Service();
      speech = _Speech();
      controller = ControllerGameSentence(
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

    test(
      'correct answer is submitted once and locks arrangement until the next question',
      () async {
        await controller.loadNextQuestion();
        _fill(controller);
        expect(controller.canCheckAnswer, isTrue);
        expect(controller.checkAnswer(), isTrue);
        expect(controller.score, 4);
        expect(controller.answeredCount, 1);
        expect(service.answers, [('q', 'Hello world', true)]);
        controller.removeWordFromSlot(0);
        expect(controller.answerSlots.first, isNotNull);
        expect(controller.checkAnswer(), isFalse);
      },
    );

    test(
      'wrong answer preserves score and correct-answer visibility rules',
      () async {
        await controller.loadNextQuestion();
        _fill(controller, reversed: true);
        expect(controller.checkAnswer(), isTrue);
        expect(controller.score, -4);
        expect(controller.scoreMinus, -4);
        expect(controller.showCorrectAnswer, isTrue);
        expect(service.answers.single, ('q', 'world Hello', false));
      },
    );

    test(
      'loading blocks stale drag/answer data and coalesces user re-entry',
      () async {
        await controller.loadNextQuestion();
        _fill(controller);
        final oldWord = controller.answerSlots.first!;
        service.pending = Completer<ModelGameSentence>();
        final loading = controller.loadNextQuestion();
        await controller.loadNextQuestion();
        expect(service.loads, 2);
        expect(controller.canCheckAnswer, isFalse);
        controller.removeWordFromSlot(0);
        expect(controller.answerSlots.first, oldWord);
        service.pending!.complete(_question());
        await loading;
        expect(controller.canMoveWordToSlot(0, oldWord), isFalse);
        expect(controller.answerSlots.every((word) => word == null), isTrue);
      },
    );

    test('failed load clears stale board and can retry', () async {
      await controller.loadNextQuestion();
      service.fail = true;
      await controller.loadNextQuestion();
      expect(controller.loadError, isA<StateError>());
      expect(controller.options, isEmpty);
      expect(controller.canArrange, isFalse);
      service.fail = false;
      await controller.loadNextQuestion();
      expect(controller.loadError, isNull);
      expect(controller.options.length, 2);
    });

    test(
      'late response after disposal cannot replace question or play audio',
      () async {
        service.pending = Completer<ModelGameSentence>();
        final loading = controller.loadNextQuestion();
        controller.dispose();
        service.pending!.complete(_question());
        await loading;
        expect(controller.currentQuestion, isNull);
        expect(speech.texts, isEmpty);
        expect(controller.checkAnswer(), isFalse);
        await controller.speak('late');
        expect(speech.texts, isEmpty);
        expect(speech.disposals, 1);
      },
    );

    test(
      'score save failure is retryable; successful completion is not saved twice',
      () async {
        controller.score = 100;
        service.failSave = true;
        await controller.loadNextQuestion();
        expect(controller.isFinished, isFalse);
        service.failSave = false;
        await controller.loadNextQuestion();
        expect(controller.isFinished, isTrue);
        await controller.loadNextQuestion();
        expect(service.saves, 2);
      },
    );

    testWidgets('correct answers retain the one-second delay', (tester) async {
      await controller.loadNextQuestion();
      _fill(controller);
      controller.checkAnswer();
      await tester.pump(const Duration(milliseconds: 999));
      expect(service.loads, 1);
      await tester.pump(const Duration(milliseconds: 1));
      expect(service.loads, 2);
      controller.dispose();
    });

    testWidgets(
      'wrong answers retain two seconds; disposal cancels pending transition',
      (tester) async {
        await controller.loadNextQuestion();
        _fill(controller, reversed: true);
        controller.checkAnswer();
        await tester.pump(const Duration(seconds: 1));
        expect(service.loads, 1);
        controller.dispose();
        await tester.pump(const Duration(seconds: 2));
        expect(service.loads, 1);
      },
    );
  });

  testWidgets(
    'practice page completes after ten answers using Controller-owned progress',
    (tester) async {
      final auth = _Auth();
      final service = _Service();
      final speech = _Speech();
      await tester.pumpWidget(
        ChangeNotifierProvider<ControllerAuth>.value(
          value: auth,
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => PageGameSentence(
                        gameId: 'game',
                        gameLevel: -1,
                        service: service,
                        speech: speech,
                      ),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      for (var question = 0; question < 10; question++) {
        final draggable =
            tester
                .widgetList<Draggable<WordItem>>(
                  find.byType(Draggable<WordItem>),
                )
                .toList()
              ..sort((a, b) => a.data!.text.compareTo(b.data!.text));
        final targets = tester
            .widgetList<DragTarget<WordItem>>(find.byType(DragTarget<WordItem>))
            .toList();
        for (var i = 0; i < draggable.length; i++) {
          targets[i].onAcceptWithDetails!(
            DragTargetDetails(data: draggable[i].data!, offset: Offset.zero),
          );
        }
        await tester.pump();
        final loc = AppLocalizations.of(
          tester.element(find.byType(PageGameSentence)),
        )!;
        await tester.tap(find.widgetWithText(ElevatedButton, loc.check));
        if (question < 9) {
          await tester.pump(const Duration(seconds: 1));
          await tester.pump();
        } else {
          await tester.pumpAndSettle();
        }
      }
      expect(service.answers.length, 10);
      expect(service.loads, 10);
      expect(find.byType(PageGameSentence), findsNothing);
      expect(find.text('open'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      auth.dispose();
    },
  );
}
