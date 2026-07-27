import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:life_pilot/point_record/model_point_record_account.dart';
import 'package:life_pilot/point_record/model_point_record_detail.dart';
import 'package:life_pilot/point_record/model_point_record_preview.dart';
import 'package:life_pilot/utils/api.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/graph.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ServicePointRecord {
  final SupabaseClient _supabase = Supabase.instance.client;
  String currentTable = TableNames.pointRecordAccount;
  ServicePointRecord();

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
    try {
      final response = await _supabase
        .from(currentTable)
        .select()
        .eq('id', eventId)
        .eq('created_by', user)
        .eq('is_valid', true)
        .maybeSingle();

      if (response == null) {
        return null;
      }

      Uint8List? bytes;
      if (response['master_graph_url'] != null) {
        bytes = await compute<String?, Uint8List?>(
          decodeBase64InIsolate,
          response['master_graph_url'],
        );
      }

      return ModelPointRecordAccount(
        id: response['id'],
        accountName: response['account'],
        category: response['category'],
        masterGraphUrl: bytes,
        points: (response['points'] ?? 0).toInt(),
      );
    } on Exception catch (exception) {
      logger.e(exception);
      return null;
    }
  }

  Future<List<ModelPointRecordAccount>> fetchAccounts({
    required String user,
    required String category, // personal / project
  }) async {
    try {
      final response = await _supabase
        .from(TableNames.pointRecordAccount)
        .select()
        .eq('created_by', user)
        .eq('category', category)
        .eq('is_valid', true)
        .order('account', ascending: true);

      if (response.isEmpty) {
        return [];
      }

      final list = (response as List);
      return Future.wait(list.map((e) async {
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
    } on Exception catch (exception) {
      logger.e(exception);
      return [];
    }
  }

  Future<ModelPointRecordAccount> createAccount(
      {required String name,
      required String user,
      required String? currency,
      required String category,
      String? eventId}) async {
    try {
      Map res = {
        "id": eventId,
        "account": name,
        "created_by": user,
        "category": category,
      };
      final response = await apiSupabase.post('point_record/create_account', {
        "table_name": TableNames.pointRecordAccount,
        "data": res,
      });
      final bytes = parseMasterGraph(response['master_graph_url']);
      return ModelPointRecordAccount(
        id: response['id'],
        accountName: response['account'],
        category: response['category'],
        masterGraphUrl: bytes,
        points: (response['points'] ?? 0).toInt(),
      );
    } catch (e, st) {
      logger.e('createAccount failed $e,$st');
      rethrow;
    }
  }

  Future<void> deleteAccount({required String accountId}) async {
    try {
      final result = await _supabase
          .from(TableNames.pointRecordAccount)
          .update({
            'is_valid': false,
          })
          .eq('id', accountId)
          .select();

      if (result.isEmpty) {
        throw Exception("account not found");
      }
    } catch (e, stacktrace) {
      logger.e(
        "deleteAccount error",
        error: e,
        stackTrace: stacktrace,
      );
      rethrow;
    }
  }

  Future<Uint8List> uploadAccountImageBytesDirect(
      String accountId, Uint8List imageBytes) async {
    try {
      // 不管 Web / Mobile 都轉 base64
      // Mobile / Web 統一存 bytea (Uint8List)
      final result = await Supabase.instance.client
        .from(TableNames.pointRecordAccount)
        .update({
          'master_graph_url': base64Encode(imageBytes),
        })
        .eq('id', accountId)
        .eq('is_valid', true)
        .select();

      if (result.isEmpty) {
        throw Exception("account not found or invalid");
      }
      return imageBytes;
    } catch (e, st) {
      logger.e('uploadAccountImageBytesDirect failed $e,$st');
      rethrow;
    }
  }

  // ===== 明細 =====
  Future<List<ModelPointRecordDetail>> fetchTodayRecords(
      {required String accountId, required String type}) async {
    try {
      final res = await _supabase.rpc(
        'fetch_today_point_records',
        params: {
          'p_account_id': accountId,
          'p_type': type,
        },
      );

      if (res == null || res is! List) {
        logger.e('fetchTodayRecords invalid response: $res');
        return [];
      }

      return res.map<ModelPointRecordDetail>((e) {
        final rawDetail = e['detail'];

        // 🔥 強制轉 Map（關鍵）
        final detail = (rawDetail is Map) ? rawDetail : <String, dynamic>{};

        return ModelPointRecordDetail(
          id: detail['id']?.toString() ?? '',
          accountId: detail['account_id']?.toString() ?? '',
          createdAt:
              DateTime.tryParse(detail['created_at']?.toString() ?? '') ??
                  DateTime.now(),
          description: detail['description']?.toString() ?? '',
          type: detail['type']?.toString() ?? '',
          value: detail['value'] is int
              ? detail['value']
              : int.tryParse(detail['value']?.toString() ?? '0') ?? 0,
          points: (e['points'] ?? 0) as int,
        );
      }).toList();
    } catch (e, st) {
      logger.e('fetchTodayRecords failed $e,$st');
      rethrow;
    }
  }

  Future<void> insertRecordsBatch(
      {required String accountId,
      required String type,
      required List<PointRecordPreview> records}) async {
    try {
      await _supabase.rpc(
        'add_point_records_batch',
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
    } catch (e, st) {
      logger.e(
        'insertRecordsBatch failed',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }
}
