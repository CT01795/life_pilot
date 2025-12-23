import 'package:life_pilot/models/game/model_game_grammar.dart';
import 'package:life_pilot/models/game/model_game_item.dart';
import 'package:life_pilot/models/game/model_game_sentence.dart';
import 'package:life_pilot/models/game/model_game_speaking.dart';
import 'package:life_pilot/models/game/model_game_translation.dart';
import 'package:life_pilot/models/game/model_game_user.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ServiceGame {
  final client = Supabase.instance.client;
  
  //------------------------- 共用 -------------------------
  Future<void> saveUserGameScore(
      {required String newUserName,
      required double newScore,
      required String? newGameId,
      bool? newIsPass}) async {
    if (newScore == 0 || newIsPass == null || newIsPass == false) {
      return;
    }
    await client.from('game_user').insert({
      'game_id': newGameId,
      'score': newScore,
      'name': newUserName,
      'is_pass': newIsPass,
      'created_at': DateTime.now().toIso8601String(), // 強制存 UTC
    });
  }

  Future<List<ModelGameItem>> fetchGames() async {
    final data = await client
        .from('game_list')
        .select('id, game_type, game_name, level')
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
    final response = await client.rpc('fetch_user_progress', params: {
      'p_name': userName,
      'p_game_type': gameType,
      'p_game_name': gameName,
    });

    final data = response as List<dynamic>;
    return data.map((e) => ModelGameUser.fromMap(e)).toList();
  }

  //------------------------- Grammar -------------------------
  Future<ModelGameGrammarQuestion> fetchGrammarQuestion(String userName) async {
    final result = await client.rpc("get_grammar_question", params: {
      'user_name': userName,
    });

    if (result == null || result.isEmpty) {
      throw Exception("No data returned");
    }

    final data = result[0];
    return ModelGameGrammarQuestion(
      questionId: data['id'],
      question: data['question'],
      correctAnswer: data['correct_answer'],
      type: data['type'],
      options: (data['options'] ?? '').split('_')
    );
  }

  // 寫入使用者答題紀錄
  Future<void> submitGrammarAnswer({
    required String userName,
    required String questionId,
    required String answer,
    required bool isRightAnswer,
  }) async {
    await client.from('game_grammar_user').insert({
      'user': userName,
      'question_id': questionId,
      'answer': answer,
      'is_right': isRightAnswer,
      'created_at': DateTime.now().toIso8601String(), // 強制存 UTC
    });
  }

  //------------------------- Sentence -------------------------
  Future<ModelGameSentence> fetchSentenceQuestion(String userName) async {
    final result = await client.rpc("get_sentence_question", params: {
      'user_name': userName,
    });

    if (result == null || result.isEmpty) {
      throw Exception("No data returned");
    }

    final data = result[0];
    return ModelGameSentence(
      questionId: data['id'],
      question: data['question'],
      correctAnswer: data['correct_answer'],
      type: data['type'],
      options: (data['question'] ?? '').split('_')
    );
  }

  // 寫入使用者答題紀錄
  Future<void> submitSentenceAnswer({
    required String userName,
    required String questionId,
    required String answer,
    required bool isRightAnswer,
  }) async {
    await client.from('game_sentence_user').insert({
      'user': userName,
      'question_id': questionId,
      'answer': answer,
      'is_right': isRightAnswer,
      'created_at': DateTime.now().toIso8601String(), // 強制存 UTC
    });
  }

  //------------------------- Speaking -------------------------
  Future<ModelGameSpeaking> fetchSpeakingQuestion(String userName) async {
    final result = await client.rpc("get_speaking_question", params: {
      'user_name': userName,
    });

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
    await client.from('game_speaking_user').insert({
      'user': userName,
      'question_id': questionId,
      'answer': answer,
      'is_right': isRightAnswer,
      'created_at': DateTime.now().toIso8601String(), // 強制存 UTC
    });
  }
  
  //------------------------- Translation -------------------------
  Future<ModelGameTranslation> fetchTranslationQuestion(String userName) async {
    final result = await client.rpc("get_translation_with_options", params: {
      'user_name': userName,
    });

    if (result == null || result.isEmpty) {
      throw Exception("No data returned");
    }

    final data = result[0];

    return ModelGameTranslation(
      questionId: data['id'],
      question: data['question'],
      correctAnswer: data['correct_answer'],
      options: [
        data['correct_answer'],
        data['wrong1'],
        data['wrong2'],
      ]..shuffle()
    );
  }

  // 寫入使用者答題紀錄
  Future<void> submitTranslationAnswer({
    required String userName,
    required String questionId,
    required String answer,
    required bool isRightAnswer,
  }) async {
    await client.from('game_translation_user').insert({
      'user': userName,
      'question_id': questionId,
      'answer': answer,
      'is_right': isRightAnswer,
      'created_at': DateTime.now().toIso8601String(), // 強制存 UTC
    });
  }
}
