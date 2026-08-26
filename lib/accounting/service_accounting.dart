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
      final response = await supabase
          .from(TableNames.accountingAccount)
          .select()
          .eq(Fields.id, eventId)
          .eq(Fields.createdBy, user)
          .eq(Fields.isValid, true)
          .maybeSingle();

      if (response == null) return null;

      Uint8List? bytes;
      if (response['master_graph_url'] != null) {
        bytes = await compute<String?, Uint8List?>(
          decodeBase64InIsolate,
          response['master_graph_url'],
        );
      }

      return ModelAccountingAccount(
        id: response[Fields.id],
        accountName: response[Fields.account],
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
      final response = await supabase
          .from(TableNames.accountingAccount)
          .select()
          .eq('category', category)
          .eq(Fields.createdBy, user)
          .eq(Fields.isValid, true)
          .order(Fields.account, ascending: true);

      final list = (response as List);
      return Future.wait(
        list.map((e) async {
          final bytes = await compute<String?, Uint8List?>(
            decodeBase64InIsolate,
            e['master_graph_url'],
          );

          return ModelAccountingAccount(
            id: e[Fields.id],
            accountName: e[Fields.account],
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
    try {
      // 1. 查詢是否已存在
      final exist = await supabase
          .from(TableNames.accountingAccount)
          .select()
          .eq(Fields.createdBy, user)
          .eq(Fields.account, name)
          .eq('category', category)
          .maybeSingle();

      Map<String, dynamic> result;

      if (exist != null) {
        // 2. 已存在但無效 -> 恢復
        if (exist[Fields.isValid] != true) {
          result = await supabase
              .from(TableNames.accountingAccount)
              .update({
                Fields.isValid: true,
              })
              .eq(Fields.id, exist[Fields.id])
              .select()
              .single();
        } else {
          throw Exception('Account already exists');
        }
      } else {
        // 3. 新增
        result = await supabase
            .from(TableNames.accountingAccount)
            .insert({
              Fields.id: eventId ?? const Uuid().v4(),
              Fields.account: name,
              Fields.createdBy: user,
              'category': category,
              'main_currency': currency,
              'balance': 0,
              'exchange_rate': null,
              Fields.isValid: true,
            })
            .select()
            .single();
      }

      final bytes = parseMasterGraph(result['master_graph_url']);

      return ModelAccountingAccount(
        id: result[Fields.id],
        accountName: result[Fields.account],
        category: result['category'],
        masterGraphUrl: bytes,
        balance: (result['balance'] ?? 0).toInt(),
        currency: result['main_currency'],
        exchangeRate: result['exchange_rate'],
      );
    } catch (e, st) {
      logger.e('createAccount failed $e,$st');
      rethrow;
    }
  }

  Future<void> deleteAccount({required String accountId}) async {
    try {
      await supabase.from(TableNames.accountingAccount).update({
        Fields.isValid: false,
      }).eq(Fields.id, accountId);

      await supabase.from(TableNames.dashboardSetting).update({
        'accounting_account_id': null,
        'accounting_account_name': null,
      }).eq('accounting_account_id', accountId);
    } catch (e, st) {
      logger.e('deleteAccount failed $e\n$st');
      rethrow;
    }
  }

  Future<Uint8List> uploadAccountImageBytesDirect(
      String accountId, Uint8List imageBytes) async {
    // 不管 Web / Mobile 都轉 base64
    // Mobile / Web 統一存 bytea (Uint8List)
    try {
      final result = await supabase
          .from(TableNames.accountingAccount)
          .update({
            'master_graph_url': base64Encode(imageBytes),
          })
          .eq(Fields.id, accountId)
          .eq(Fields.isValid, true)
          .select();

      if ((result as List).isEmpty) {
        throw Exception('Account not found');
      }
      return imageBytes;
    } catch (e, st) {
      logger.e('uploadAccountImageBytesDirect failed $e\n$st');
      rethrow;
    }
  }

  // ===== 明細 =====
  Future<List<ModelAccountingDetail>> fetchTodayRecords(
      {required String accountId, required String type}) async {
    final res = await supabase.rpc(
      'fetch_today_accountings',
      params: {
        'p_account_id': accountId,
        'p_type': type,
      },
    );

    if (res == null || res is! List) {
      logger.e('fetchTodayRecords invalid response: $res');
      return [];
    }

    return res.map((e) {
      final detail = (e['detail'] as Map?) ?? {};

      return ModelAccountingDetail(
        id: detail[Fields.id]?.toString() ?? '',
        accountId: detail['account_id']?.toString() ?? '',
        createdAt:
            DateTime.tryParse(detail[Fields.createdAt] ?? '') ?? DateTime.now(),
        date: DateTime.tryParse(detail['date'] ?? '') ??
            DateTime.tryParse(detail[Fields.createdAt] ?? '') ??
            DateTime.now(),
        primaryCategory:
            detail['primary_category']?.toString() ?? 'uncategorized',
        secondaryCategory: detail['group']?.toString(),
        description: detail['description'] ?? '',
        type: detail['type'] ?? '',
        value: detail['value'] ?? 0,
        currency: detail['currency'] ?? '',
        exchangeRate: detail['exchange_rate'],
        balance: e['balance'] ?? 0,
      );
    }).toList();
  }

  Future<void> insertRecordsBatch(
      {required String accountId,
      required String type,
      required List<AccountingPreview> records,
      required String? currency}) async {
    final recordsMap = records
        .map((r) => {
              Fields.id: const Uuid().v4(),
              'description': r.description,
              'value': r.value,
              'currency': r.currency ?? currency,
              'primary_category': r.primaryCategory,
              'group': r.secondaryCategory?.trim() ?? '',
            })
        .toList();

    try {
      await supabase.rpc(
        'add_accountings_batch2',
        params: {
          'p_account_id': accountId,
          'p_type': type,
          'p_records': recordsMap,
        },
      );
    } catch (e, st) {
      logger.e('insertRecordsBatch failed $e\n$st');
      rethrow;
    }
  }

  Future<void> updateAccountingDetail({
    required String detailId,
    required int newValue,
    required String newCurrency,
    required String newDescription,
    required DateTime newDate,
    required String newPrimaryCategory,
    String? newSecondaryCategory,
  }) async {
    try {
      await supabase.rpc(
        'update_accounting_detail_with_date',
        params: {
          'p_detail_id': detailId,
          'p_new_value': newValue,
          'p_new_currency': newCurrency,
          'p_new_description': newDescription,
          'p_new_date': newDate.toUtc().toIso8601String(),
          'p_new_primary_category': newPrimaryCategory,
          'p_new_group': newSecondaryCategory?.trim() ?? '',
        },
      );
    } catch (e, st) {
      logger.e('updateAccountingDetail failed $e\n$st');
      rethrow;
    }
  }

  Future<String> fetchLatestAccount({
    required String user,
    required String category,
  }) async {
    try {
      final response = await supabase
          .from(TableNames.accountingAccount)
          .select('main_currency')
          .eq(Fields.createdBy, user)
          .eq('category', category)
          .eq(Fields.isValid, true)
          .order(Fields.createdAt, ascending: false)
          .limit(1)
          .maybeSingle();

      return response?['main_currency'] ?? 'TWD';
    } catch (e, st) {
      logger.e('fetchLatestAccount failed $e\n$st');
      return 'TWD';
    }
  }

  Future<void> switchMainCurrency({
    required String accountId,
    required String currency,
  }) async {
    try {
      await supabase.rpc(
        'switch_main_currency',
        params: {
          'p_account_id': accountId,
          'p_currency': currency,
        },
      );
    } catch (e, st) {
      logger.e('switchMainCurrency failed $e\n$st');
      rethrow;
    }
  }
}
