enum SocialOptionFeedback { neutral, correct, incorrect }

class ModelGameSocial {
  final String id;
  final String scene;
  final List<String> options;
  final List<int> scores;
  final String correctAnswer;

  ModelGameSocial({
    required this.id,
    required this.scene,
    required List<String> options,
    required List<int> scores,
    required this.correctAnswer,
  }) : options = List.unmodifiable(options),
       scores = List.unmodifiable(scores) {
    final index = <String, int>{};
    for (var i = 0; i < options.length; i++) {
      index.putIfAbsent(options[i], () => i < scores.length ? scores[i] : -1);
    }
    _scoresByOption = Map.unmodifiable(index);
  }

  late final Map<String, int> _scoresByOption;

  int scoreFor(String option) => _scoresByOption[option] ?? -1;
}
