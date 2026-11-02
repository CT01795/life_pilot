import 'dart:convert';
import 'dart:typed_data';
import 'package:life_pilot/feedback/model_feedback.dart';
import 'package:life_pilot/utils/supabase.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/value_parser.dart';
import '../utils/logger.dart';

class ServiceFeedback {
  Future<void> sendFeedback({
    required String account,
    required String subject,
    required String content,
    List<String>? cc, // ← 改成 List<String>
    List<Uint8List>? screenshots, // ← 支援多張
  }) async {
    final screenshotBase64 = screenshots
        ?.map((bytes) => base64Encode(bytes))
        .toList();
    await supabase.from(TableNames.feedback).insert({
      'subject': subject,
      'content': content,
      'cc': cc, // text[]
      'screenshot': screenshotBase64, // text[] 或 bytea[]，依你的 schema
      Fields.createdBy: account,
      Fields.createdAt: DateTime.now().toUtc().toIso8601String(),
      'is_ok': false,
    });
  }

  Future<List<dynamic>> loadFeedback({
    required DateTime dateFrom,
    required DateTime dateTo,
  }) async {
    try {
      final response = await supabase
          .from(TableNames.feedback)
          .select(
            'id,subject,content,cc,created_by,created_at,is_ok,deal_by,deal_at,status',
          )
          .gte(Fields.createdAt, dateFrom.toUtc().toIso8601String())
          .lt(Fields.createdAt, dateTo.toUtc().toIso8601String())
          .order(Fields.createdAt, ascending: false);

      return response;
    } catch (e, st) {
      logger.e('loadFeedback failed $e', stackTrace: st);
      rethrow;
    }
  }

  Future<bool> hasFeedbackBefore(DateTime before) async {
    final rows = await supabase
        .from(TableNames.feedback)
        .select(Fields.id)
        .lt(Fields.createdAt, before.toUtc().toIso8601String())
        .limit(1);
    return rows.isNotEmpty;
  }

  Future<List<String>> loadScreenshots(int id) async {
    final client = supabase;
    final owner = client.auth.currentUser?.id;
    if (owner == null) throw StateError('Authentication required');
    final row = await client
        .from(TableNames.feedback)
        .select('screenshot')
        .eq('id', id)
        .maybeSingle();
    if (client.auth.currentUser?.id != owner) {
      throw StateError('Feedback account changed');
    }
    if (row == null) throw StateError('Feedback no longer visible');
    return (row['screenshot'] as List? ?? const [])
        .map((value) => value as String)
        .toList(growable: false);
  }

  Future<DateTime?> latestFeedbackDateBefore(DateTime before) async {
    final rows = await supabase
        .from(TableNames.feedback)
        .select(Fields.createdAt)
        .lt(Fields.createdAt, before.toUtc().toIso8601String())
        .order(Fields.createdAt, ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    return tryParseDateTimeValue(rows.first[Fields.createdAt], toLocal: true);
  }

  Future<void> updateFeedback({required ModelFeedback feedback}) async {
    final data = feedback.toMap();
    await supabase
        .from(TableNames.feedback)
        .update({
          'is_ok': data['is_ok'],
          'deal_by': data['deal_by'],
          'deal_at': data['deal_at'],
          'status': data['status'],
        })
        .eq(Fields.id, data[Fields.id]);
  }
}
