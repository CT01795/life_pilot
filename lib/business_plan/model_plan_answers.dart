import 'package:life_pilot/business_plan/model_business_plan.dart';

/// Immutable answer updates by stable IDs, independent of the editor cursor.
class ModelPlanAnswers {
  static ModelBusinessPlan replace(
    ModelBusinessPlan plan, {
    required String sectionId,
    required String questionId,
    required String answer,
    String? expectedAnswer,
  }) {
    final s = plan.sections.indexWhere((section) => section.id == sectionId);
    if (s < 0) return plan;
    final section = plan.sections[s];
    final q = section.questions.indexWhere(
      (question) => question.id == questionId,
    );
    if (q < 0) return plan;
    final question = section.questions[q];
    if (question.answer == answer ||
        (expectedAnswer != null && question.answer != expectedAnswer)) {
      return plan;
    }
    final questions = [...section.questions];
    questions[q] = question.copyWith(answer: answer);
    final sections = [...plan.sections];
    sections[s] = section.copyWith(questions: questions);
    return plan.copyWith(sections: sections);
  }
}
