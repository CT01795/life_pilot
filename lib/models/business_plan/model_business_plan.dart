import 'package:life_pilot/models/business_plan/model_plan_section.dart';

class ModelBusinessPlan {
  final String id;
  final String title;
  final DateTime createdAt;
  final List<ModelPlanSection> sections;

  ModelBusinessPlan({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.sections,
  });

  ModelBusinessPlan copyWith({
    String? title,
    List<ModelPlanSection>? sections,
  }) {
    return ModelBusinessPlan(
      id: id,
      title: title ?? this.title,
      createdAt: createdAt,
      sections: sections ?? this.sections,
    );
  }
}