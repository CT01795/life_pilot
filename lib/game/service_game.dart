import 'dart:math';

import 'package:life_pilot/game/grammar/model_game_grammar.dart';
import 'package:life_pilot/game/mario_translation/model_game_mario_translation.dart';
import 'package:life_pilot/game/model_game_item.dart';
import 'package:life_pilot/game/model_game_user.dart';
import 'package:life_pilot/game/sentence/model_game_sentence.dart';
import 'package:life_pilot/game/social/model_game_social.dart';
import 'package:life_pilot/game/speaking/model_game_speaking.dart';
import 'package:life_pilot/game/translation/model_game_translation.dart';
import 'package:life_pilot/game/word_search/model_game_word_search.dart';
import 'package:life_pilot/utils/api.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DuplicateGameQuestionException implements Exception {
  const DuplicateGameQuestionException();
}

class GameQuestionHasAnswersException implements Exception {
  const GameQuestionHasAnswersException();
}

class GameQuestionHint {
  const GameQuestionHint({required this.question, required this.answer});

  final String question;
  final String answer;
}

class QuestionBankAvailability {
  const QuestionBankAvailability({
    required this.questionCount,
    required this.canPlay,
    required this.requiresThreeInGroup,
  });

  final int questionCount;
  final bool canPlay;
  final bool requiresThreeInGroup;
}

class MyGameQuestion {
  const MyGameQuestion({
    required this.id,
    required this.question,
    required this.answer,
    required this.group,
    required this.level,
    this.options,
  });

  final String id;
  final String question;
  final String answer;
  final String group;
  final int level;
  final String? options;
}

class ServiceGame {
  static const _grammarQuestionTable = 'game_grammar';
  static const _sentenceQuestionTable = 'game_sentence';
  static const _translationQuestionTable = 'game_translation';

  //------------------------- 共用 -------------------------
  Future<void> saveUserGameScore(
      {required String newUserName,
      required double newScore,
      required String? newGameId,
      bool? newIsPass}) async {
    if (newScore == 0 || newScore < 2) {
      //不紀錄0分
      return;
    }
    await supabase.from(TableNames.gameUser).insert({
      'game_id': newGameId,
      'score': newScore,
      'name': newUserName,
      'is_pass': newIsPass,
      Fields.createdAt: DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<List<ModelGameItem>> fetchGames() async {
    final data = await supabase
        .from(TableNames.gameList)
        .select()
        .order('game_type', ascending: true)
        .order('game_name', ascending: true)
        .order('level', ascending: true);

    // 轉成 GameItem
    return (data as List<dynamic>).map((e) {
      final map = e as Map<String, dynamic>;
      return ModelGameItem(
        id: map[Fields.id] as String,
        gameType: map['game_type'] as String,
        gameName: map['game_name'] as String,
        level: int.tryParse(map['level']?.toString() ?? '') ?? 1,
      );
    }).toList();
  }

  // 查詢目前使用者的分數紀錄
  Future<List<ModelGameUser>> fetchUserProgress(
      String userName, String gameType, String gameName) async {
    final response = await supabase.rpc(
      'fetch_user_progress',
      params: {
        'p_name': userName,
        'p_game_type': gameType,
        'p_game_name': gameName,
      },
    );

    if (response == null || response is! List) {
      return [];
    }

    final data = response;
    return data.map((e) => ModelGameUser.fromMap(e)).toList();
  }

  Future<void> addGrammarQuestion({
    required String question,
    required String answer,
    required String group,
    required int level,
    required List<String> options,
  }) async {
    if (await _questionExists(
      tableName: _grammarQuestionTable,
      question: question,
      answer: answer,
      group: group,
    )) {
      throw const DuplicateGameQuestionException();
    }
    await _insertQuestion(_grammarQuestionTable, {
      'question': question.trim(),
      'answer': answer.trim(),
      'group': group.trim(),
      'level': level,
      'options': options.map((option) => option.trim()).join('_'),
    });
  }

  Future<void> addSentenceQuestion({
    required String question,
    required String answer,
    required String group,
    required int level,
  }) async {
    if (await _questionExists(
      tableName: _sentenceQuestionTable,
      question: question,
      answer: answer,
      group: group,
    )) {
      throw const DuplicateGameQuestionException();
    }
    await _insertQuestion(_sentenceQuestionTable, {
      'question': question.trim(),
      'answer': answer.trim(),
      'group': group.trim(),
      'level': level,
    });
  }

  Future<void> addTranslationQuestion({
    required String question,
    required String answer,
    required String group,
    required int level,
  }) async {
    if (await _questionExists(
      tableName: _translationQuestionTable,
      question: question,
      answer: answer,
      group: group,
    )) {
      throw const DuplicateGameQuestionException();
    }
    await _insertQuestion(_translationQuestionTable, {
      'question': question.trim(),
      'answer': answer.trim(),
      'group': group.trim(),
      'level': level,
    });
  }

  Future<void> updateGrammarQuestion({
    required String id,
    required String question,
    required String answer,
    required String group,
    required int level,
    required List<String> options,
  }) async {
    await _updateQuestion(
      tableName: _grammarQuestionTable,
      id: id,
      question: question,
      answer: answer,
      group: group,
      level: level,
      extraValues: {
        'options': options.map((option) => option.trim()).join('_'),
      },
    );
  }

  Future<void> updateSentenceQuestion({
    required String id,
    required String question,
    required String answer,
    required String group,
    required int level,
  }) async {
    await _updateQuestion(
      tableName: _sentenceQuestionTable,
      id: id,
      question: question,
      answer: answer,
      group: group,
      level: level,
    );
  }

  Future<void> updateTranslationQuestion({
    required String id,
    required String question,
    required String answer,
    required String group,
    required int level,
  }) async {
    await _updateQuestion(
      tableName: _translationQuestionTable,
      id: id,
      question: question,
      answer: answer,
      group: group,
      level: level,
    );
  }

  Future<QuestionBankAvailability> getMyQuestionBankAvailability({
    required String gameName,
    required int level,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw StateError('User must be signed in');
    final normalizedName = gameName.toLowerCase();
    late final String tableName;
    if (normalizedName == 'english rpg adventure') {
      tableName = _grammarQuestionTable;
    } else if (normalizedName == 'speaking' ||
        normalizedName == 'word and sentence builder') {
      tableName = _sentenceQuestionTable;
    } else {
      tableName = _translationQuestionTable;
    }

    final rows = await supabase
        .from(tableName)
        .select('group')
        .eq('owner_id', userId)
        .lte('level', level);

    final matchingGroups =
        rows.map((row) => row['group']?.toString() ?? '').where((group) {
      if (normalizedName == 'word searching') {
        return group == '英翻中Word';
      }
      if (gameName.contains('日')) return group.contains('日');
      if (gameName.contains('韓')) return group.contains('韓');
      if (normalizedName.contains('translation')) {
        return !group.contains('日') && !group.contains('韓');
      }
      return true;
    }).toList();

    final requiresThree = normalizedName.contains('translation');
    if (!requiresThree) {
      return QuestionBankAvailability(
        questionCount: matchingGroups.length,
        canPlay: matchingGroups.isNotEmpty,
        requiresThreeInGroup: false,
      );
    }

    final groupCounts = <String, int>{};
    for (final group in matchingGroups) {
      groupCounts.update(group, (count) => count + 1, ifAbsent: () => 1);
    }
    return QuestionBankAvailability(
      questionCount: matchingGroups.length,
      canPlay: groupCounts.isNotEmpty &&
          groupCounts.values.every((count) => count >= 3),
      requiresThreeInGroup: true,
    );
  }

  Future<List<MyGameQuestion>> fetchMyQuestions({
    required String gameName,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw StateError('User must be signed in');
    final tableName = _questionTableForGame(gameName);
    final columns = tableName == _grammarQuestionTable
        ? 'id, question, answer, group, level, options'
        : 'id, question, answer, group, level';
    final rows = await supabase
        .from(tableName)
        .select(columns)
        .eq('owner_id', userId)
        .order('created_at', ascending: false);

    return rows
        .where((row) => _groupMatchesGame(
              gameName,
              row['group']?.toString() ?? '',
            ))
        .map((row) => MyGameQuestion(
              id: row['id'].toString(),
              question: row['question']?.toString() ?? '',
              answer: row['answer']?.toString() ?? '',
              group: row['group']?.toString() ?? '',
              level: int.tryParse(row['level']?.toString() ?? '') ?? 1,
              options: row['options']?.toString(),
            ))
        .toList();
  }

  Future<List<String>> fetchMyQuestionGroups({
    required String gameName,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw StateError('User must be signed in');
    final rows = await supabase
        .from(_questionTableForGame(gameName))
        .select('group')
        .eq('owner_id', userId);
    final groups = rows
        .map((row) => row['group']?.toString().trim() ?? '')
        .where(
            (group) => group.isNotEmpty && _groupMatchesGame(gameName, group))
        .toSet()
        .toList()
      ..sort();
    return groups;
  }

  Future<GameQuestionHint?> fetchAdminQuestionHint({
    required String gameName,
    required String group,
  }) async {
    final randomKey = Random.secure().nextDouble();
    var rows = await supabase
        .from(_questionTableForGame(gameName))
        .select('question, answer')
        .eq('owner_id', AuthConstants.systemQuestionBankOwnerId)
        .eq('group', group)
        .gte('rand_key', randomKey)
        .order('rand_key')
        .limit(1);
    if (rows.isEmpty) {
      rows = await supabase
          .from(_questionTableForGame(gameName))
          .select('question, answer')
          .eq('owner_id', AuthConstants.systemQuestionBankOwnerId)
          .eq('group', group)
          .lt('rand_key', randomKey)
          .order('rand_key')
          .limit(1);
    }
    if (rows.isEmpty) return null;
    final row = rows.first;
    return GameQuestionHint(
      question: row['question']?.toString() ?? '',
      answer: row['answer']?.toString() ?? '',
    );
  }

  Future<void> deleteMyQuestion({
    required String gameName,
    required String questionId,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw StateError('User must be signed in');
    late final List<Map<String, dynamic>> deletedRows;
    try {
      deletedRows = await supabase
          .from(_questionTableForGame(gameName))
          .delete()
          .eq('id', questionId)
          .eq('owner_id', userId)
          .select('id');
    } on PostgrestException catch (error) {
      if (error.code == '23503') {
        throw const GameQuestionHasAnswersException();
      }
      rethrow;
    }
    if (deletedRows.isEmpty) {
      throw StateError('Question was not deleted');
    }
  }

  String _questionTableForGame(String gameName) {
    final normalizedName = gameName.toLowerCase();
    if (normalizedName == 'english rpg adventure') {
      return _grammarQuestionTable;
    }
    if (normalizedName == 'speaking' ||
        normalizedName == 'word and sentence builder') {
      return _sentenceQuestionTable;
    }
    return _translationQuestionTable;
  }

  bool _groupMatchesGame(String gameName, String group) {
    final normalizedName = gameName.toLowerCase();
    if (normalizedName == 'word searching') return group == '英翻中Word';
    if (gameName.contains('日')) return group.contains('日');
    if (gameName.contains('韓')) return group.contains('韓');
    if (normalizedName.contains('translation')) {
      return !group.contains('日') && !group.contains('韓');
    }
    return true;
  }

  Future<bool> _questionExists({
    required String tableName,
    required String question,
    required String answer,
    required String group,
    String? excludedId,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw StateError('User must be signed in');

    final rows = await supabase
        .from(tableName)
        .select('id, question, answer')
        .eq('owner_id', userId)
        .eq('group', group.trim());
    final normalizedQuestion = _normalizeQuestion(question);
    final normalizedAnswer = _normalizeQuestion(answer);
    return rows.any(
      (row) =>
          row['id']?.toString() != excludedId &&
          _normalizeQuestion(row['question']?.toString() ?? '') ==
              normalizedQuestion &&
          _normalizeQuestion(row['answer']?.toString() ?? '') ==
              normalizedAnswer,
    );
  }

  String _normalizeQuestion(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[\s_]+'), '');
  }

  Future<void> _insertQuestion(
    String tableName,
    Map<String, Object?> values,
  ) async {
    try {
      await supabase.from(tableName).insert(values);
    } on PostgrestException catch (error) {
      if (error.code == '23505') {
        throw const DuplicateGameQuestionException();
      }
      rethrow;
    }
  }

  Future<void> _updateQuestion({
    required String tableName,
    required String id,
    required String question,
    required String answer,
    required String group,
    required int level,
    Map<String, Object?> extraValues = const {},
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw StateError('User must be signed in');
    if (await _questionExists(
      tableName: tableName,
      question: question,
      answer: answer,
      group: group,
      excludedId: id,
    )) {
      throw const DuplicateGameQuestionException();
    }

    try {
      await supabase
          .from(tableName)
          .update({
            'question': question.trim(),
            'answer': answer.trim(),
            'group': group.trim(),
            'level': level,
            ...extraValues,
          })
          .eq('id', id)
          .eq('owner_id', userId);
    } on PostgrestException catch (error) {
      if (error.code == '23505') {
        throw const DuplicateGameQuestionException();
      }
      rethrow;
    }
  }

  //------------------------- Grammar -------------------------
  Future<ModelGameGrammarQuestion> fetchGrammarQuestion(
      String userName, int level,
      {String questionBank = 'admin'}) async {
    final result = await supabase.rpc(
      'get_grammar_question',
      params: {
        'user_name': userName,
        'p_level': level,
        'p_question_bank': questionBank,
      },
    );

    if (result == null || result.isEmpty) {
      throw Exception("No data returned");
    }

    final data = result[0];
    return ModelGameGrammarQuestion(
        questionId: data[Fields.id],
        question: data['question'],
        correctAnswer: data['correct_answer'],
        type: data['type'],
        options: (data['options'] ?? '').split('_'));
  }

  // 寫入使用者答題紀錄
  Future<void> submitGrammarAnswer({
    required String userName,
    required String questionId,
    required String answer,
    required bool isRightAnswer,
  }) async {
    await supabase.from(TableNames.gameGrammarUser).insert({
      'user': userName,
      'question_id': questionId,
      'answer': answer,
      'is_right': isRightAnswer,
      Fields.createdAt: DateTime.now().toUtc().toIso8601String(),
    });
  }

  //------------------------- Sentence -------------------------
  Future<ModelGameSentence> fetchSentenceQuestion(String userName, int level,
      {String questionBank = 'admin'}) async {
    final result = await supabase.rpc(
      'get_sentence_question',
      params: {
        'user_name': userName,
        'p_level': level,
        'p_question_bank': questionBank,
      },
    );

    if (result == null || result.isEmpty) {
      throw Exception("No data returned");
    }
    final data = result[0];
    return ModelGameSentence(
        questionId: data[Fields.id],
        question: data['question'],
        correctAnswer: data['correct_answer'],
        type: data['type'],
        options: (data['question'] ?? '').split('_'));
  }

  // 寫入使用者答題紀錄
  Future<void> submitSentenceAnswer({
    required String userName,
    required String questionId,
    required String answer,
    required bool isRightAnswer,
  }) async {
    await supabase.from(TableNames.gameSentenceUser).insert({
      'user': userName,
      'question_id': questionId,
      'answer': answer,
      'is_right': isRightAnswer,
      Fields.createdAt: DateTime.now().toUtc().toIso8601String(),
    });
  }

  //------------------------- Speaking -------------------------
  Future<ModelGameSpeaking> fetchSpeakingQuestion(String userName, int level,
      {String questionBank = 'admin'}) async {
    final result = await supabase.rpc(
      'get_speaking_question',
      params: {
        'user_name': userName,
        'p_level': level,
        'p_question_bank': questionBank,
      },
    );

    if (result == null || result.isEmpty) {
      throw Exception("No data returned");
    }

    final data = result[0];
    return ModelGameSpeaking(
      questionId: data[Fields.id],
      question: data['question'],
      correctAnswer: data['correct_answer'],
      type: data['type'],
    );
  }

  // 寫入使用者答題紀錄
  Future<void> submitSpeakingAnswer({
    required String userName,
    required String questionId,
    required String answer,
    required bool isRightAnswer,
  }) async {
    await supabase.from(TableNames.gameSpeakingUser).insert({
      'user': userName,
      'question_id': questionId,
      'answer': answer,
      'is_right': isRightAnswer,
      Fields.createdAt: DateTime.now().toUtc().toIso8601String(),
    });
  }

  //------------------------- Social -------------------------
  Future<ModelGameSocial> fetchSocialQuestion(
      String userName, int level) async {
    final result = await supabase.rpc(
      'get_social_with_options',
      params: {
        'user_name': userName,
        'p_level': level,
      },
    );

    if (result == null || result.isEmpty) {
      throw Exception("No data returned");
    }

    final data = result[0];
    Map tmpMap = {
      data['answer1']: data['score1'],
      data['answer2']: data['score2'],
      data['answer3']: data['score3']
    };
    List<String> options = [
      data['answer1'],
      data['answer2'],
      data['answer3'],
    ]..shuffle();
    List<int> scores = [
      tmpMap[options[0]],
      tmpMap[options[1]],
      tmpMap[options[2]]
    ];
    return ModelGameSocial(
        id: data[Fields.id],
        scene: data['scene'],
        correctAnswer: data['answer1'],
        options: options,
        scores: scores);
  }

  // 寫入使用者答題紀錄
  Future<void> submitSocialAnswer({
    required String userName,
    required String questionId,
    required String answer,
    required bool isRightAnswer,
  }) async {
    await supabase.from(TableNames.gameSocialUser).insert({
      'user': userName,
      'question_id': questionId,
      'answer': answer,
      'is_right': isRightAnswer,
      Fields.createdAt: DateTime.now().toUtc().toIso8601String(),
    });
  }

  //------------------------- Mario Translation -------------------------
  Future<ModelGameMarioTranslation> fetchMarioTranslationQuestion(
      String userName, int level,
      {String questionBank = 'admin'}) async {
    final result = await supabase.rpc(
      'get_translation_with_options',
      params: {
        'user_name': userName,
        'p_level': level,
        'p_question_bank': questionBank,
      },
    );

    if (result == null || result.isEmpty) {
      throw Exception("No data returned");
    }

    final data = result[0];

    return ModelGameMarioTranslation(
        questionId: data[Fields.id],
        question: data['question'],
        correctAnswer: data['correct_answer'],
        options: [
          data['correct_answer'],
          data['wrong1'],
          data['wrong2'],
        ]..shuffle());
  }

  //------------------------- Translation -------------------------
  Future<ModelGameTranslation> fetchTranslationQuestion(
      String userName, int level, String gameName,
      {String questionBank = 'admin'}) async {
    String functionName = 'get_translation_with_options';
    if (gameName.contains("日")) {
      functionName = 'get_translationjp_with_options';
    } else if (gameName.contains("韓")) {
      functionName = 'get_translationkr_with_options';
    }

    final result = await supabase.rpc(
      functionName,
      params: {
        'user_name': userName,
        'p_level': level,
        'p_question_bank': questionBank,
      },
    );

    if (result == null || result.isEmpty) {
      throw Exception("No data returned");
    }

    final data = result[0];

    return ModelGameTranslation(
        questionId: data[Fields.id],
        question: data['question'],
        group: data['group'],
        correctAnswer: data['correct_answer'],
        options: [
          data['correct_answer'],
          data['wrong1'] ?? '',
          data['wrong2'] ?? '',
        ]..shuffle());
  }

  Future<Map<String, Set<String>>> getSynonyms() async {
    final response =
        await supabase.from(TableNames.gameTranslationSynonyms).select();

    final Map<String, Set<String>> synonyms = {};

    for (final row in response) {
      final String question = row['question'];
      final String answer = row['answer'];

      synonyms.putIfAbsent(question, () => <String>{});
      synonyms[question]!.add(answer);
    }
    return synonyms;
  }

  // 寫入使用者答題紀錄
  Future<void> submitTranslationAnswer({
    required String userName,
    required String questionId,
    required String answer,
    required bool isRightAnswer,
  }) async {
    await supabase.from(TableNames.gameTranslationUser).insert({
      'user': userName,
      'question_id': questionId,
      'answer': answer,
      'is_right': isRightAnswer,
      Fields.createdAt: DateTime.now().toUtc().toIso8601String(),
    });
  }

  //------------------------- Word Search -------------------------
  Future<ModelGameWordSearch> fetchWordSearchQuestion(
      String userName, int level,
      {String questionBank = 'admin'}) async {
    final result = await supabase.rpc(
      'get_next_word_question',
      params: {
        'user_name': userName,
        'p_level': level,
        'p_question_bank': questionBank,
      },
    );

    if (result == null || result.isEmpty) {
      throw Exception("No data returned");
    }
    final data = result[0];
    return ModelGameWordSearch(
        questionId: data[Fields.id], question: data['question'], found: false);
  }

  // 寫入使用者答題紀錄
  Future<void> submitWordSearchAnswer({
    required String userName,
    required String questionId,
    required String answer,
    required bool isRightAnswer,
  }) async {
    await supabase.from(TableNames.gameWordSearchUser).insert({
      'user': userName,
      'question_id': questionId,
      'answer': answer,
      'is_right': isRightAnswer,
      Fields.createdAt: DateTime.now().toUtc().toIso8601String(),
    });
  }
}
