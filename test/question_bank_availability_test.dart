import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/game/question_bank_availability.dart';

void main() {
  test('all translation variants require three usable questions in total', () {
    for (final name in [
      'Translation (CH-EN)',
      'Translation (CH-JP)',
      'Translation (CH-KR)',
      'Mario translation',
    ]) {
      expect(
        QuestionBankAvailability.forGame(
          gameName: name,
          questionCount: 2,
        ).canPlay,
        isFalse,
      );
      final enough = QuestionBankAvailability.forGame(
        gameName: name,
        questionCount: 3,
      );
      expect(enough.canPlay, isTrue);
      expect(enough.questionCount, 3);
      expect(enough.requiresThreeInGroup, isTrue);
    }
  });

  test('other games need at least one complete usable question', () {
    for (final name in [
      'Social',
      'Speaking',
      'Word and Sentence Builder',
      'English RPG Adventure',
    ]) {
      expect(
        QuestionBankAvailability.forGame(
          gameName: name,
          questionCount: 0,
        ).canPlay,
        isFalse,
      );
      final enough = QuestionBankAvailability.forGame(
        gameName: name,
        questionCount: 1,
      );
      expect(enough.canPlay, isTrue);
      expect(enough.requiresThreeInGroup, isFalse);
    }
  });

  test('name matching retains case-insensitive translation handling', () {
    expect(
      QuestionBankAvailability.forGame(
        gameName: 'MARIO TRANSLATION',
        questionCount: 2,
      ).canPlay,
      isFalse,
    );
  });

  test('empty and invalid negative counts cannot start a game', () {
    for (final count in [0, -1]) {
      expect(
        QuestionBankAvailability.forGame(
          gameName: 'Speaking',
          questionCount: count,
        ).canPlay,
        isFalse,
      );
      expect(
        QuestionBankAvailability.forGame(
          gameName: 'Translation',
          questionCount: count,
        ).canPlay,
        isFalse,
      );
    }
  });
}
