import 'model_plan_question.dart';

class ModelPlanSection {
  final String id;
  final String title;
  final List<ModelPlanQuestion> questions;
  final int sortOrder;

  ModelPlanSection({
    required this.id,
    required this.title,
    required this.questions,
    this.sortOrder = 0
  });

  ModelPlanSection copyWith({
    List<ModelPlanQuestion>? questions,
  }) {
    return ModelPlanSection(
      id: id,
      title: title,
      questions: questions ?? this.questions,
    );
  }
}
