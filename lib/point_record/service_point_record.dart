import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:life_pilot/point_record/model_point_record_account.dart';
import 'package:life_pilot/point_record/model_point_record_detail.dart';
import 'package:life_pilot/point_record/model_point_record_preview.dart';
import 'package:life_pilot/utils/api.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/graph.dart';
import 'package:life_pilot/utils/logger.dart';

class ServicePointRecord {
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
      final response =
          await apiSupabase.post('point_record/find_account_by_id', {
        'table_name': currentTable,
        'id': eventId,
        'user': user,
      });

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
      final response = await apiSupabase.post('point_record/fetch_accounts', {
        "table_name": TableNames.pointRecordAccount,
        "category": category,
        "user": user,
      });
      if (response == null) return [];

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
    await apiSupabase.post('point_record/delete_account', {
      "table_name": TableNames.pointRecordAccount,
      "id": accountId,
    });
  }

  Future<Uint8List> uploadAccountImageBytesDirect(
      String accountId, Uint8List imageBytes) async {
    try {
      // 不管 Web / Mobile 都轉 base64
      // Mobile / Web 統一存 bytea (Uint8List)
      await apiSupabase.post('point_record/upload_account_image_bytes_direct', {
        "table_name": TableNames.pointRecordAccount,
        "id": accountId,
        "master_graph_url": base64Encode(imageBytes),
      });
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
      final res = await apiSupabase.post('point_record/fetch_today_records', {
        "p_account_id": accountId,
        "p_type": type,
      });
      if (res == null || res is! List) {
        logger.e('fetchTodayRecords invalid response: $res');
        return [];
      }

      return res.map((e) {
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
      await apiSupabase.post('point_record/insert_records_batch', {
        "p_account_id": accountId,
        "p_type": type,
        "p_records": records
            .map((r) => {
                  'description': r.description,
                  'value': r.value,
                })
            .toList(),
      });
    } catch (e, st) {
      logger.e('insertRecordsBatch failed $e,$st');
      rethrow;
    }
  }
}
