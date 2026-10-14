/// Maps stable game names to question sources without loading any data.
class GameQuestionSourceRules {
  const GameQuestionSourceRules._();

  static const grammarTable = 'game_grammar';
  static const sentenceTable = 'game_sentence';
  static const translationTable = 'game_translation';

  static bool isJapaneseTranslation(String gameName) =>
      gameName.toLowerCase() == 'translation (ch-jp)';

  static bool isKoreanTranslation(String gameName) =>
      gameName.toLowerCase() == 'translation (ch-kr)';

  static bool isTranslation(String gameName) =>
      gameName.toLowerCase().contains('translation');

  static String tableForGame(String gameName) {
    return switch (gameName.toLowerCase()) {
      'english rpg adventure' => grammarTable,
      'speaking' || 'word and sentence builder' => sentenceTable,
      _ => translationTable,
    };
  }

  static bool groupMatchesGame(String gameName, String group) {
    if (gameName.toLowerCase() == 'word searching') {
      return group == '英翻中Word';
    }
    if (isJapaneseTranslation(gameName)) return group.contains('日');
    if (isKoreanTranslation(gameName)) return group.contains('韓');
    if (isTranslation(gameName)) {
      return !group.contains('日') && !group.contains('韓');
    }
    return true;
  }

  static String translationRpc(String gameName) {
    if (isJapaneseTranslation(gameName)) {
      return 'get_translationjp_with_options';
    }
    if (isKoreanTranslation(gameName)) return 'get_translationkr_with_options';
    return 'get_translation_with_options';
  }
}
