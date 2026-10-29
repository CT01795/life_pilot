import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/business_plan/controller_business_plan.dart';
import 'package:life_pilot/business_plan/model_business_plan.dart';
import 'package:life_pilot/business_plan/model_plan_section.dart';
import 'package:life_pilot/business_plan/model_plan_question.dart';
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
        ModelPlanQuestion(id: 'q', prompt: 'Question', answer: 'old'),
      ],
    ),
  ],
);

class _Auth extends ControllerAuth {
  String account = 'a@example.com';
  @override
  String get currentAccount => account;
}

class _Service extends ServiceBusinessPlan {
  final writes = <(String, String)>[];
  final pending = <Completer<void>>[];
  @override
  Future<ModelBusinessPlan> fetchPlanDetail({required String planId}) async =>
      _plan(planId);
  @override
  Future<void> updatePlanTitle({
    required String planId,
    required String title,
  }) {
    writes.add((planId, title));
    final request = Completer<void>();
    pending.add(request);
    return request.future;
  }

  @override
  Future<void> upsertAnswer({
    required String planId,
    required String sectionId,
    required String questionId,
    required String answer,
  }) async {}
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
    c.plans = [_plan('a'), _plan('b')];
  });
  tearDown(() {
    if (!c.notifierDisposed) c.dispose();
    auth.dispose();
  });

  test(
    'unchanged title does not copy content or write to the service',
    () async {
      final before = c.currentPlan;
      await c.updateCurrentPlanTitle(before!, before.title);
      expect(c.currentPlan, same(before));
      expect(service.writes, isEmpty);
      final changed = before.renamed('new');
      expect(changed.sections, same(before.sections));
      expect(changed.renamed('new'), same(changed));
    },
  );

  test(
    'renaming another list item does not replace the selected plan',
    () async {
      final active = c.currentPlan;
      final save = c.updateCurrentPlanTitle(c.plans[1], 'New B');
      await _flush();
      expect(c.currentPlan, same(active));
      expect(c.currentPlanId, 'a');
      expect(c.plans[1].title, 'New B');
      service.pending.single.completeError(StateError('failed'));
      await save;
      expect(c.currentPlan, same(active));
      expect(c.plans[1].title, 'b');
    },
  );

  test(
    'late title failure rolls back its cache without altering another plan',
    () async {
      final save = c.updateCurrentPlanTitle(c.currentPlan!, 'New A');
      await _flush();
      await c.loadPlanDetailIfNeeded('b');
      service.pending.single.completeError(StateError('failed'));
      await save;
      expect(c.currentPlan!.id, 'b');
      expect(c.currentPlan!.title, 'b');
      await c.loadPlanDetailIfNeeded('a');
      expect(c.currentPlan!.title, 'a');
    },
  );

  for (final firstSucceeds in [true, false]) {
    for (final secondSucceeds in [true, false]) {
      test(
        'title writes preserve order and confirmed result $firstSucceeds/$secondSucceeds',
        () async {
          final original = c.currentPlan!;
          final first = c.updateCurrentPlanTitle(original, 'First');
          final second = c.updateCurrentPlanTitle(original, 'Second');
          await _flush();
          expect(service.writes, [('a', 'First')]);
          if (firstSucceeds) {
            service.pending[0].complete();
          } else {
            service.pending[0].completeError(StateError('first'));
          }
          await first;
          await _flush();
          expect(service.writes.last, ('a', 'Second'));
          if (secondSucceeds) {
            service.pending[1].complete();
          } else {
            service.pending[1].completeError(StateError('second'));
          }
          await second;
          final expected = secondSucceeds
              ? 'Second'
              : firstSucceeds
              ? 'First'
              : 'a';
          expect(c.currentPlan!.title, expected);
          expect(c.plans[0].title, expected);
          await c.loadPlanDetailIfNeeded('a');
          expect(c.currentPlan!.title, expected);
        },
      );
    }
  }

  test('title rollback preserves an answer saved in the meantime', () async {
    final save = c.updateCurrentPlanTitle(c.currentPlan!, 'New');
    await _flush();
    await c.commitCurrentAnswer('Edited answer');
    service.pending.single.completeError(StateError('failed'));
    await save;
    expect(c.currentPlan!.title, 'a');
    expect(c.currentQuestion.answer, 'Edited answer');
    await c.loadPlanDetailIfNeeded('a');
    expect(c.currentQuestion.answer, 'Edited answer');
  });

  test(
    'account change skips queued titles and ignores an old rollback',
    () async {
      final first = c.updateCurrentPlanTitle(c.currentPlan!, 'First');
      final second = c.updateCurrentPlanTitle(c.currentPlan!, 'Second');
      await _flush();
      auth.account = 'b@example.com';
      c.updateAuth(auth);
      await c.loadPlanDetailIfNeeded('a');
      service.pending.single.completeError(StateError('old'));
      await Future.wait([first, second]);
      expect(service.writes, hasLength(1));
      expect(c.currentPlan!.title, 'a');
    },
  );

  test('disposal prevents late title rollback', () async {
    final save = c.updateCurrentPlanTitle(c.currentPlan!, 'New');
    await _flush();
    c.dispose();
    final before = c.currentPlan;
    service.pending.single.completeError(StateError('late'));
    await save;
    expect(c.currentPlan, same(before));
  });
}
