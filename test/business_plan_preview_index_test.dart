import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/business_plan/model_business_plan.dart';
import 'package:life_pilot/business_plan/model_plan_preview.dart';
import 'package:life_pilot/business_plan/model_plan_section.dart';
import 'package:life_pilot/business_plan/model_plan_question.dart';

ModelBusinessPlan _plan(List<ModelPlanSection> sections) => ModelBusinessPlan(
  id: 'plan',
  title: 'Plan',
  createdAt: DateTime(2026),
  sections: sections,
);
ModelPlanQuestion _question(String id, [String answer = '']) =>
    ModelPlanQuestion(id: id, prompt: id, answer: answer);

class _CountedSection extends ModelPlanSection {
  _CountedSection(int id)
    : super(
        id: '$id',
        title: 'Section $id',
        questions: List.generate(100, (q) => _question('$id-$q')),
      );
  int reads = 0;
  @override
  List<ModelPlanQuestion> get questions {
    reads++;
    return super.questions;
  }
}

void main() {
  test(
    'flat order preserves section headers, empty sections and editor coordinates',
    () {
      final a = _question('a'), b = _question('b');
      final plan = _plan([
        ModelPlanSection(id: '0', title: 'Empty', questions: []),
        ModelPlanSection(id: '1', title: 'Filled', questions: [a, b]),
        ModelPlanSection(id: '2', title: 'Last', questions: []),
      ]);
      final index = PlanPreviewIndex(plan);
      expect(index.items, hasLength(5));
      expect((index.items[0] as PlanSectionItem).title, 'Empty');
      expect((index.items[1] as PlanSectionItem).title, 'Filled');
      final first = index.items[2] as PlanQuestionItem;
      final second = index.items[3] as PlanQuestionItem;
      expect((first.sectionIndex, first.questionIndex), (1, 0));
      expect((second.sectionIndex, second.questionIndex), (1, 1));
      expect(first.question, same(a));
      expect(second.question, same(b));
      expect((index.items.last as PlanSectionItem).title, 'Last');
      expect(() => index.items.clear(), throwsUnsupportedError);
    },
  );

  test(
    'large preview reads each section once and indexing does not rescan',
    () {
      final sections = List.generate(100, _CountedSection.new);
      final index = PlanPreviewIndex(_plan(sections));
      expect(index.items, hasLength(10100));
      for (var i = 0; i < index.items.length; i++) {
        expect(index.items[i], isA<PlanPreviewItem>());
      }
      expect(sections.every((section) => section.reads == 1), isTrue);
      final last = index.items.last as PlanQuestionItem;
      expect((last.sectionIndex, last.questionIndex), (99, 99));
    },
  );

  test('empty plan has no fake loading row', () {
    expect(PlanPreviewIndex(_plan([])).items, isEmpty);
  });

  test(
    'same-ID updated plans invalidate the index without changing old answers',
    () {
      final old = _plan([
        ModelPlanSection(
          id: 's',
          title: 'Before',
          questions: [_question('q', '<p>Before</p>')],
        ),
      ]);
      final index = PlanPreviewIndex(old);
      expect(index.matches(old), isTrue);
      final updated = old.copyWith(
        sections: [
          old.sections.first.copyWith(
            title: 'After',
            questions: [_question('q', '<p>After</p>')],
          ),
        ],
      );
      expect(index.matches(updated), isFalse);
      final next = PlanPreviewIndex(updated);
      expect((next.items.first as PlanSectionItem).title, 'After');
      expect(
        (next.items.last as PlanQuestionItem).question.answer,
        '<p>After</p>',
      );
      expect(
        (index.items.last as PlanQuestionItem).question.answer,
        '<p>Before</p>',
      );
    },
  );
}
