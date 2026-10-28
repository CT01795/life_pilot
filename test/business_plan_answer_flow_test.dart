import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/business_plan/controller_business_plan.dart';
import 'package:life_pilot/business_plan/model_business_plan.dart';
import 'package:life_pilot/business_plan/model_plan_answers.dart';
import 'package:life_pilot/business_plan/model_plan_question.dart';
import 'package:life_pilot/business_plan/model_plan_section.dart';
import 'package:life_pilot/business_plan/service_business_plan.dart';

ModelBusinessPlan _plan(String id) => ModelBusinessPlan(
  id: id,
  title: id,
  createdAt: DateTime(2026),
  sections: [
    ModelPlanSection(
      id: 's',
      title: 'Section',
      questions: [
        ModelPlanQuestion(id: 'q0', prompt: '0', answer: 'old0'),
        ModelPlanQuestion(id: 'q1', prompt: '1', answer: 'old1'),
      ],
    ),
    ModelPlanSection(id: 't', title: 'Other section', questions: []),
  ],
);

class _Auth extends ControllerAuth {
  String account = 'a@example.com';
  @override
  String get currentAccount => account;
}

class _Service extends ServiceBusinessPlan {
  final writes = <(String, String, String, String)>[];
  final pending = <Completer<void>>[];
  @override
  Future<ModelBusinessPlan> fetchPlanDetail({required String planId}) async =>
      _plan(planId);
  @override
  Future<void> upsertAnswer({
    required String planId,
    required String sectionId,
    required String questionId,
    required String answer,
  }) {
    writes.add((planId, sectionId, questionId, answer));
    final result = Completer<void>();
    pending.add(result);
    return result.future;
  }
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Auth auth;
  late _Service service;
  late ControllerBusinessPlan c;
  setUp(() async {
    auth = _Auth();
    service = _Service();
    c = ControllerBusinessPlan(service: service, auth: auth);
    await c.loadPlanDetailIfNeeded('a');
  });
  tearDown(() {
    if (!c.notifierDisposed) c.dispose();
    auth.dispose();
  });

  test('unchanged answers do not write or copy the plan', () async {
    final before = c.currentPlan;
    await c.commitCurrentAnswer('old0');
    expect(service.writes, isEmpty);
    expect(c.currentPlan, same(before));
  });

  test(
    'same pending answer waits for its save without an extra write',
    () async {
      final first = c.commitCurrentAnswer('pending');
      var duplicateFinished = false;
      final duplicate = c
          .commitCurrentAnswer('pending')
          .then((_) => duplicateFinished = true);
      await _flush();
      expect(duplicateFinished, isFalse);
      expect(service.writes, hasLength(1));
      service.pending.single.complete();
      await Future.wait([first, duplicate]);
      expect(duplicateFinished, isTrue);
    },
  );

  test(
    'synchronous answer listener cannot reverse queued write order',
    () async {
      final notifier = c.answerNotifier(0, 0);
      Future<void>? nested;
      var entered = false;
      notifier.addListener(() {
        if (entered || notifier.value != 'first') return;
        entered = true;
        nested = c.commitCurrentAnswer('second');
      });
      final first = c.commitCurrentAnswer('first');
      await _flush();
      expect(service.writes.single.$4, 'first');
      service.pending[0].complete();
      await first;
      await _flush();
      expect(service.writes.last.$4, 'second');
      service.pending[1].complete();
      await nested;
      expect(c.currentQuestion.answer, 'second');
    },
  );

  for (final firstSucceeds in [true, false]) {
    for (final secondSucceeds in [true, false]) {
      test(
        'same question writes in order; success $firstSucceeds/$secondSucceeds restores confirmed data',
        () async {
          final first = c.commitCurrentAnswer('first');
          final second = c.commitCurrentAnswer('second');
          await _flush();
          expect(service.writes, [('a', 's', 'q0', 'first')]);
          expect(c.currentQuestion.answer, 'second');
          if (firstSucceeds) {
            service.pending[0].complete();
          } else {
            service.pending[0].completeError(StateError('first failed'));
          }
          await first;
          await _flush();
          expect(service.writes.last, ('a', 's', 'q0', 'second'));
          if (secondSucceeds) {
            service.pending[1].complete();
          } else {
            service.pending[1].completeError(StateError('second failed'));
          }
          await second;
          final expected = secondSucceeds
              ? 'second'
              : firstSucceeds
              ? 'first'
              : 'old0';
          expect(c.currentQuestion.answer, expected);
          expect(c.answerNotifier(0, 0).value, expected);
          await c.loadPlanDetailIfNeeded('a');
          expect(c.currentQuestion.answer, expected);
        },
      );
    }
  }

  test(
    'different questions save independently and rollback preserves another answer',
    () async {
      final first = c.commitCurrentAnswer('failed0');
      c.jumpToQuestion(sectionIndex: 0, questionIndex: 1);
      final second = c.commitCurrentAnswer('saved1');
      await _flush();
      expect(service.writes, hasLength(2));
      service.pending[1].complete();
      await second;
      service.pending[0].completeError(StateError('failed'));
      await first;
      expect(c.questionIndex, 1);
      expect(c.currentQuestion.answer, 'saved1');
      expect(c.currentPlan!.sections[0].questions[0].answer, 'old0');
      await c.loadPlanDetailIfNeeded('a');
      expect(c.currentPlan!.sections[0].questions.map((q) => q.answer), [
        'old0',
        'saved1',
      ]);
    },
  );

  test(
    'failure after switching plans only rolls back the original cached plan',
    () async {
      final save = c.commitCurrentAnswer('failed');
      await _flush();
      await c.loadPlanDetailIfNeeded('b');
      service.pending.single.completeError(StateError('failed'));
      await save;
      expect(c.currentPlan!.id, 'b');
      expect(c.currentQuestion.answer, 'old0');
      await c.loadPlanDetailIfNeeded('a');
      expect(c.currentQuestion.answer, 'old0');
    },
  );

  test('account switch ignores old rollback and skips queued writes', () async {
    final first = c.commitCurrentAnswer('first');
    final second = c.commitCurrentAnswer('second');
    await _flush();
    auth.account = 'b@example.com';
    c.updateAuth(auth);
    await c.loadPlanDetailIfNeeded('a');
    service.pending.single.completeError(StateError('old account failed'));
    await Future.wait([first, second]);
    expect(service.writes, hasLength(1));
    expect(c.currentQuestion.answer, 'old0');
  });

  test('disposed controller does not publish a late rollback', () async {
    final save = c.commitCurrentAnswer('pending');
    await _flush();
    var notices = 0;
    c.addListener(() => notices++);
    c.dispose();
    final before = c.currentPlan;
    service.pending.single.completeError(StateError('late'));
    await save;
    expect(c.currentPlan, same(before));
    expect(notices, 0);
  });

  test(
    'answer Model only copies the changed branch and respects expected value',
    () {
      final plan = _plan('a');
      final changed = ModelPlanAnswers.replace(
        plan,
        sectionId: 's',
        questionId: 'q0',
        answer: 'changed',
      );
      expect(changed.sections[1], same(plan.sections[1]));
      expect(
        changed.sections[0].questions[1],
        same(plan.sections[0].questions[1]),
      );
      expect(plan.sections[0].questions[0].answer, 'old0');
      expect(
        ModelPlanAnswers.replace(
          changed,
          sectionId: 's',
          questionId: 'q0',
          answer: 'old0',
          expectedAnswer: 'outdated',
        ),
        same(changed),
      );
      expect(
        ModelPlanAnswers.replace(
          plan,
          sectionId: 'missing',
          questionId: 'q0',
          answer: 'x',
        ),
        same(plan),
      );
    },
  );
}
