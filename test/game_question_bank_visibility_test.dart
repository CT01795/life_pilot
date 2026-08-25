import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/game/game_question_bank_visibility.dart';

void main() {
  group('GameQuestionBankVisibility', () {
    test('admin always sees question management actions', () {
      expect(
        GameQuestionBankVisibility.showManagementActions(
          isAdmin: true,
          selectedQuestionBank: 'admin',
        ),
        isTrue,
      );
    });

    test('normal user does not see actions for admin question bank', () {
      expect(
        GameQuestionBankVisibility.showManagementActions(
          isAdmin: false,
          selectedQuestionBank: 'admin',
        ),
        isFalse,
      );
    });

    test('normal user sees actions after selecting own question bank', () {
      expect(
        GameQuestionBankVisibility.showManagementActions(
          isAdmin: false,
          selectedQuestionBank: 'mine',
        ),
        isTrue,
      );
    });
  });
}
