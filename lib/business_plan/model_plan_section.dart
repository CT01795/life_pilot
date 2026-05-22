import 'model_plan_question.dart';

class ModelPlanSection {
  final String id;
  final String title;
  final List<ModelPlanQuestion> questions;
  final int sortOrder;

  ModelPlanSection(
      {required this.id,
      required this.title,
      required this.questions,
      this.sortOrder = 0});

  ModelPlanSection copyWith({
    String? id,
    String? title,
    int? sortOrder,
    List<ModelPlanQuestion>? questions,
  }) {
    return ModelPlanSection(
      id: id ?? this.id,
      title: title ?? this.title,
      sortOrder: sortOrder ?? this.sortOrder,
      questions: questions ?? this.questions.map((e) => e.copyWith()).toList(),
    );
  }
}
