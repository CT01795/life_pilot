import 'package:life_pilot/business_plan/model_plan_section.dart';

class ModelBusinessPlan {
  final String id;
  final String title;
  final DateTime createdAt;
  final String status;
  final List<ModelPlanSection> sections;

  ModelBusinessPlan({
    required this.id,
    required this.title,
    required this.createdAt,
    this.status = 'not_started',
    required this.sections,
  });

  ModelBusinessPlan copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    String? status,
    List<ModelPlanSection>? sections,
  }) {
    return ModelBusinessPlan(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      sections: sections ?? this.sections.map((e) => e.copyWith()).toList(),
    );
  }
}
