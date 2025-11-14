class GameWordMatch {
  final String questionId;
  final String question;
  final List<String> options; // 3 個答案
  final String correctAnswer;
  bool? isRight;

  GameWordMatch({
    required this.questionId,
    required this.question,
    required this.options,
    required this.correctAnswer,
    this.isRight,
  });
}