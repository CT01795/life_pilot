import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:life_pilot/business_plan/controller_business_plan.dart';
import 'package:life_pilot/business_plan/model_business_plan.dart';
import 'package:life_pilot/business_plan/model_plan_navigation.dart';
import 'package:life_pilot/business_plan/model_plan_question.dart';
import 'package:life_pilot/business_plan/model_plan_section.dart';
import 'package:life_pilot/business_plan/page_plan_editor.dart';
import 'package:life_pilot/business_plan/service_business_plan.dart';
import 'package:life_pilot/l10n/app_localizations.dart';

ModelBusinessPlan _plan([List<int> sizes = const [0, 2, 0, 1, 0]]) =>
    ModelBusinessPlan(
      id: 'p',
      title: 'Plan',
      createdAt: DateTime(2026),
      sections: [
        for (var s = 0; s < sizes.length; s++)
          ModelPlanSection(
            id: '$s',
            title: 'Section $s',
            questions: [
              for (var q = 0; q < sizes[s]; q++)
                ModelPlanQuestion(
                  id: '$s-$q',
                  prompt: '$s-$q',
                  answer: 'Answer',
                ),
            ],
          ),
      ],
    );

class _Service extends ServiceBusinessPlan {
  ModelBusinessPlan plan = _plan();
  final writes = <String>[];
  @override
  Future<ModelBusinessPlan> fetchPlanDetail({required String planId}) async =>
      plan;
  @override
  Future<void> upsertAnswer({
    required String planId,
    required String sectionId,
    required String questionId,
    required String answer,
  }) async {
    writes.add(questionId);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('model skips empty chapters and preserves question coordinates', () {
    final plan = _plan();
    expect(ModelPlanNavigation.first(plan), (section: 1, question: 0));
    expect(ModelPlanNavigation.count(plan), 3);
    expect(
      ModelPlanNavigation.adjacent(plan, (
        section: 1,
        question: 1,
      ), forward: true),
      (section: 3, question: 0),
    );
    expect(
      ModelPlanNavigation.adjacent(plan, (
        section: 3,
        question: 0,
      ), forward: false),
      (section: 1, question: 1),
    );
    expect(ModelPlanNavigation.numberAt(plan, (section: 3, question: 0)), 3);
    expect(plan.sections.map((s) => s.questions.length), [0, 2, 0, 1, 0]);
  });
  for (final position in [
    (section: -1, question: 0),
    (section: 99, question: 0),
    (section: 0, question: 0),
    (section: 1, question: -1),
    (section: 1, question: 2),
  ]) {
    test(
      'invalid position $position has no question, number or adjacent target',
      () {
        final plan = _plan();
        expect(ModelPlanNavigation.questionAt(plan, position), isNull);
        expect(ModelPlanNavigation.numberAt(plan, position), 0);
        for (final forward in [true, false]) {
          expect(
            ModelPlanNavigation.adjacent(plan, position, forward: forward),
            isNull,
          );
        }
      },
    );
  }
  test(
    'model observes mutable section lists rather than caching stale positions',
    () {
      final plan = _plan();
      plan.sections[1].questions.clear();
      expect(ModelPlanNavigation.first(plan), (section: 3, question: 0));
      expect(ModelPlanNavigation.count(plan), 1);
      plan.sections[3].questions.clear();
      expect(ModelPlanNavigation.first(plan), isNull);
      expect(ModelPlanNavigation.count(plan), 0);
    },
  );
  for (final plan in [
    null,
    _plan([]),
    _plan([0, 0]),
  ]) {
    test('empty model (${plan?.sections.length}) returns empty navigation', () {
      expect(ModelPlanNavigation.first(plan), isNull);
      expect(ModelPlanNavigation.count(plan), 0);
      expect(ModelPlanNavigation.numberAt(plan, (section: 0, question: 0)), 0);
    });
  }

  group('controller', () {
    late _Service service;
    late ControllerBusinessPlan c;
    setUp(() {
      service = _Service();
      c = ControllerBusinessPlan(service: service, auth: null);
    });
    tearDown(() {
      if (!c.notifierDisposed) c.dispose();
    });
    test('detail load selects the first actual question', () async {
      await c.loadPlanDetailIfNeeded('p');
      expect(c.sectionIndex, 1);
      expect(c.currentQuestion.id, '1-0');
      expect(c.totalQuestions, 3);
      expect(c.currentQuestionNumber, 1);
      expect(c.progress, closeTo(1 / 3, 0.000001));
    });
    test(
      'forward/back navigation skips empties and does not notify at boundaries',
      () async {
        await c.loadPlanDetailIfNeeded('p');
        var notifications = 0;
        c.addListener(() => notifications++);
        expect(c.previous(), isFalse);
        expect(c.next(), isTrue);
        expect(c.currentQuestion.id, '1-1');
        expect(c.next(), isTrue);
        expect(c.currentQuestion.id, '3-0');
        expect(c.progress, 1);
        expect(c.next(), isFalse);
        expect(c.previous(), isTrue);
        expect(c.currentQuestion.id, '1-1');
        expect(c.previous(), isTrue);
        expect(c.currentQuestion.id, '1-0');
        expect(c.previous(), isFalse);
        expect(notifications, 4);
      },
    );
    test(
      'invalid and unchanged jumps retain selection without notification',
      () async {
        await c.loadPlanDetailIfNeeded('p');
        var notifications = 0;
        c.addListener(() => notifications++);
        c.jumpToQuestion(sectionIndex: 0, questionIndex: 0);
        c.jumpToQuestion(sectionIndex: -1, questionIndex: 0);
        c.jumpToQuestion(sectionIndex: 1, questionIndex: 99);
        c.jumpToQuestion(sectionIndex: 1, questionIndex: 0);
        expect(c.currentQuestion.id, '1-0');
        expect(notifications, 0);
      },
    );
    test(
      'empty or missing plan does not navigate or write an answer',
      () async {
        expect(c.totalQuestions, 0);
        expect(c.progress, 0);
        expect(c.currentQuestionNumber, 0);
        expect(c.next(), isFalse);
        expect(c.previous(), isFalse);
        expect(c.planAnswerAt(-1, 99), '');
        await c.commitCurrentAnswer('ignored');
        service.plan = _plan([0]);
        await c.loadPlanDetailIfNeeded('p');
        expect(c.selectedQuestion, isNull);
        await c.commitCurrentAnswer('ignored');
        expect(service.writes, isEmpty);
      },
    );
    test(
      'cached detail retains valid selection and repairs invalid selection',
      () async {
        await c.loadPlanDetailIfNeeded('p');
        c.jumpToQuestion(sectionIndex: 3, questionIndex: 0);
        await c.loadPlanDetailIfNeeded('p');
        expect(c.currentQuestion.id, '3-0');
        c.sectionIndex = 0;
        await c.loadPlanDetailIfNeeded('p');
        expect(c.currentQuestion.id, '1-0');
      },
    );
    test('disposed controller cannot move its selection', () async {
      await c.loadPlanDetailIfNeeded('p');
      c.dispose();
      expect(c.next(), isFalse);
      expect(c.previous(), isFalse);
      c.jumpToQuestion(sectionIndex: 3, questionIndex: 0);
      expect(c.currentQuestion.id, '1-0');
    });
    test(
      'saving after skipping an empty chapter targets the selected question',
      () async {
        await c.loadPlanDetailIfNeeded('p');
        c.next();
        c.next();
        await c.commitCurrentAnswer('Updated');
        expect(service.writes, ['3-0']);
        expect(c.currentQuestion.answer, 'Updated');
        expect(c.planAnswerAt(1, 0), 'Answer');
        expect(c.planAnswerAt(0, 0), '');
      },
    );
  });

  for (final language in ['en', 'zh', 'ja', 'ko']) {
    testWidgets('empty editor renders without an HTML plugin in $language', (
      tester,
    ) async {
      final c = ControllerBusinessPlan(service: _Service(), auth: null);
      addTearDown(c.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: c,
          child: MaterialApp(
            locale: Locale(language),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const PagePlanEditor(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
