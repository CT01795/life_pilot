import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/game/game_question_authoring_rules.dart';

void main() {
  group('GameQuestionAuthoringRules', () {
    test('plural hint hides ASCII arrow and blank', () {
      expect(
        GameQuestionAuthoringRules.grammarHint(
          question: 'head <--> many ______',
          answer: 'heads',
          isPlural: true,
        ),
        'head',
      );
    });

    test('plural hint hides unicode arrow', () {
      expect(
        GameQuestionAuthoringRules.grammarHint(
          question: 'child ↔ many ______',
          answer: 'children',
          isPlural: true,
        ),
        'child',
      );
    });

    test('grammar sentence replaces the answer with a blank', () {
      expect(
        GameQuestionAuthoringRules.grammarQuestion(
          completedQuestion: 'We are young',
          answer: 'are',
          isPlural: false,
        ),
        'We ______ young',
      );
    });

    test('single word is split into letters', () {
      expect(
        GameQuestionAuthoringRules.sentenceQuestion('mother'),
        'm_o_t_h_e_r',
      );
    });

    test('sentence is split into words', () {
      expect(
        GameQuestionAuthoringRules.sentenceQuestion('I love apples'),
        'I_love_apples',
      );
    });

    test('category suffix becomes its level', () {
      expect(GameQuestionAuthoringRules.levelFromGroup('日翻中句子123'), 123);
      expect(GameQuestionAuthoringRules.levelFromGroup('日翻中句子'), 1);
    });

    test('blank numbered suffix represents level one category', () {
      expect(
        GameQuestionAuthoringRules.numberedGroup(
          base: '韓翻中句子4',
          suffix: '',
        ),
        '韓翻中句子',
      );
    });

    test('only admin or Japanese and Korean games can add categories', () {
      expect(
        GameQuestionAuthoringRules.canCreateCustomGroup(
          isAdmin: false,
          gameName: 'English RPG Adventure',
        ),
        isFalse,
      );
      expect(
        GameQuestionAuthoringRules.canCreateCustomGroup(
          isAdmin: false,
          gameName: 'Translation日',
        ),
        isTrue,
      );
      expect(
        GameQuestionAuthoringRules.canCreateCustomGroup(
          isAdmin: true,
          gameName: 'English RPG Adventure',
        ),
        isTrue,
      );
    });
  });
}
