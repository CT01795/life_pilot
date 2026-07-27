import 'package:life_pilot/game/grammar/model_game_grammar.dart';
import 'package:life_pilot/game/mario_translation/model_game_mario_translation.dart';
import 'package:life_pilot/game/model_game_item.dart';
import 'package:life_pilot/game/model_game_user.dart';
import 'package:life_pilot/game/sentence/model_game_sentence.dart';
import 'package:life_pilot/game/social/model_game_social.dart';
import 'package:life_pilot/game/speaking/model_game_speaking.dart';
import 'package:life_pilot/game/translation/model_game_translation.dart';
import 'package:life_pilot/game/word_search/model_game_word_search.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ServiceGame {
  //------------------------- 共用 -------------------------
  final SupabaseClient _supabase = Supabase.instance.client;
  Future<void> saveUserGameScore(
      {required String newUserName,
      required double newScore,
      required String? newGameId,
      bool? newIsPass}) async {
    if (newScore == 0 || newScore < 2) {
      //不紀錄0分
      return;
    }
    await _supabase
      .from(TableNames.gameUser)
      .insert({
        'game_id': newGameId,
        'score': newScore,
        'name': newUserName,
        'is_pass': newIsPass,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
  }

  Future<List<ModelGameItem>> fetchGames() async {
    final data = await _supabase
      .from(TableNames.gameList)
      .select()
      .order('game_type', ascending: true)
      .order('game_name', ascending: true)
      .order('level', ascending: true);

    // 轉成 GameItem
    return (data as List<dynamic>).map((e) {
      final map = e as Map<String, dynamic>;
      return ModelGameItem(
        id: map['id'] as String,
        gameType: map['game_type'] as String,
        gameName: map['game_name'] as String,
        level: int.tryParse(map['level']?.toString() ?? '') ?? 1,
      );
    }).toList();
  }

  // 查詢目前使用者的分數紀錄
  Future<List<ModelGameUser>> fetchUserProgress(
      String userName, String gameType, String gameName) async {
    final response = await _supabase.rpc(
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

  //------------------------- Grammar -------------------------
  Future<ModelGameGrammarQuestion> fetchGrammarQuestion(
      String userName, int level) async {
    final result = await _supabase.rpc(
      'get_grammar_question',
      params: {
        'user_name': userName,
        'p_level': level,
      },
    );

    if (result == null || result.isEmpty) {
      throw Exception("No data returned");
    }

    final data = result[0];
    return ModelGameGrammarQuestion(
        questionId: data['id'],
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
    await _supabase
      .from(TableNames.gameGrammarUser)
      .insert({
        'user': userName,
        'question_id': questionId,
        'answer': answer,
        'is_right': isRightAnswer,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
  }

  //------------------------- Sentence -------------------------
  Future<ModelGameSentence> fetchSentenceQuestion(
      String userName, int level) async {
    final result = await _supabase.rpc(
      'get_sentence_question',
      params: {
        'user_name': userName,
        'p_level': level,
      },
    );

    if (result == null || result.isEmpty) {
      throw Exception("No data returned");
    }
    final data = result[0];
    return ModelGameSentence(
        questionId: data['id'],
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
    await _supabase
      .from(TableNames.gameSentenceUser)
      .insert({
        'user': userName,
        'question_id': questionId,
        'answer': answer,
        'is_right': isRightAnswer,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
  }

  //------------------------- Speaking -------------------------
  Future<ModelGameSpeaking> fetchSpeakingQuestion(
      String userName, int level) async {
    final result = await _supabase.rpc(
      'get_speaking_question',
      params: {
        'user_name': userName,
        'p_level': level,
      },
    );

    if (result == null || result.isEmpty) {
      throw Exception("No data returned");
    }

    final data = result[0];
    return ModelGameSpeaking(
      questionId: data['id'],
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
    await Supabase.instance.client
      .from(TableNames.gameSpeakingUser)
      .insert({
        'user': userName,
        'question_id': questionId,
        'answer': answer,
        'is_right': isRightAnswer,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
  }

  //------------------------- Social -------------------------
  Future<ModelGameSocial> fetchSocialQuestion(
      String userName, int level) async {
    final result = await _supabase.rpc(
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
        id: data['id'],
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
    await _supabase
      .from(TableNames.gameSocialUser)
      .insert({
        'user': userName,
        'question_id': questionId,
        'answer': answer,
        'is_right': isRightAnswer,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
  }

  //------------------------- Mario Translation -------------------------
  Future<ModelGameMarioTranslation> fetchMarioTranslationQuestion(
      String userName, int level) async {
    final result = await _supabase.rpc(
      'get_translation_with_options',
      params: {
        'user_name': userName,
        'p_level': level,
      },
    );

    if (result == null || result.isEmpty) {
      throw Exception("No data returned");
    }

    final data = result[0];

    return ModelGameMarioTranslation(
        questionId: data['id'],
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
      String userName, int level, String gameName) async {
    String functionName = 'get_translation_with_options';
    if (gameName.contains("日")) {
      functionName = 'get_translationjp_with_options';
    } else if (gameName.contains("韓")) {
      functionName = 'get_translationkr_with_options';
    }

    final result = await _supabase.rpc(
      functionName,
      params: {
        'user_name': userName,
        'p_level': level,
      },
    );

    if (result == null || result.isEmpty) {
      throw Exception("No data returned");
    }

    final data = result[0];

    return ModelGameTranslation(
        questionId: data['id'],
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
    final response = await _supabase
      .from(TableNames.gameTranslationSynonyms)
      .select();

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
    await _supabase
      .from(TableNames.gameTranslationUser)
      .insert({
        'user': userName,
        'question_id': questionId,
        'answer': answer,
        'is_right': isRightAnswer,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
  }

  //------------------------- Word Search -------------------------
  Future<ModelGameWordSearch> fetchWordSearchQuestion(
      String userName, int level) async {
    final result = await _supabase.rpc(
      'get_next_word_question',
      params: {
        'user_name': userName,
        'p_level': level,
      },
    );

    if (result == null || result.isEmpty) {
      throw Exception("No data returned");
    }
    final data = result[0];
    return ModelGameWordSearch(
        questionId: data['id'], question: data['question'], found: false);
  }

  // 寫入使用者答題紀錄
  Future<void> submitWordSearchAnswer({
    required String userName,
    required String questionId,
    required String answer,
    required bool isRightAnswer,
  }) async {
    await _supabase
      .from(TableNames.gameWordSearchUser)
      .insert({
        'user': userName,
        'question_id': questionId,
        'answer': answer,
        'is_right': isRightAnswer,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
  }
}
