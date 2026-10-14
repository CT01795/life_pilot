import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/game/game_question_source_rules.dart';

void main() {
  test('games use their existing grammar sentence or translation tables', () {
    expect(
      GameQuestionSourceRules.tableForGame('English RPG Adventure'),
      'game_grammar',
    );
    for (final name in ['Speaking', 'Word and Sentence Builder']) {
      expect(GameQuestionSourceRules.tableForGame(name), 'game_sentence');
    }
    for (final name in [
      'Translation (CH-EN)',
      'Translation (CH-JP)',
      'Translation (CH-KR)',
      'Mario translation',
      'Word Searching',
    ]) {
      expect(GameQuestionSourceRules.tableForGame(name), 'game_translation');
    }
  });

  test('Japanese and Korean translations only match their own groups', () {
    expect(
      GameQuestionSourceRules.groupMatchesGame('Translation (CH-JP)', '日翻中句子2'),
      isTrue,
    );
    expect(
      GameQuestionSourceRules.groupMatchesGame('Translation (CH-JP)', '韓翻中句子'),
      isFalse,
    );
    expect(
      GameQuestionSourceRules.groupMatchesGame('Translation (CH-KR)', '韓翻中句子3'),
      isTrue,
    );
    expect(
      GameQuestionSourceRules.groupMatchesGame('Translation (CH-KR)', '日翻中句子'),
      isFalse,
    );
  });

  test('English and Mario translation exclude Japanese and Korean groups', () {
    for (final name in ['Translation (CH-EN)', 'Mario translation']) {
      expect(GameQuestionSourceRules.groupMatchesGame(name, '英翻中Word'), isTrue);
      expect(GameQuestionSourceRules.groupMatchesGame(name, '日翻中句子'), isFalse);
      expect(GameQuestionSourceRules.groupMatchesGame(name, '韓翻中句子'), isFalse);
    }
  });

  test('word searching retains its exact group match', () {
    expect(
      GameQuestionSourceRules.groupMatchesGame('Word Searching', '英翻中Word'),
      isTrue,
    );
    expect(
      GameQuestionSourceRules.groupMatchesGame('Word Searching', '英翻中Word2'),
      isFalse,
    );
    expect(GameQuestionSourceRules.groupMatchesGame('Speaking', 'any'), isTrue);
  });

  test(
    'RPC names preserve language selection and case-insensitive handling',
    () {
      expect(
        GameQuestionSourceRules.translationRpc('TRANSLATION (CH-JP)'),
        'get_translationjp_with_options',
      );
      expect(
        GameQuestionSourceRules.translationRpc('Translation (CH-KR)'),
        'get_translationkr_with_options',
      );
      expect(
        GameQuestionSourceRules.translationRpc('Mario translation'),
        'get_translation_with_options',
      );
      expect(GameQuestionSourceRules.tableForGame('SPEAKING'), 'game_sentence');
    },
  );
}
