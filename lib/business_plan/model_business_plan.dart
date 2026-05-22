import 'package:life_pilot/business_plan/model_plan_section.dart';

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
    String? id,
    String? title,
    DateTime? createdAt,
    List<ModelPlanSection>? sections,
  }) {
    return ModelBusinessPlan(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      sections: sections ?? this.sections.map((e) => e.copyWith()).toList(),
    );
  }
}