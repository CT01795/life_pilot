import 'package:life_pilot/business_plan/model_business_plan.dart';
import 'package:life_pilot/business_plan/model_plan_question.dart';

typedef PlanQuestionPosition = ({int section, int question});

/// Pure question coordinates. Empty sections remain in the plan/preview, but
/// editor navigation visits questions only. No cached index: existing plan
/// section lists are mutable, so each operation inspects the current tree.
class ModelPlanNavigation {
  static ModelPlanQuestion? questionAt(
    ModelBusinessPlan? plan,
    PlanQuestionPosition position,
  ) {
    if (plan == null ||
        position.section < 0 ||
        position.section >= plan.sections.length) {
      return null;
    }
    final questions = plan.sections[position.section].questions;
    final index = position.question;
    return index < 0 || index >= questions.length ? null : questions[index];
  }

  static PlanQuestionPosition? first(ModelBusinessPlan? plan) {
    if (plan == null) return null;
    for (var s = 0; s < plan.sections.length; s++) {
      if (plan.sections[s].questions.isNotEmpty) {
        return (section: s, question: 0);
      }
    }
    return null;
  }

  static PlanQuestionPosition? adjacent(
    ModelBusinessPlan? plan,
    PlanQuestionPosition position, {
    required bool forward,
  }) {
    if (questionAt(plan, position) == null) return null;
    final sections = plan!.sections;
    final nextQuestion = position.question + (forward ? 1 : -1);
    if (nextQuestion >= 0 &&
        nextQuestion < sections[position.section].questions.length) {
      return (section: position.section, question: nextQuestion);
    }
    final step = forward ? 1 : -1;
    for (
      var s = position.section + step;
      s >= 0 && s < sections.length;
      s += step
    ) {
      final questions = sections[s].questions;
      if (questions.isNotEmpty) {
        return (section: s, question: forward ? 0 : questions.length - 1);
      }
    }
    return null;
  }

  static int count(ModelBusinessPlan? plan) =>
      plan?.sections.fold<int>(0, (sum, s) => sum + s.questions.length) ?? 0;

  static int numberAt(ModelBusinessPlan? plan, PlanQuestionPosition position) {
    if (questionAt(plan, position) == null) return 0;
    var count = position.question + 1;
    for (var s = 0; s < position.section; s++) {
      count += plan!.sections[s].questions.length;
    }
    return count;
  }
}
