class ModelPlanQuestion {
  final String id;
  final String prompt;
  final String answer;
  final int sortOrder;

  ModelPlanQuestion(
      {required this.id,
      required this.prompt,
      this.answer = '',
      this.sortOrder = 0});

  ModelPlanQuestion copyWith({
    String? id,
    String? prompt,
    String? answer,
    int? sortOrder,
  }) {
    return ModelPlanQuestion(
      id: id ?? this.id,
      prompt: prompt ?? this.prompt,
      answer: answer ?? this.answer,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}
