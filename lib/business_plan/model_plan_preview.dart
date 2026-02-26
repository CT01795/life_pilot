import 'package:life_pilot/business_plan/model_plan_question.dart';

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

  const PlanQuestionItem(
    this.sectionIndex,
    this.questionIndex,
    this.question,
  );
}
