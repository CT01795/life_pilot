class ModelPlanQuestion {
  final String id;
  final String prompt;
  final String answer;

  ModelPlanQuestion({
    required this.id,
    required this.prompt,
    this.answer = '',
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
