class ModelGameSocial {
  final String id;
  final String scene;
  final List<String> options;
  final List<int> scores;
  final String correctAnswer;

  ModelGameSocial({
    required this.id,
    required this.scene,
    required this.options,
    required this.scores,
    required this.correctAnswer,
  });
}