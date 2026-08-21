class GameQuestionAuthoringRules {
  const GameQuestionAuthoringRules._();

  static bool isNumberedLanguageGame(String gameName) =>
      gameName.contains('日') || gameName.contains('韓');

  static bool canCreateCustomGroup({
    required bool isAdmin,
    required String gameName,
  }) =>
      isAdmin || isNumberedLanguageGame(gameName);

  static String groupWithoutLevel(String group) =>
      group.trim().replaceFirst(RegExp(r'\d+$'), '');

  static int levelFromGroup(String group) {
    final match = RegExp(r'(\d+)$').firstMatch(group.trim());
    return int.tryParse(match?.group(1) ?? '') ?? 1;
  }

  static String numberedGroup({
    required String base,
    required String suffix,
  }) {
    final normalizedBase = groupWithoutLevel(base);
    final normalizedSuffix = suffix.trim();
    return normalizedSuffix.isEmpty || normalizedSuffix == '1'
        ? normalizedBase
        : '$normalizedBase$normalizedSuffix';
  }

  static String sentenceQuestion(String answer) {
    final normalizedAnswer = answer.trim();
    final parts = normalizedAnswer.contains(RegExp(r'\s'))
        ? normalizedAnswer.split(RegExp(r'\s+'))
        : normalizedAnswer.split('');
    return parts.join('_');
  }

  static String grammarQuestion({
    required String completedQuestion,
    required String answer,
    required bool isPlural,
  }) {
    final normalizedQuestion = completedQuestion.trim();
    final normalizedAnswer = answer.trim();
    if (isPlural) return '$normalizedQuestion <--> many ______';
    return normalizedQuestion.replaceFirst(normalizedAnswer, '______');
  }

  static bool grammarAnswerAppears({
    required String completedQuestion,
    required String answer,
  }) =>
      completedQuestion.trim().contains(answer.trim());

  static String grammarHint({
    required String question,
    required String answer,
    required bool isPlural,
  }) {
    if (isPlural) {
      final beforeArrow = question.split(RegExp(r'\s*(?:<|↔)')).first.trim();
      if (beforeArrow.isNotEmpty && beforeArrow != question.trim()) {
        return beforeArrow;
      }
      final beforeMany = question
          .split(RegExp(r'\s+many\s+', caseSensitive: false))
          .first
          .trim();
      if (beforeMany.isNotEmpty) return beforeMany;
    }
    return question.replaceFirst(RegExp(r'_{2,}'), answer);
  }
}
