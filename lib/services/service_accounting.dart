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

  Future<List<ModelAccountingAccount>> fetchAccounts({
    required String user,
  }) async {
    final res = await supabase
        .from('accounting_account')
        .select()
        .eq('created_by', user)
        .eq('is_valid', true)
        .order('account', ascending: true);

    return Future.wait((res as List).map((e) async {
      final bytes = await compute<String?, Uint8List?>(
        decodeBase64InIsolate,
        e['master_graph_url'],
      );
      return ModelAccountingAccount(
        id: e['id'],
        accountName: e['account'],
        masterGraphUrl: bytes,
        points: (e['points'] ?? 0).toInt(),
        balance: (e['balance'] ?? 0).toInt(),
      );
    }));
  }

  Future<ModelAccountingAccount> createAccount({
    required String name,
    required String user,
  }) async {
    // 先檢查是否有重複帳戶
    final res = await supabase
        .from('accounting_account')
        .select('id, is_valid')
        .eq('created_by', user)
        .eq('account', name)
        .maybeSingle();

    PostgrestMap result;
    if (res != null) {
      if (res['is_valid'] == false) {
        // 帳戶存在但被刪除 → 直接改成 true
        result = await supabase
            .from('accounting_account')
            .update({'is_valid': true}).eq('id', res['id'])
            .select().single();
      } else {
        throw Exception('Account already exists'); // 已存在有效帳戶
      }
    } else {
      result = await supabase.from('accounting_account').insert({
        'account': name,
        'created_by': user,
        'points': 0,
        'balance': 0,
      })
      .select().single();
    }

    final bytes = parseMasterGraph(result['master_graph_url']);
    return ModelAccountingAccount(
      id: result['id'],
      accountName: result['account'],
      masterGraphUrl: bytes,
      points: (result['points'] ?? 0).toInt(),
      balance: (result['balance'] ?? 0).toInt(),
    );
  }

  Future<void> deleteAccount({
    required String accountId,
  }) async {
    await supabase
        .from('accounting_account')
        .update({'is_valid': false}).eq('id', accountId);
  }

  Future<Uint8List> uploadAccountImageBytesDirect(
      String accountId, Uint8List imageBytes) async {
    try {
      // 不管 Web / Mobile 都轉 base64
      final base64Str = base64Encode(imageBytes);
      // Mobile / Web 統一存 bytea (Uint8List)
      await supabase
          .from('accounting_account')
          .update({'master_graph_url': base64Str}).eq('id', accountId);
      return imageBytes;
    } catch (e, st) {
      logger.e('uploadAccountImageBytesDirect failed $e,$st');
      rethrow;
    }
  }

  // ===== 明細 =====
  Future<List<ModelAccounting>> fetchTodayRecords({
    required String accountId,
    required String type,
  }) async {
    final res = await supabase.rpc(
      'fetch_today_accountings',
      params: {
        'p_account_id': accountId,
        'p_type': type,
      },
    );
    /*final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final end = start.add(const Duration(days: 1));

    final res = await supabase
        .from('accounting_detail')
        .select()
        .eq('account_id', accountId)
        .eq('type', type)
        .gte('created_at', start.toIso8601String())
        .lt('created_at', end.toIso8601String())
        .order('created_at', ascending: false);
    */
    return (res as List)
        .map((e) => ModelAccounting(
              id: e['id'],
              accountId: e['account_id'],
              createdAt: DateTime.parse(e['created_at']),
              description: e['description'],
              type: e['type'],
              value: (e['value'] ?? 0).toInt(),
            ))
        .toList();
  }

  Future<void> insertRecordsBatch({
    required String accountId,
    required String type,
    required List<AccountingPreview> records,
  }) async {
    await supabase.rpc(
      'add_accountings_batch',
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

Uint8List? decodeBase64InIsolate(String? data) {
  if (data == null) return null;
  try {
    return base64Decode(data);
  } catch (_) {
    return null;
  }
}
