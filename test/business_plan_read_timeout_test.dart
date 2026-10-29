import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/business_plan/controller_business_plan.dart';
import 'package:life_pilot/business_plan/model_business_plan.dart';
import 'package:life_pilot/business_plan/model_plan_template.dart';
import 'package:life_pilot/business_plan/service_business_plan.dart';

ModelBusinessPlan _plan(String id, [String title = 'Plan']) =>
    ModelBusinessPlan(
      id: id,
      title: title,
      createdAt: DateTime(2026, 10),
      sections: [],
    );
ModelPlanTemplate _template(String id) =>
    ModelPlanTemplate(id: id, title: id, description: '');

class _Auth extends ControllerAuth {
  String account = 'a@example.com';
  @override
  String get currentAccount => account;
}

class _Service extends ServiceBusinessPlan {
  final pages = <Completer<List<ModelBusinessPlan>>>[];
  final ranges = <(DateTime, DateTime)>[];
  final templates = <Completer<List<ModelPlanTemplate>>>[];
  final details = <({String id, Completer<ModelBusinessPlan> done})>[];
  final histories = <Completer<bool>>[];
  final older = <Completer<DateTime?>>[];
  final boundaries = <DateTime>[];
  bool gateHistory = false, gateOlder = false, more = true;
  late final createGate = Completer<void>();
  int creates = 0;
  @override
  Future<List<ModelBusinessPlan>> fetchPlans({
    required String user,
    required DateTime dateFrom,
    required DateTime dateTo,
  }) {
    final done = Completer<List<ModelBusinessPlan>>();
    pages.add(done);
    ranges.add((dateFrom, dateTo));
    return done.future;
  }

  @override
  Future<List<ModelPlanTemplate>> fetchTemplates() {
    final done = Completer<List<ModelPlanTemplate>>();
    templates.add(done);
    return done.future;
  }

  @override
  Future<ModelBusinessPlan> fetchPlanDetail({required String planId}) {
    final done = Completer<ModelBusinessPlan>();
    details.add((id: planId, done: done));
    return done.future;
  }

  @override
  Future<bool> hasPlansBefore({
    required String user,
    required DateTime before,
  }) {
    if (!gateHistory) return Future.value(more);
    final done = Completer<bool>();
    histories.add(done);
    return done.future;
  }

  @override
  Future<DateTime?> latestPlanDateBefore({
    required String user,
    required DateTime before,
  }) {
    boundaries.add(before);
    if (!gateOlder) return Future.value(DateTime(2024, 10));
    final done = Completer<DateTime?>();
    older.add(done);
    return done.future;
  }

  @override
  Future<void> createPlanFromTemplate({
    required String user,
    required String planId,
    required String title,
    required String templateId,
  }) {
    creates++;
    return createGate.future;
  }
}

void main() {
  late _Auth auth;
  late _Service service;
  late ControllerBusinessPlan c;
  setUp(() {
    auth = _Auth();
    service = _Service();
    c = ControllerBusinessPlan(
      service: service,
      auth: auth,
      requestTimeout: const Duration(milliseconds: 20),
      historyTimeout: const Duration(milliseconds: 10),
    );
  });
  tearDown(() {
    if (!c.notifierDisposed) c.dispose();
    auth.dispose();
  });
  Future<void> seed(WidgetTester tester) async {
    final pending = c.loadPlans();
    service.pages.last.complete([_plan('initial')]);
    await tester.pump();
    await pending;
  }

  for (final stage in ['list', 'history', 'older date', 'older page']) {
    for (final fails in [false, true]) {
      testWidgets(
        '$stage timeout retains data and retries (late failure=$fails)',
        (tester) async {
          final older = stage.startsWith('older');
          if (stage != 'history') await seed(tester);
          if (stage == 'history') service.gateHistory = true;
          if (stage == 'older date') service.gateOlder = true;
          final pending = older ? c.loadMorePlans() : c.loadPlans();
          await tester.pump();
          if (stage == 'history') {
            service.pages.last.complete([_plan('initial')]);
            await tester.pump();
          }
          final snapshot = c.plans;
          final pageCount = service.pages.length;
          await tester.pump(const Duration(milliseconds: 21));
          await pending;
          final error = stage == 'list'
              ? c.plansLoadError
              : stage == 'history'
              ? c.planHistoryError
              : c.loadMorePlansError;
          expect(error, isA<TimeoutException>());
          expect(c.plans, same(snapshot));
          expect(c.isPlansLoading, isFalse);
          expect(c.isCheckingPlanHistory, isFalse);
          expect(c.isLoadingMorePlans, isFalse);
          if (stage != 'list') expect(c.hasPlanHistoryAction, isTrue);
          if (stage == 'history') {
            fails
                ? service.histories.last.completeError(
                    StateError('late history'),
                  )
                : service.histories.last.complete(true);
          } else if (stage == 'older date') {
            fails
                ? service.older.last.completeError(StateError('late date'))
                : service.older.last.complete(DateTime(2024));
          } else {
            fails
                ? service.pages.last.completeError(StateError('late page'))
                : service.pages.last.complete([_plan('old')]);
          }
          await tester.pump();
          expect(c.plans, same(snapshot));
          expect(service.pages.length, pageCount);
          service.gateHistory = false;
          service.gateOlder = false;
          service.more = false;
          final retry = stage == 'history'
              ? c.retryPlanHistory()
              : older
              ? c.loadMorePlans()
              : c.loadPlans();
          await tester.pump();
          if (stage != 'history') service.pages.last.complete([_plan('retry')]);
          await tester.pump();
          await retry;
          expect(c.plansLoadError, isNull);
          expect(c.planHistoryError, isNull);
          expect(c.loadMorePlansError, isNull);
          expect(c.hasPlanHistoryAction, isFalse);
          if (stage == 'history') {
            expect(c.plans, same(snapshot));
          } else {
            expect(c.plans.map((p) => p.id), contains('retry'));
          }
          if (older) expect(service.boundaries.first, service.boundaries.last);
        },
      );
    }
  }
  for (final fails in [false, true]) {
    testWidgets(
      'template timeout releases shared load and ignores late result, failure=$fails',
      (tester) async {
        final first = c.loadTemplates();
        expect(c.loadTemplates(), same(first));
        final old = service.templates.single;
        await tester.pump(const Duration(milliseconds: 21));
        await first;
        expect(c.templateLoadError, isA<TimeoutException>());
        expect(c.isTemplateLoading, isFalse);
        final retry = c.loadTemplates();
        service.templates.last.complete([_template('fresh')]);
        await tester.pump();
        await retry;
        fails
            ? old.completeError(StateError('late templates'))
            : old.complete([_template('old')]);
        await tester.pump();
        expect(c.templates.single.id, 'fresh');
        expect(c.templateLoadError, isNull);
      },
    );
    testWidgets(
      'detail timeout releases request pool without caching late response, failure=$fails',
      (tester) async {
        final first = c.loadPlanDetailIfNeeded('a');
        final joined = c.loadPlanDetailIfNeeded('a');
        expect(service.details.length, 1);
        final old = service.details.single.done;
        await tester.pump(const Duration(milliseconds: 21));
        await Future.wait([first, joined]);
        expect(c.planDetailError, isA<TimeoutException>());
        expect(c.isPlanDetailLoading, isFalse);
        final retry = c.loadPlanDetailIfNeeded('a');
        expect(service.details.length, 2);
        service.details.last.done.complete(_plan('a', 'Fresh'));
        await tester.pump();
        await retry;
        fails
            ? old.completeError(StateError('late detail'))
            : old.complete(_plan('a', 'Old'));
        await tester.pump();
        expect(c.currentPlan!.title, 'Fresh');
        expect(c.planDetailError, isNull);
        await c.loadPlanDetailIfNeeded('a');
        expect(service.details.length, 2);
      },
    );
  }
  for (final kind in ['list', 'templates', 'detail']) {
    for (final change in ['account', 'dispose']) {
      testWidgets('$kind timeout after $change does not publish stale errors', (
        tester,
      ) async {
        final pending = switch (kind) {
          'list' => c.loadPlans(),
          'templates' => c.loadTemplates(),
          _ => c.loadPlanDetailIfNeeded('a'),
        };
        if (change == 'account') {
          auth.account = 'b@example.com';
          c.updateAuth(auth);
        } else {
          c.dispose();
        }
        var notifications = 0;
        if (!c.notifierDisposed) c.addListener(() => notifications++);
        await tester.pump(const Duration(milliseconds: 21));
        await pending;
        expect(c.plansLoadError, isNull);
        expect(c.templateLoadError, isNull);
        expect(c.planDetailError, isNull);
        expect(notifications, 0);
        if (kind == 'list') {
          service.pages.single.completeError(StateError('late list'));
        } else if (kind == 'templates') {
          service.templates.single.completeError(StateError('late templates'));
        } else {
          service.details.single.done.completeError(StateError('late detail'));
        }
        await tester.pump();
        expect(c.plans, isEmpty);
        expect(c.templates, isEmpty);
        expect(c.currentPlan, isNull);
        expect(notifications, 0);
      });
    }
  }
  testWidgets(
    'read deadlines do not time out a creation write or its confirmation read',
    (tester) async {
      final pending = c.createPlanFromTemplate(title: 'New', templateId: 't');
      await tester.pump(const Duration(milliseconds: 21));
      expect(c.isCreatingPlan, isTrue);
      expect(service.creates, 1);
      expect(service.details, isEmpty);
      service.createGate.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 21));
      expect(c.isCreatingPlan, isTrue);
      expect(service.creates, 1);
      final detail = service.details.single;
      detail.done.complete(_plan(detail.id));
      await tester.pump();
      expect(await pending, isTrue);
      expect(c.isCreatingPlan, isFalse);
    },
  );
}
