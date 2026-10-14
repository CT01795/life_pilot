import 'package:life_pilot/game/game_question_source_rules.dart';

/// Result shared by all question-bank sources, independent of data loading.
class QuestionBankAvailability {
  const QuestionBankAvailability({
    required this.questionCount,
    required this.canPlay,
    required this.requiresThreeInGroup,
  });

  factory QuestionBankAvailability.forGame({
    required String gameName,
    required int questionCount,
  }) {
    final requiresThree = GameQuestionSourceRules.isTranslation(gameName);
    return QuestionBankAvailability(
      questionCount: questionCount,
      canPlay: questionCount >= (requiresThree ? 3 : 1),
      requiresThreeInGroup: requiresThree,
    );
  }

  final int questionCount;
  final bool canPlay;

  /// Legacy field name retained for callers; the threshold applies to the
  /// total usable question count, rather than each individual category.
  final bool requiresThreeInGroup;
}
