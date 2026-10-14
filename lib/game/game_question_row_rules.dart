import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/value_parser.dart';
import 'package:life_pilot/game/game_question_source_rules.dart';

/// Pure question-row rules shared by storage and search operations.
class GameQuestionRowRules {
  const GameQuestionRowRules._();

  static final _duplicateSeparators = RegExp(r'[\s_]+');

  static bool isPlayableAtLevel(
    Map<String, dynamic> row,
    int level, {
    String? gameName,
  }) =>
      row['is_active'] == true &&
      (tryParseIntValue(row['level']) ?? 1) <= level &&
      (gameName == null ||
          GameQuestionSourceRules.groupMatchesGame(
            gameName,
            parseStringValue(row['group']),
          ));

  static String duplicateKey(Object? value) => parseStringValue(
    value,
  ).toLowerCase().replaceAll(_duplicateSeparators, '');

  static bool matchesStatus(Object? isActive, String status) {
    final active = isActive == true;
    return status == 'all' ||
        (status == 'active' && active) ||
        (status == 'inactive' && !active);
  }

  static bool hasDuplicateQuestion(
    Iterable<Map<String, dynamic>> rows, {
    required String question,
    required String answer,
    required String group,
    String? excludingId,
  }) {
    final questionKey = duplicateKey(question);
    final answerKey = duplicateKey(answer);
    final groupKey = normalizeStringValue(group);
    return rows.any(
      (row) =>
          parseOptionalStringValue(row[Fields.id]) != excludingId &&
          normalizeStringValue(row['group']) == groupKey &&
          duplicateKey(row['question']) == questionKey &&
          duplicateKey(row['answer']) == answerKey,
    );
  }
}
