import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/business_plan/controller_business_plan.dart';
import 'package:life_pilot/business_plan/model_business_plan.dart';
import 'package:life_pilot/business_plan/model_plan_template.dart';
import 'package:life_pilot/business_plan/model_plan_section.dart';
import 'package:life_pilot/business_plan/model_plan_question.dart';
import 'package:life_pilot/business_plan/page_plan_preview.dart';
import 'package:life_pilot/business_plan/page_plan_select_template.dart';
import 'package:life_pilot/business_plan/service_business_plan.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

ModelBusinessPlan _plan(String id) => ModelBusinessPlan(
  id: id,
  title: id,
  createdAt: DateTime(2026, 10, 15),
  sections: [],
);

class _Auth extends ControllerAuth {
  String account = 'a@example.com';
  @override
  String get currentAccount => account;
}

class _Service extends ServiceBusinessPlan {
  ModelBusinessPlan Function(String) planFactory = _plan;
  final reads = <String>[];
  final creates = <(String, String, String)>[];
  final pending = <String, Completer<ModelBusinessPlan>>{};
  Completer<void>? pendingCreate;
  bool failRead = false;
  bool failCreate = false;
  void Function()? onRead;
  @override
  Future<void> upsertAnswer({
    required String planId,
    required String sectionId,
    required String questionId,
    required String answer,
  }) async {}
  @override
  Future<ModelBusinessPlan> fetchPlanDetail({required String planId}) async {
    reads.add(planId);
    onRead?.call();
    if (failRead) throw StateError('offline');
    return pending[planId]?.future ?? Future.value(planFactory(planId));
  }

  @override
  Future<void> createPlanFromTemplate({
    required String user,
    required String planId,
    required String title,
    required String templateId,
  }) async {
    creates.add((user, planId, title));
    if (pendingCreate != null) await pendingCreate!.future;
    if (failCreate) throw StateError('create failed');
  }

  @override
  Future<List<ModelPlanTemplate>> fetchTemplates() async => [
    ModelPlanTemplate(id: 't', title: 'Template', description: ''),
  ];
}

Widget _app(ControllerBusinessPlan controller, Widget child) =>
    ChangeNotifierProvider.value(
      value: controller,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'reentrant loading listener does not recursively publish the same state',
    () async {
      final service = _Service()..pending['a'] = Completer<ModelBusinessPlan>();
      final auth = _Auth();
      final c = ControllerBusinessPlan(service: service, auth: auth);
      addTearDown(c.dispose);
      addTearDown(auth.dispose);
      final nested = <Future<void>>[];
      var notifications = 0;
      c.addListener(() {
        notifications++;
        // Limit recursion so a regression reports an assertion, not stack overflow.
        if (c.isPlanDetailLoading && notifications < 5) {
          nested.add(c.loadPlanDetailIfNeeded('a'));
        }
      });
      final first = c.loadPlanDetailIfNeeded('a');
      expect(notifications, 1);
      expect(service.reads, ['a']);
      service.pending['a']!.complete(_plan('a'));
      await Future.wait([first, ...nested]);
      expect(c.currentPlan!.id, 'a');
      expect(c.isPlanDetailLoading, isFalse);
    },
  );
  test(
    'synchronous service callback joins the registered detail read',
    () async {
      final service = _Service()..pending['a'] = Completer<ModelBusinessPlan>();
      final auth = _Auth();
      final c = ControllerBusinessPlan(service: service, auth: auth);
      addTearDown(c.dispose);
      addTearDown(auth.dispose);
      Future<void>? nested;
      service.onRead = () {
        service.onRead = null;
        nested = c.loadPlanDetailIfNeeded('a');
      };
      final first = c.loadPlanDetailIfNeeded('a');
      expect(service.reads, ['a']);
      service.pending['a']!.complete(_plan('a'));
      await Future.wait([first, nested!]);
      expect(c.currentPlan!.id, 'a');
    },
  );
  test(
    'switching back to a pending plan publishes selection without rereading',
    () async {
      final service = _Service()
        ..pending['a'] = Completer<ModelBusinessPlan>()
        ..pending['b'] = Completer<ModelBusinessPlan>();
      final auth = _Auth();
      final c = ControllerBusinessPlan(service: service, auth: auth);
      addTearDown(c.dispose);
      addTearDown(auth.dispose);
      final a = c.loadPlanDetailIfNeeded('a'),
          b = c.loadPlanDetailIfNeeded('b');
      var notifications = 0;
      c.addListener(() => notifications++);
      final back = c.loadPlanDetailIfNeeded('a');
      expect(notifications, 1);
      expect(c.currentPlanId, 'a');
      expect(service.reads, ['a', 'b']);
      service.pending['a']!.complete(_plan('a'));
      await Future.wait([a, back]);
      service.pending['b']!.complete(_plan('b'));
      await b;
      expect(c.currentPlan!.id, 'a');
    },
  );
  test(
    'account change during loading publication prevents an unsent detail read',
    () async {
      final service = _Service();
      final auth = _Auth();
      final c = ControllerBusinessPlan(service: service, auth: auth);
      addTearDown(c.dispose);
      addTearDown(auth.dispose);
      c.addListener(() {
        if (c.isPlanDetailLoading) {
          auth.account = 'b@example.com';
          c.updateAuth(auth, notify: false);
        }
      });
      await c.loadPlanDetailIfNeeded('a');
      expect(service.reads, isEmpty);
      expect(c.currentPlan, isNull);
      expect(c.planDetailError, isNull);
      expect(c.isPlanDetailLoading, isFalse);
    },
  );
  test(
    'account change during creation publication prevents an unsent write',
    () async {
      final service = _Service();
      final auth = _Auth();
      final c = ControllerBusinessPlan(service: service, auth: auth);
      addTearDown(c.dispose);
      addTearDown(auth.dispose);
      c.addListener(() {
        if (c.isCreatingPlan) {
          auth.account = 'b@example.com';
          c.updateAuth(auth, notify: false);
        }
      });
      expect(
        await c.createPlanFromTemplate(title: 'Plan', templateId: 't'),
        isFalse,
      );
      expect(service.creates, isEmpty);
      expect(service.reads, isEmpty);
    },
  );

  testWidgets('preview index refreshes after plan edits and saved answers', (
    tester,
  ) async {
    final service = _Service()
      ..planFactory = (id) => _plan(id).copyWith(
        sections: [
          ModelPlanSection(
            id: 's',
            title: 'Section before',
            questions: [
              ModelPlanQuestion(
                id: 'q',
                prompt: 'Question',
                answer: 'Answer before',
                sortOrder: 0,
              ),
            ],
          ),
        ],
      );
    final c = ControllerBusinessPlan(service: service, auth: _Auth())
      ..setCurrentPlanSummary(_plan('a'));
    addTearDown(c.dispose);
    await tester.pumpWidget(_app(c, const PagePlanPreview()));
    await tester.pumpAndSettle();
    expect(find.text('Section before'), findsOneWidget);
    expect(find.text('Answer before'), findsOneWidget);
    c.currentPlan = c.currentPlan!.copyWith(
      sections: [
        c.currentPlan!.sections.first.copyWith(title: 'Section after'),
      ],
    );
    c.safeNotify();
    await tester.pumpAndSettle();
    expect(find.text('Section before'), findsNothing);
    expect(find.text('Section after'), findsOneWidget);
    await c.commitCurrentAnswer('Answer after');
    c.safeNotify();
    await tester.pumpAndSettle();
    expect(find.text('Answer before'), findsNothing);
    expect(find.text('Answer after'), findsOneWidget);
    expect(service.reads, ['a']);
    expect(tester.takeException(), isNull);
  });

  test(
    'creation skips empty sections when choosing the first editable question',
    () async {
      final service = _Service()
        ..planFactory = (id) => _plan(id).copyWith(
          sections: [
            ModelPlanSection(id: 'empty', title: 'Empty', questions: []),
            ModelPlanSection(
              id: 'filled',
              title: 'Filled',
              questions: [
                ModelPlanQuestion(
                  id: 'q',
                  prompt: 'Question',
                  answer: '',
                  sortOrder: 0,
                ),
              ],
            ),
          ],
        );
      final c = ControllerBusinessPlan(service: service, auth: _Auth());
      addTearDown(c.dispose);
      expect(
        await c.createPlanFromTemplate(title: 'New', templateId: 't'),
        true,
      );
      expect(c.sectionIndex, 1);
      expect(c.currentQuestion.id, 'q');
    },
  );
  testWidgets(
    'empty created plan opens preview without entering a question editor',
    (tester) async {
      final service = _Service();
      final c = ControllerBusinessPlan(service: service, auth: _Auth());
      addTearDown(c.dispose);
      await tester.pumpWidget(_app(c, const PagePlanSelectTemplate()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Template'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'New');
      final loc = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.pump();
      await tester.tap(find.text(loc.create));
      await tester.pumpAndSettle();
      expect(service.creates, hasLength(1));
      expect(service.reads, hasLength(1));
      expect(find.byType(PagePlanPreview), findsOneWidget);
      expect(find.text(loc.noData), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'concurrent detail reads share one request and empty detail is cached',
    () async {
      final service = _Service()..pending['a'] = Completer<ModelBusinessPlan>();
      final c = ControllerBusinessPlan(service: service, auth: _Auth());
      addTearDown(c.dispose);
      final first = c.loadPlanDetailIfNeeded('a');
      final second = c.loadPlanDetailIfNeeded('a');
      expect(service.reads, ['a']);
      service.pending['a']!.complete(_plan('a'));
      await Future.wait([first, second]);
      await c.loadPlanDetailIfNeeded('a');
      expect(service.reads, ['a']);
      expect(c.currentPlan!.sections, isEmpty);
      expect(c.isPlanDetailLoading, false);
    },
  );
  test('late detail cannot overwrite a different selected plan', () async {
    final service = _Service()..pending['a'] = Completer<ModelBusinessPlan>();
    final c = ControllerBusinessPlan(service: service, auth: _Auth());
    addTearDown(c.dispose);
    final first = c.loadPlanDetailIfNeeded('a');
    await c.loadPlanDetailIfNeeded('b');
    service.pending['a']!.complete(_plan('a'));
    await first;
    expect(c.currentPlan!.id, 'b');
    expect(c.currentPlanId, 'b');
  });
  test(
    'account change prevents old details from entering the new account cache',
    () async {
      final auth = _Auth();
      final service = _Service()..pending['a'] = Completer<ModelBusinessPlan>();
      final c = ControllerBusinessPlan(service: service, auth: auth);
      addTearDown(c.dispose);
      final first = c.loadPlanDetailIfNeeded('a');
      auth.account = 'b@example.com';
      c.updateAuth(auth);
      service.pending['a']!.complete(_plan('a'));
      await first;
      expect(c.currentPlan, isNull);
      service.pending.clear();
      await c.loadPlanDetailIfNeeded('a');
      expect(service.reads, ['a', 'a']);
    },
  );
  test(
    'detail failure exposes retry state without an uncaught error',
    () async {
      final service = _Service()..failRead = true;
      final c = ControllerBusinessPlan(service: service, auth: _Auth());
      addTearDown(c.dispose);
      await c.loadPlanDetailIfNeeded('a');
      expect(c.planDetailError, isStateError);
      expect(c.isPlanDetailLoading, false);
      service.failRead = false;
      await c.loadPlanDetailIfNeeded('a');
      expect(c.planDetailError, isNull);
      expect(c.currentPlan!.id, 'a');
    },
  );
  test(
    'duplicate creates are blocked and successful detail is cached',
    () async {
      final service = _Service()..pendingCreate = Completer<void>();
      final c = ControllerBusinessPlan(service: service, auth: _Auth());
      addTearDown(c.dispose);
      final first = c.createPlanFromTemplate(title: ' New ', templateId: 't');
      expect(c.isCreatingPlan, true);
      expect(
        await c.createPlanFromTemplate(title: 'New', templateId: 't'),
        false,
      );
      service.pendingCreate!.complete();
      expect(await first, true);
      expect(service.creates, hasLength(1));
      expect(service.creates.single.$3, 'New');
      expect(c.currentPlanId, service.creates.single.$2);
      expect(c.plans.single.id, service.creates.single.$2);
      await c.loadPlanDetailIfNeeded(c.currentPlanId!);
      expect(service.reads, hasLength(1));
      expect(c.isCreatingPlan, false);
    },
  );
  test('creation failure releases busy state', () async {
    final service = _Service()..failCreate = true;
    final c = ControllerBusinessPlan(service: service, auth: _Auth());
    addTearDown(c.dispose);
    await expectLater(
      c.createPlanFromTemplate(title: 'New', templateId: 't'),
      throwsStateError,
    );
    expect(c.isCreatingPlan, false);
    expect(c.currentPlan, isNull);
  });
  test(
    'account change during creation prevents follow-up detail and navigation result',
    () async {
      final auth = _Auth();
      final service = _Service()..pendingCreate = Completer<void>();
      final c = ControllerBusinessPlan(service: service, auth: auth);
      addTearDown(c.dispose);
      final request = c.createPlanFromTemplate(title: 'New', templateId: 't');
      auth.account = 'b@example.com';
      c.updateAuth(auth);
      service.pendingCreate!.complete();
      expect(await request, false);
      expect(service.reads, isEmpty);
      expect(c.currentPlan, isNull);
    },
  );
  test('dispose ignores pending details', () async {
    final service = _Service()..pending['a'] = Completer<ModelBusinessPlan>();
    final c = ControllerBusinessPlan(service: service, auth: _Auth());
    final request = c.loadPlanDetailIfNeeded('a');
    c.dispose();
    service.pending['a']!.complete(_plan('a'));
    await request;
    expect(c.currentPlan, isNull);
  });
  testWidgets('preview shows empty data instead of a permanent loading state', (
    tester,
  ) async {
    final service = _Service();
    final c = ControllerBusinessPlan(service: service, auth: _Auth())
      ..setCurrentPlanSummary(_plan('a'));
    addTearDown(c.dispose);
    await tester.pumpWidget(_app(c, const PagePlanPreview()));
    await tester.pumpAndSettle();
    final loc = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(loc.noData), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(service.reads, ['a']);
    expect(tester.takeException(), isNull);
  });
  testWidgets('preview failure can be retried', (tester) async {
    final service = _Service()..failRead = true;
    final c = ControllerBusinessPlan(service: service, auth: _Auth())
      ..setCurrentPlanSummary(_plan('a'));
    addTearDown(c.dispose);
    await tester.pumpWidget(_app(c, const PagePlanPreview()));
    await tester.pumpAndSettle();
    final loc = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(loc.retry), findsOneWidget);
    service.failRead = false;
    await tester.tap(find.text(loc.retry));
    await tester.pumpAndSettle();
    expect(find.text(loc.noData), findsOneWidget);
    expect(service.reads, ['a', 'a']);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'template title dialog rejects whitespace and cancellation does not create',
    (tester) async {
      final service = _Service();
      final c = ControllerBusinessPlan(service: service, auth: _Auth());
      addTearDown(c.dispose);
      await tester.pumpWidget(_app(c, const PagePlanSelectTemplate()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Template'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump();
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
      final loc = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.tap(find.text(loc.cancel));
      await tester.pumpAndSettle();
      expect(service.creates, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
