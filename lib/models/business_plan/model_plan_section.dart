import 'model_plan_question.dart';

class ModelPlanSection {
  final String id;
  final String title;
  final List<ModelPlanQuestion> questions;

  ModelPlanSection({
    required this.id,
    required this.title,
    required this.questions,
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