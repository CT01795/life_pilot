import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:life_pilot/core/graph.dart';
import 'package:life_pilot/core/logger.dart';
import 'package:life_pilot/models/point_record/model_point_record.dart';
import 'package:life_pilot/models/point_record/model_point_record_account.dart';
import 'package:life_pilot/models/point_record/model_point_record_preview.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide MultipartFile;
import 'package:dio/dio.dart';

class ServicePointRecord {
  final Dio dio;
  String currentTable = 'point_record_account';
  ServicePointRecord(this.dio);

  final supabase = Supabase.instance.client;

  // ===== 帳戶 =====
  Uint8List? parseMasterGraph(dynamic data) {
    if (data == null) return null;

    if (data is String) {
      try {
        return base64Decode(data);
      } catch (e) {
        logger.e(e);
        return null;
      }
    }
    return null;
  }

  Future<ModelPointRecordAccount?> findAccountByEventId(
      {required String eventId, required String user}) async {
    // 或者直接從 Supabase 查詢
    try {
      final res = await supabase
          .from(currentTable)
          .select('*')
          .eq('id', eventId)
          .eq('created_by', user)
          .eq('is_valid', true)
          .limit(1)
          .single();

      final bytes = await compute<String?, Uint8List?>(
        decodeBase64InIsolate,
        res['master_graph_url'],
      );

      return ModelPointRecordAccount(
        id: res['id'],
        accountName: res['account'],
        category: res['category'],
        masterGraphUrl: bytes,
        points: (res['points'] ?? 0).toInt(),
      );
    } on Exception{
      return null;
    }
  }

  Future<List<ModelPointRecordAccount>> fetchAccounts({
    required String user,
    required String category, // personal / project
  }) async {
    var query = supabase
        .from(currentTable)
        .select()
        .eq('created_by', user)
        .eq('is_valid', true)
        .eq('category', category);
    final res = await query.order('account', ascending: true);

    return Future.wait((res as List).map((e) async {
      final bytes = await compute<String?, Uint8List?>(
        decodeBase64InIsolate,
        e['master_graph_url'],
      );
      return ModelPointRecordAccount(
        id: e['id'],
        accountName: e['account'],
        category: e['category'],
        masterGraphUrl: bytes,
        points: (e['points'] ?? 0).toInt(),
      );
    }));
  }

  Future<String> fetchLatestAccount({
    required String user,
    required String category,
  }) async {
    var query = supabase
        .from(currentTable)
        .select()
        .eq('created_by', user)
        .eq('is_valid', true)
        .eq('category', category);
    final res = await query
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    return res?['main_currency'];
  }

  Future<ModelPointRecordAccount> createAccount(
      {required String name,
      required String user,
      required String? currency,
      required String category,
      String? eventId}) async {
    // 先檢查是否有重複帳戶
    var query = supabase
        .from(currentTable)
        .select('id, is_valid, category')
        .eq('created_by', user)
        .eq('account', name);
    final res = await query.maybeSingle();

    PostgrestMap result;
    if (res != null) {
      if (res['is_valid'] == false && res['category'] == category) {
        // 帳戶存在但被刪除 → 直接改成 true
        result = await supabase
            .from(currentTable)
            .update({'is_valid': true})
            .eq('id', res['id'])
            .eq('category', res['category'])
            .select()
            .single();
      } else {
        if (eventId != null) {
          result = await supabase
              .from(currentTable)
              .select('*')
              .eq('created_by', user)
              .eq('account', name)
              .single();
        } else {
          throw Exception('Account already exists'); // 已存在有效帳戶
        }
      }
    } else {
      result = await supabase
          .from(currentTable)
          .insert({
            'id': eventId,
            'account': name,
            'created_by': user,
            'category': category,
            'points': 0,
          })
          .select()
          .single();
    }

    final bytes = parseMasterGraph(result['master_graph_url']);
    return ModelPointRecordAccount(
        id: result['id'],
        accountName: result['account'],
        category: result['category'],
        masterGraphUrl: bytes,
        points: (result['points'] ?? 0).toInt(),);
  }

  Future<void> deleteAccount(
      {required String accountId}) async {
    await supabase
        .from(currentTable)
        .update({'is_valid': false}).eq('id', accountId);
  }

  Future<Uint8List> uploadAccountImageBytesDirect(
      String accountId, Uint8List imageBytes) async {
    try {
      // 不管 Web / Mobile 都轉 base64
      final base64Str = base64Encode(imageBytes);
      // Mobile / Web 統一存 bytea (Uint8List)
      await supabase
          .from(currentTable)
          .update({'master_graph_url': base64Str}).eq('id', accountId);
      return imageBytes;
    } catch (e, st) {
      logger.e('uploadAccountImageBytesDirect failed $e,$st');
      rethrow;
    }
  }

  // ===== 明細 =====
  Future<List<ModelPointRecord>> fetchTodayRecords(
      {required String accountId, required String type}) async {
    String currentFunc = 'fetch_today_point_records';
    final res = await supabase.rpc(
      currentFunc,
      params: {
        'p_account_id': accountId,
        'p_type': type,
      },
    );
    return (res as List)
        .map((e) => ModelPointRecord(
              id: e['id'],
              accountId: e['account_id'],
              createdAt: DateTime.parse(e['created_at']),
              description: e['description'],
              type: e['type'],
              value: (e['value'] ?? 0).toInt(),
            ))
        .toList();
  }

  Future<void> insertRecordsBatch(
      {required String accountId,
      required String type,
      required List<PointRecordPreview> records}) async {
    String currentFunc = 'add_point_records_batch';
    await supabase.rpc(
      currentFunc,
      params: {
        'p_account_id': accountId,
        'p_type': type,
        'p_records': records
            .map((r) => {
                  'description': r.description,
                  'value': r.value,
                })
            .toList(),
      },
    );
  }
}
