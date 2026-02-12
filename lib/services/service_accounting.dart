import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:life_pilot/core/logger.dart';
import 'package:life_pilot/models/accounting/model_accounting.dart';
import 'package:life_pilot/models/accounting/model_accounting_account.dart';
import 'package:life_pilot/models/accounting/model_accounting_preview.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide MultipartFile;
import 'package:dio/dio.dart';

class ServiceAccounting {
  final Dio dio;

  ServiceAccounting(this.dio);

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

  Future<ModelAccountingAccount?> findAccountByEventId(
      {required String eventId, required String user}) async {
    // 或者直接從 Supabase 查詢
    try {
      final res = await supabase
          .from('accounting_account')
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

      return ModelAccountingAccount(
        id: res['id'],
        accountName: res['account'],
        category: res['category'],
        masterGraphUrl: bytes,
        points: (res['points'] ?? 0).toInt(),
        balance: (res['balance'] ?? 0).toInt(),
        currency: res['main_currency'],
        exchangeRate: res['exchange_rate'],
      );
    } on Exception{
      return null;
    }
  }

  Future<List<ModelAccountingAccount>> fetchAccounts({
    required String user,
    required String currentType,
    required String category, // personal / project
  }) async {
    String currentTable = currentType == 'balance'
        ? 'accounting_account'
        : 'point_record_account';
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
      return ModelAccountingAccount(
        id: e['id'],
        accountName: e['account'],
        category: e['category'],
        masterGraphUrl: bytes,
        points: (e['points'] ?? 0).toInt(),
        balance: (e['balance'] ?? 0).toInt(),
        currency: e['main_currency'],
        exchangeRate: e['exchange_rate'],
      );
    }));
  }

  Future<String> fetchLatestAccount({
    required String user,
    required String currentType,
    required String category,
  }) async {
    String currentTable = currentType == 'balance'
        ? 'accounting_account'
        : 'point_record_account';
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

  Future<ModelAccountingAccount> createAccount(
      {required String name,
      required String user,
      required String? currency,
      required String currentType,
      required String category,
      String? eventId}) async {
    String currentTable = currentType == 'balance'
        ? 'accounting_account'
        : 'point_record_account';
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
            'balance': 0,
            'main_currency': currency, // 或 mainCurrency
            'exchange_rate': null,
          })
          .select()
          .single();
    }

    final bytes = parseMasterGraph(result['master_graph_url']);
    return ModelAccountingAccount(
        id: result['id'],
        accountName: result['account'],
        category: result['category'],
        masterGraphUrl: bytes,
        points: (result['points'] ?? 0).toInt(),
        balance: (result['balance'] ?? 0).toInt(),
        currency: result['main_currency'],
        exchangeRate: result['exchange_rate']);
  }

  Future<void> deleteAccount(
      {required String accountId, required String currentType}) async {
    String currentTable = currentType == 'balance'
        ? 'accounting_account'
        : 'point_record_account';
    await supabase
        .from(currentTable)
        .update({'is_valid': false}).eq('id', accountId);
  }

  Future<Uint8List> uploadAccountImageBytesDirect(
      String accountId, Uint8List imageBytes, String currentType) async {
    String currentTable = currentType == 'balance'
        ? 'accounting_account'
        : 'point_record_account';
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
  Future<List<ModelAccounting>> fetchTodayRecords(
      {required String accountId, required String type}) async {
    String currentFunc = type == 'balance'
        ? 'fetch_today_accountings'
        : 'fetch_today_point_records';
    final res = await supabase.rpc(
      currentFunc,
      params: {
        'p_account_id': accountId,
        'p_type': type,
      },
    );
    return (res as List)
        .map((e) => ModelAccounting(
              id: e['id'],
              accountId: e['account_id'],
              createdAt: DateTime.parse(e['created_at']),
              description: e['description'],
              type: e['type'],
              value: (e['value'] ?? 0).toInt(),
              currency: e.containsKey('currency') ? e['currency'] : '',
              exchangeRate:
                  e.containsKey('exchange_rate') ? e['exchange_rate'] : null,
            ))
        .toList();
  }

  Future<void> insertRecordsBatch(
      {required String accountId,
      required String type,
      required List<AccountingPreview> records,
      required String? currency,
      required String currentType}) async {
    String currentFunc = currentType == 'balance'
        ? 'add_accountings_batch'
        : 'add_point_records_batch';
    await supabase.rpc(
      currentFunc,
      params: {
        'p_account_id': accountId,
        'p_type': type,
        'p_records': records
            .map((r) => {
                  'description': r.description,
                  'value': r.value,
                  'currency': r.currency ?? currency,
                })
            .toList(),
      },
    );
  }

  Future<void> switchMainCurrency({
    required String accountId,
    required String currency,
  }) async {
    await supabase.rpc(
      'switch_main_currency',
      params: {
        'p_account_id': accountId,
        'p_currency': currency,
      },
    );
  }

  Future<void> updateAccountingDetail({
    required String detailId,
    required int newValue,
    required String newCurrency,
    required String newDescription,
  }) async {
    await supabase.rpc(
      'update_accounting_detail',
      params: {
        'p_detail_id': detailId,
        'p_new_value': newValue,
        'p_new_currency': newCurrency,
        'p_new_description': newDescription,
      },
    );
  }
}

Uint8List? decodeBase64InIsolate(String? data) {
  if (data == null) return null;
  try {
    return base64Decode(data);
  } catch (_) {
    return null;
  }
}
