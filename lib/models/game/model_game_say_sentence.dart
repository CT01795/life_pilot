class ModelGameSaySentence {
  final String questionId;
  final String question;
  final String correctAnswer;
  final String type;
  bool? isRight;

  ModelGameSaySentence({
    required this.questionId,
    required this.question,
    required this.correctAnswer,
    required this.type,
    this.isRight,
  });
}
