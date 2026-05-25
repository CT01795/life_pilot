import 'dart:convert';
import 'dart:typed_data';

import 'package:life_pilot/feedback/model_feedback.dart';
import 'package:life_pilot/utils/api.dart';
import 'package:life_pilot/utils/const.dart';

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
    await apiSupabase.post('feedback/insert', {
      'table_name': TableNames.feedback,
      'feedback_data': {
        'subject': subject,
        'content': content,
        // PostgreSQL text[]
        'cc': cc,
        // PostgreSQL text[]
        // bytea[]：Uint8List → base64 → List<String>
        // 將 Uint8List 轉成 Base64 存入 DB
        'screenshot': screenshotBase64,
        'created_by': account,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'is_ok': false,
      }
    });
  }

  Future<List<dynamic>> loadFeedback() async {
    return await apiSupabase.post('feedback/select', {
      'table_name': TableNames.feedback,
    });
  }

  Future<void> updateFeedback({
    required ModelFeedback feedback,
  }) async {
    await apiSupabase.post('feedback/update', {
      'table_name': TableNames.feedback,
      'update_data': feedback.toMap(),
    });
  }
}
