import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class ServiceFeedback {
  final supabase = Supabase.instance.client;

  Future<void> sendFeedback({
    required String account,
    required String subject,
    required String content,
    List<String>? cc,                // ← 改成 List<String>
    List<Uint8List>? screenshots,    // ← 支援多張
  }) async {
    final screenshotBase64 = screenshots
      ?.map((bytes) => base64Encode(bytes))
      .toList();
    await supabase.from('feedback').insert({
      'subject': subject,
      'content': content,
      'cc': cc, // 直接傳 List<String>

      // bytea[]：Uint8List → base64 → List<String>
      // 將 Uint8List 轉成 Base64 存入 DB
      'screenshot': screenshotBase64,
      'created_by': account,
      'created_at': DateTime.now().toUtc().toIso8601String()
    });
  }
}
