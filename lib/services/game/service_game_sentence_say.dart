import 'package:life_pilot/models/game/model_game_sentence_say.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ServiceGameSentenceSay {
  final client = Supabase.instance.client;

  Future<ModelGameSentenceSay> fetchQuestion(String userName) async {
    final result = await client.rpc("get_sentence_say_question", params: {
      'user_name': userName,
    });

    if (result == null || result.isEmpty) {
      throw Exception("No data returned");
    }

    final data = result[0];
    return ModelGameSentenceSay(
      questionId: data['id'],
      question: data['question'],
      correctAnswer: data['correct_answer'],
      type: data['type'],
    );
  }

  // 寫入使用者答題紀錄
  Future<void> submitAnswer({
    required String userName,
    required String questionId,
    required String answer,
    required bool isRightAnswer,
  }) async {
    await client.from('game_sentence_say_user').insert({
      'user': userName,
      'question_id': questionId,
      'answer': answer,
      'is_right': isRightAnswer,
      'created_at': DateTime.now().toIso8601String(), // 強制存 UTC
    });
  }

  Future<void> saveUserGameScore({
    required String userName,
    required double score,
    required String? gameId,
  }) async {
    await client.from('game_user').insert({
      'game_id': gameId,
      'score': score,
      'name': userName,
      'created_at': DateTime.now().toIso8601String(), // 強制存 UTC
    });
  }
}
