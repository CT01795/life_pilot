import 'package:life_pilot/game/model_game_user.dart';

/// Derived once per record update, rather than during every View rebuild.
class ModelGameProgressSummary {
  const ModelGameProgressSummary({
    required this.attempts,
    required this.passed,
    required this.bestScore,
  });

  factory ModelGameProgressSummary.from(List<ModelGameUser> records) {
    var passed = 0;
    num? bestScore;
    for (final record in records) {
      if (record.isPass == true) passed++;
      final score = record.score;
      if (score != null && (bestScore == null || score > bestScore)) {
        bestScore = score;
      }
    }
    return ModelGameProgressSummary(
      attempts: records.length,
      passed: passed,
      bestScore: bestScore,
    );
  }

  final int attempts;
  final int passed;
  final num? bestScore;
}
