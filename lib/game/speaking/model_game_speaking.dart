class ModelGameSpeaking {
  final String questionId;
  final String question;
  final String correctAnswer;
  final String type;
  bool? isRight;

  ModelGameSpeaking({
    required this.questionId,
    required this.question,
    required this.correctAnswer,
    required this.type,
    this.isRight,
  });

  /// Preserve the existing comparison: case, spaces and periods are ignored.
  bool matchesAnswer(String answer) =>
      _normalize(correctAnswer) == _normalize(answer);

  static String _normalize(String value) =>
      value.toLowerCase().replaceAll(' ', '').replaceAll('.', '');
}

class SpeakingAttemptResult {
  final bool isCorrect;
  final bool completesQuestion;
  final int points;

  const SpeakingAttemptResult({
    required this.isCorrect,
    required this.completesQuestion,
    required this.points,
  });
}

/// A question allows two attempts; completing either way earns four points.
class ModelSpeakingRound {
  final ModelGameSpeaking question;
  int _attempts = 0;
  SpeakingAttemptResult? _lastResult;

  ModelSpeakingRound(this.question);
  int get attempts => _attempts;
  bool? get isCorrect => _lastResult?.isCorrect;
  bool get isComplete => _lastResult?.completesQuestion ?? false;

  SpeakingAttemptResult? answer(String answer) {
    if (answer.isEmpty || isComplete) return null;
    _attempts++;
    final correct = question.matchesAnswer(answer);
    final complete = correct || _attempts >= 2;
    return _lastResult = SpeakingAttemptResult(
      isCorrect: correct,
      completesQuestion: complete,
      points: complete ? 4 : 0,
    );
  }
}
