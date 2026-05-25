import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:life_pilot/accounting/model_accounting_account.dart';
import 'package:life_pilot/accounting/model_accounting_detail.dart';
import 'package:life_pilot/accounting/model_accounting_preview.dart';
import 'package:life_pilot/utils/api.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/graph.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:uuid/uuid.dart';

class ServiceAccounting {
  String currentTable = TableNames.accountingAccount;
  ServiceAccounting();

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

  Future<ModelAccountingAccount?> findAccountByEventId(
      {required String eventId, required String user}) async {
    try {
      
      final response = await apiSupabase.post('accounting/find_account_by_id', {
        "table_name": TableNames.accountingAccount,
        "id": eventId,
        "user": user,
      });
      Uint8List? bytes;
      if (response['master_graph_url'] != null) {
        bytes = await compute<String?, Uint8List?>(
          decodeBase64InIsolate,
          response['master_graph_url'],
        );
      }

      return ModelAccountingAccount(
        id: response['id'],
        accountName: response['account'],
        category: response['category'],
        masterGraphUrl: bytes,
        balance: (response['balance'] ?? 0).toInt(),
        currency: response['main_currency'],
        exchangeRate: response['exchange_rate'],
      );
    } on Exception {
      return null;
    }
  }

  Future<List<ModelAccountingAccount>> fetchAccounts({
    required String user,
    required String category, // personal / project
  }) async {
    try {
      
      final response = await apiSupabase.post('accounting/fetch_accounts', {
        "table_name": TableNames.accountingAccount,
        "category": category,
        "user": user,
      });
      if (response == null) return [];
      final list = (response as List);
      return Future.wait(
        list.map((e) async {
          final bytes = await compute<String?, Uint8List?>(
            decodeBase64InIsolate,
            e['master_graph_url'],
          );

          return ModelAccountingAccount(
            id: e['id'],
            accountName: e['account'],
            category: e['category'],
            masterGraphUrl: bytes,
            balance: (e['balance'] ?? 0).toInt(),
            currency: e['main_currency'],
            exchangeRate: e['exchange_rate'],
          );
        }),
      );
    } on Exception catch (exception) {
      logger.e(exception);
      return [];
    }
  }

  Future<ModelAccountingAccount> createAccount(
      {required String name,
      required String user,
      required String? currency,
      required String category,
      String? eventId}) async {
    Map map = {
      "id": eventId ?? const Uuid().v4(),
      "account": name,
      "created_by": user,
      "category": category,
      "main_currency": currency,
    };

    try {
      final result = await apiSupabase.post('accounting/create_account', {
        "table_name": TableNames.accountingAccount,
        "data": map,
      });

      final bytes = parseMasterGraph(result['master_graph_url']);
      return ModelAccountingAccount(
          id: result['id'],
          accountName: result['account'],
          category: result['category'],
          masterGraphUrl: bytes,
          balance: (result['balance'] ?? 0).toInt(),
          currency: result['main_currency'],
          exchangeRate: result['exchange_rate']);
    } catch (e, st) {
      logger.e('createAccount failed $e,$st');
      rethrow;
    }
  }

  Future<void> deleteAccount({required String accountId}) async {
    try {
      await apiSupabase.post('accounting/delete_account', {
        "table_name": TableNames.accountingAccount,
        "id": accountId,
      });
    } catch (e, st) {
      logger.e('deleteAccount failed $e,$st');
      rethrow;
    }
  }

  Future<Uint8List> uploadAccountImageBytesDirect(
      String accountId, Uint8List imageBytes) async {
    // 不管 Web / Mobile 都轉 base64
    // Mobile / Web 統一存 bytea (Uint8List)
    try {
      await apiSupabase.post('accounting/upload_account_image_bytes_direct', {
        "table_name": TableNames.accountingAccount,
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
  Future<List<ModelAccountingDetail>> fetchTodayRecords(
      {required String accountId, required String type}) async {
    final res = await apiSupabase.post('accounting/fetch_today_records', {
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
      return ModelAccountingDetail(
        id: detail['id']?.toString() ?? '',
        accountId: detail['account_id']?.toString() ?? '',
        createdAt: DateTime.tryParse(detail['created_at']?.toString() ?? '') ??
            DateTime.now(),
        description: detail['description']?.toString() ?? '',
        type: detail['type']?.toString() ?? '',
        value: detail['value'] is int
            ? detail['value']
            : int.tryParse(detail['value']?.toString() ?? '0') ?? 0,
        currency: detail.containsKey('currency') ? detail['currency'] : '',
        exchangeRate: detail.containsKey('exchange_rate')
            ? detail['exchange_rate']
            : null,
        balance: (e['balance'] ?? 0) as int,
      );
    }).toList();
  }

  Future<void> insertRecordsBatch(
      {required String accountId,
      required String type,
      required List<AccountingPreview> records,
      required String? currency}) async {
    List<Map> recordsMap = records
      .map((r) => {
            'id': const Uuid().v4(),
            'description': r.description,
            'value': r.value,
            'currency': r.currency ?? currency,
          })
      .toList();
    try {
      await apiSupabase.post('accounting/insert_records_batch', {
        "p_account_id": accountId,
        "p_type": type,
        "p_records": recordsMap,
      });
    } catch (e, st) {
      logger.e('insertRecordsBatch failed $e,$st');
      rethrow;
    }
  }

  Future<void> updateAccountingDetail({
    required String detailId,
    required int newValue,
    required String newCurrency,
    required String newDescription,
  }) async {
    try {
      await apiSupabase.post('accounting/update_accounting_detail', {
        "p_detail_id": detailId,
        "p_new_value": newValue,
        "p_new_currency": newCurrency,
        "p_new_description": newDescription,
      });
    } catch (e, st) {
      logger.e('updateAccountingDetail failed $e,$st');
      rethrow;
    }
  }

  Future<String> fetchLatestAccount({
    required String user,
    required String category,
  }) async {
    try {
      final res = await apiSupabase.post('accounting/fetch_latest_account', {
        "table_name": TableNames.accountingAccount,
        "category": category,
        "user": user,
      });
      
      return res?['main_currency'];
    } on Exception catch (exception) {
      logger.e(exception);
      return "";
    }
  }

  Future<void> switchMainCurrency({
    required String accountId,
    required String currency,
  }) async {
    try {
      await apiSupabase.post('accounting/switch_main_currency', {
        "p_account_id": accountId,
        "p_currency": currency,
      });
    } catch (e, st) {
      logger.e('switchMainCurrency failed $e,$st');
      rethrow;
    }
  }
}
