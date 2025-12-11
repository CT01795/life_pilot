class ModelGameSentence {
  final String questionId;
  final String question;
  final List<String> options;
  final String correctAnswer;
  final String type;
  bool? isRight;

  ModelGameSentence({
    required this.questionId,
    required this.question,
    required this.options,
    required this.correctAnswer,
    required this.type,
    this.isRight,
  });
}

class WordItem {
  final String id;     // 唯一識別
  final String text;

  WordItem({required this.id, required this.text});
}
