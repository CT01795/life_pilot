import 'dart:convert';
import 'dart:typed_data';
import 'package:life_pilot/feedback/model_feedback.dart';
import 'package:life_pilot/utils/api.dart';
import 'package:life_pilot/utils/const.dart';
import '../utils/logger.dart';

class ServiceFeedback {
  Future<void> sendFeedback({
    required String account,
    required String subject,
    required String content,
    List<String>? cc, // ← 改成 List<String>
    List<Uint8List>? screenshots, // ← 支援多張
  }) async {
    final screenshotBase64 =
        screenshots?.map((bytes) => base64Encode(bytes)).toList();
    await supabase
      .from(TableNames.feedback)
      .insert({
        'subject': subject,
        'content': content,
        'cc': cc,                       // text[]
        'screenshot': screenshotBase64, // text[] 或 bytea[]，依你的 schema
        Fields.createdBy: account,
        Fields.createdAt: DateTime.now().toUtc().toIso8601String(),
        'is_ok': false,
      });
  }

  Future<List<dynamic>> loadFeedback() async {
    try {
      final response = await supabase
          .from(TableNames.feedback)
          .select()
          .order('is_ok', ascending: true)
          .order(Fields.createdAt, ascending: true);

      return response;
    } catch (e, st) {
      logger.e('loadFeedback failed $e', stackTrace: st);
      return [];
    }
  }

  Future<void> updateFeedback({
    required ModelFeedback feedback,
  }) async {
    final data = feedback.toMap();
    await supabase
      .from(TableNames.feedback)
      .update({
        'is_ok': data['is_ok'],
        'deal_by': data['deal_by'],
        'deal_at': data['deal_at'],
      })
      .eq(Fields.id, data[Fields.id]);
  }
}
