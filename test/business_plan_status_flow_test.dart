import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/business_plan/controller_business_plan.dart';
import 'package:life_pilot/business_plan/model_business_plan.dart';
import 'package:life_pilot/business_plan/model_plan_section.dart';
import 'package:life_pilot/business_plan/model_plan_question.dart';
import 'package:life_pilot/business_plan/service_business_plan.dart';

ModelBusinessPlan _plan() => ModelBusinessPlan(
  id: 'a',
  title: 'Original',
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
  final writes = <String>[];
  final pending = <Completer<void>>[];
  @override
  Future<ModelBusinessPlan> fetchPlanDetail({required String planId}) async =>
      _plan();
  @override
  Future<void> updatePlanStatus({
    required String planId,
    required String status,
  }) {
    writes.add(status);
    final done = Completer<void>();
    pending.add(done);
    return done.future;
  }

  @override
  Future<void> updatePlanTitle({
    required String planId,
    required String title,
  }) async {}
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
    c.plans = [c.currentPlan!];
  });
  tearDown(() {
    if (!c.notifierDisposed) c.dispose();
    auth.dispose();
  });

  test('unchanged status neither writes nor copies the content tree', () async {
    final plan = c.plans.single;
    await c.updatePlanStatus(plan, plan.status);
    expect(service.writes, isEmpty);
    expect(c.plans.single, same(plan));
  });
  for (final firstSuccess in [true, false]) {
    for (final secondSuccess in [true, false]) {
      test(
        'serialized status writes and rollback ($firstSuccess, $secondSuccess)',
        () async {
          final original = c.plans.single;
          final first = c.updatePlanStatus(original, 'in_progress');
          final second = c.updatePlanStatus(original, 'completed');
          final checkedFirst = firstSuccess
              ? first
              : expectLater(first, throwsStateError);
          final checkedSecond = secondSuccess
              ? second
              : expectLater(second, throwsStateError);
          await _flush();
          expect(service.writes, ['in_progress']);
          if (firstSuccess) {
            service.pending[0].complete();
          } else {
            service.pending[0].completeError(StateError('first'));
          }
          await checkedFirst;
          await _flush();
          expect(service.writes, ['in_progress', 'completed']);
          expect(c.plans.single.status, 'completed');
          if (secondSuccess) {
            service.pending[1].complete();
          } else {
            service.pending[1].completeError(StateError('second'));
          }
          await checkedSecond;
          final expected = secondSuccess
              ? 'completed'
              : firstSuccess
              ? 'in_progress'
              : 'not_started';
          expect(c.plans.single.status, expected);
          expect(c.currentPlan!.status, expected);
          expect(c.plans.single.sections, same(original.sections));
        },
      );
    }
  }
  test('failed status preserves a newer title and saved answer', () async {
    final pending = c.updatePlanStatus(c.plans.single, 'in_progress');
    final checked = expectLater(pending, throwsStateError);
    await _flush();
    await c.updateCurrentPlanTitle(c.currentPlan!, 'New title');
    await c.commitCurrentAnswer('New answer');
    service.pending.single.completeError(StateError('status'));
    await checked;
    expect(c.currentPlan!.status, 'not_started');
    expect(c.currentPlan!.title, 'New title');
    expect(
      c.currentPlan!.sections.single.questions.single.answer,
      'New answer',
    );
    expect(c.plans.single.title, 'New title');
  });
  test('account change skips queued writes and ignores old rollback', () async {
    final first = c.updatePlanStatus(c.plans.single, 'in_progress');
    final checked = expectLater(first, throwsStateError);
    final second = c.updatePlanStatus(c.plans.single, 'completed');
    await _flush();
    auth.account = 'b@example.com';
    c.updateAuth(auth);
    c.plans = [_plan().copyWith(status: 'completed')];
    service.pending.single.completeError(StateError('old account'));
    await checked;
    await second;
    expect(service.writes, ['in_progress']);
    expect(c.plans.single.status, 'completed');
  });
  test('disposed controller does not send queued status writes', () async {
    final first = c.updatePlanStatus(c.plans.single, 'in_progress');
    final second = c.updatePlanStatus(c.plans.single, 'completed');
    await _flush();
    c.dispose();
    service.pending.single.complete();
    await Future.wait([first, second]);
    expect(service.writes, ['in_progress']);
  });
}
