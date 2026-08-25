class GameQuestionBankVisibility {
  const GameQuestionBankVisibility._();

  static bool showManagementActions({
    required bool isAdmin,
    required String selectedQuestionBank,
  }) {
    return isAdmin || selectedQuestionBank == 'mine';
  }
}
