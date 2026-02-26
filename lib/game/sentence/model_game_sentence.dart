// ignore_for_file: public_member_api_docs, sort_constructors_first
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

  String buildUserAnswer(List<WordItem?> slots) {
  return slots
    .map((e) => e?.text ?? '')
    .join(type == 'word' ? '' : ' ');
}
}

class WordItem {
  final String id;     // 唯一識別
  final String text;

  WordItem({required this.id, required this.text});
}

class GameState {
  List<WordItem> options;
  List<WordItem?> answerSlots;
  bool? isRightAnswer;
  int answeredCount;

  GameState({
    required this.options,
    required this.answerSlots,
    required this.isRightAnswer,
    required this.answeredCount,
  });
}
