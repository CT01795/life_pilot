import 'package:life_pilot/business_plan/model_plan_question.dart';
import 'package:life_pilot/business_plan/model_business_plan.dart';

/// One plan snapshot's flat preview order. No HTML parsing, network calls or
/// shared cache; the View owns its index and replaces it when the plan changes.
class PlanPreviewIndex {
  PlanPreviewIndex._(this._plan, this.items);
  final ModelBusinessPlan _plan;
  final List<PlanPreviewItem> items;

  factory PlanPreviewIndex(ModelBusinessPlan plan) {
    final items = <PlanPreviewItem>[];
    final sections = plan.sections;
    for (var s = 0; s < sections.length; s++) {
      final section = sections[s];
      items.add(PlanSectionItem(section.title));
      final questions = section.questions;
      for (var q = 0; q < questions.length; q++) {
        items.add(PlanQuestionItem(s, q, questions[q]));
      }
    }
    return PlanPreviewIndex._(plan, List.unmodifiable(items));
  }

  bool matches(ModelBusinessPlan plan) => identical(_plan, plan);
}

sealed class PlanPreviewItem {
  const PlanPreviewItem();
}

class PlanSectionItem extends PlanPreviewItem {
  final String title;
  const PlanSectionItem(this.title);
}

class PlanQuestionItem extends PlanPreviewItem {
  final int sectionIndex;
  final int questionIndex;
  final ModelPlanQuestion question;

  const PlanQuestionItem(this.sectionIndex, this.questionIndex, this.question);
}
