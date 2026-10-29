import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/business_plan/controller_business_plan.dart';
import 'package:life_pilot/business_plan/model_business_plan.dart';
import 'package:life_pilot/business_plan/model_business_plan_list.dart';
import 'package:life_pilot/business_plan/service_business_plan.dart';

ModelBusinessPlan _plan(String id, {String status = 'not_started'}) =>
    ModelBusinessPlan(
      id: id,
      title: id,
      status: status,
      createdAt: DateTime(2026, 10),
      sections: [],
    );

class _Auth extends ControllerAuth {
  String account = 'a@example.com';
  @override
  String get currentAccount => account;
}

class _Service extends ServiceBusinessPlan {
  bool failWrite = false;
  List<ModelBusinessPlan> rows = [];
  final statusWrites = <Completer<void>>[];
  @override
  Future<List<ModelBusinessPlan>> fetchPlans({
    required String user,
    required DateTime dateFrom,
    required DateTime dateTo,
  }) async => rows;
  @override
  Future<bool> hasPlansBefore({
    required String user,
    required DateTime before,
  }) async => false;
  @override
  Future<void> updatePlanStatus({
    required String planId,
    required String status,
  }) {
    final done = Completer<void>();
    statusWrites.add(done);
    return done.future;
  }

  @override
  Future<void> updatePlanTitle({
    required String planId,
    required String title,
  }) async {
    if (failWrite) throw StateError('offline');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Auth auth;
  late _Service service;
  late ControllerBusinessPlan controller;
  setUp(() {
    auth = _Auth();
    service = _Service();
    controller = ControllerBusinessPlan(service: service, auth: auth);
  });
  tearDown(() {
    if (!controller.notifierDisposed) controller.dispose();
    auth.dispose();
  });

  test(
    'model filtering retains source order and returns a readonly snapshot',
    () {
      final rows = [
        _plan('b'),
        _plan('hidden', status: 'completed'),
        _plan('a'),
      ];
      final statuses = {'not_started'};
      final result = ModelBusinessPlanList.visible(rows, statuses);
      expect(result.map((p) => p.id), ['b', 'a']);
      expect(rows, hasLength(3));
      rows.clear();
      statuses.clear();
      expect(result.map((p) => p.id), ['b', 'a']);
      expect(() => result.clear(), throwsUnsupportedError);
    },
  );

  test('controller owns list structure and reuses filtered snapshots', () {
    final rows = [_plan('a'), _plan('hidden', status: 'completed')];
    controller.plans = rows;
    final all = controller.plans;
    final visible = controller.visiblePlans;
    rows.clear();
    expect(controller.plans, same(all));
    expect(controller.plans, hasLength(2));
    expect(controller.visiblePlans, same(visible));
    expect(visible.single.id, 'a');
    expect(() => all.clear(), throwsUnsupportedError);
    expect(() => visible.clear(), throwsUnsupportedError);
    expect(() => all[0] = _plan('other'), throwsUnsupportedError);
  });

  test(
    'replacing data invalidates filtering without changing old snapshots',
    () {
      controller.plans = [_plan('a')];
      final previous = controller.visiblePlans;
      controller.plans = [_plan('b')];
      expect(controller.visiblePlans.single.id, 'b');
      expect(controller.visiblePlans, isNot(same(previous)));
      expect(previous.single.id, 'a');
    },
  );

  test(
    'status toggles invalidate only their snapshots and support empty filters',
    () {
      controller.plans = [_plan('a'), _plan('b', status: 'completed')];
      final previous = controller.visiblePlans;
      final statuses = controller.selectedStatuses;
      expect(controller.selectedStatuses, same(statuses));
      expect(() => statuses.clear(), throwsUnsupportedError);
      controller.toggleStatus('completed');
      expect(controller.visiblePlans.map((p) => p.id), ['a', 'b']);
      expect(previous.map((p) => p.id), ['a']);
      expect(statuses, isNot(contains('completed')));
      controller.toggleStatus('completed');
      controller.toggleStatus('not_started');
      controller.toggleStatus('in_progress');
      expect(controller.visiblePlans, isEmpty);
      expect(controller.visiblePlans, same(controller.visiblePlans));
    },
  );

  for (final fails in [false, true]) {
    test(
      'title update refreshes cached visible data (failure=$fails)',
      () async {
        final plan = _plan('a');
        controller.plans = [plan];
        final previous = controller.visiblePlans;
        service.failWrite = fails;
        final save = controller.updateCurrentPlanTitle(plan, 'Renamed');
        expect(controller.visiblePlans.single.title, 'Renamed');
        expect(previous.single.title, 'a');
        await save;
        expect(controller.visiblePlans.single.title, fails ? 'a' : 'Renamed');
        expect(controller.visiblePlans, same(controller.visiblePlans));
      },
    );

    test(
      'status update and rollback invalidate filtering (failure=$fails)',
      () async {
        final plan = _plan('a');
        controller.plans = [plan];
        final previous = controller.visiblePlans;
        final save = controller.updatePlanStatus(plan, 'completed');
        final checked = fails ? expectLater(save, throwsStateError) : save;
        expect(controller.visiblePlans, isEmpty);
        expect(previous.single.status, 'not_started');
        await Future<void>.delayed(Duration.zero);
        if (fails) {
          service.statusWrites.single.completeError(StateError('offline'));
        } else {
          service.statusWrites.single.complete();
        }
        await checked;
        expect(controller.visiblePlans.length, fails ? 1 : 0);
        expect(
          controller.plans.single.status,
          fails ? 'not_started' : 'completed',
        );
      },
    );
  }

  test(
    'account reset invalidates visible data without mutating old snapshots',
    () {
      controller.plans = [_plan('a')];
      final previous = controller.visiblePlans;
      auth.account = 'b@example.com';
      controller.updateAuth(auth);
      expect(controller.plans, isEmpty);
      expect(controller.visiblePlans, isEmpty);
      expect(previous.single.id, 'a');
    },
  );

  test('same account and disposed filter actions do not rebuild snapshots', () {
    controller.plans = [_plan('a')];
    final visible = controller.visiblePlans;
    final statuses = controller.selectedStatuses;
    controller.updateAuth(auth);
    expect(controller.visiblePlans, same(visible));
    controller.dispose();
    controller.toggleStatus('completed');
    expect(controller.selectedStatuses, same(statuses));
    expect(controller.visiblePlans, same(visible));
  });

  test(
    'list refresh replaces snapshot and isolates later service mutations',
    () async {
      controller.plans = [_plan('old')];
      final previous = controller.visiblePlans;
      service.rows = [_plan('new')];
      await controller.loadPlans();
      final loaded = controller.visiblePlans;
      expect(loaded.single.id, 'new');
      service.rows.clear();
      expect(controller.visiblePlans, same(loaded));
      expect(loaded.single.id, 'new');
      expect(previous.single.id, 'old');
    },
  );
}
