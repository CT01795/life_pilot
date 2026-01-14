class ModelPlanQuestion {
  final String id;
  final String prompt;
  final String answer;
  final int sortOrder;

  ModelPlanQuestion({
    required this.id,
    required this.prompt,
    this.answer = '',
    this.sortOrder = 0
  });

  ModelPlanQuestion copyWith({
    String? answer,
  }) {
    return ModelPlanQuestion(
      id: id,
      prompt: prompt,
      answer: answer ?? this.answer,
    );
  }
}
