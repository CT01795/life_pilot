import 'package:life_pilot/models/game/model_game_translation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ServiceGameTranslation {
  final client = Supabase.instance.client;

  Future<ModelGameTranslation> fetchQuestion(String userName) async {
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
  Future<void> submitAnswer({
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