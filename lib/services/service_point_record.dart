import 'package:life_pilot/models/point_record/model_point_record.dart';
import 'package:life_pilot/models/point_record/model_point_record_account.dart';
import 'package:life_pilot/models/point_record/model_point_record_preview.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ServicePointRecord {
  final supabase = Supabase.instance.client;

  // ===== 帳戶 =====
  Future<List<ModelPointRecordAccount>> fetchAccounts({
    required String userId,
  }) async {
    final res = await supabase
        .from('point_record_account')
        .select()
        .eq('created_by', userId)
        .eq('is_valid', true)
        .order('account', ascending: true);

    return (res as List)
        .map((e) => ModelPointRecordAccount(
              id: e['id'],
              accountName: e['account'],
              masterGraphUrl: e['master_graph_url'],
              points: (e['points'] ?? 0).toInt(),
              balance: (e['balance'] ?? 0).toInt(),
            ))
        .toList();
  }

  Future<void> createAccount({
    required String name,
    required String userId,
  }) async {
    // 先檢查是否有重複帳戶
    final res = await supabase
        .from('point_record_account')
        .select('id, is_valid')
        .eq('created_by', userId)
        .eq('account', name)
        .maybeSingle();

    if (res != null) {
      if (res['is_valid'] == false) {
        // 帳戶存在但被刪除 → 直接改成 true
        await supabase
            .from('point_record_account')
            .update({'is_valid': true})
            .eq('id', res['id']);
        return;
      } else {
        throw Exception('Account already exists'); // 已存在有效帳戶
      }
    }

    await supabase.from('point_record_account').insert({
      'account': name,
      'created_by': userId,
      'points': 0,
      'balance': 0,
    });
  }

  Future<void> deleteAccount({
    required String accountId,
  }) async {
    await supabase
        .from('point_record_account')
        .update({'is_valid': false})
        .eq('id', accountId);
  }
  
  // ===== 明細 =====
  Future<List<ModelPointRecord>> fetchTodayRecords({
    required String accountId,
    required String type,
  }) async {
    final res = await supabase.rpc(
      'fetch_today_point_records',
      params: {
        'p_account_id': accountId,
        'p_type': type,
      },
    );
    /*final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final end = start.add(const Duration(days: 1));

    final res = await supabase
        .from('point_record_detail')
        .select()
        .eq('account_id', accountId)
        .eq('type', type)
        .gte('created_at', start.toIso8601String())
        .lt('created_at', end.toIso8601String())
        .order('created_at', ascending: false);
    */
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

  Future<void> insertRecordsBatch({
    required String accountId,
    required String type,
    required List<PointRecordPreview> records,
  }) async {
    await supabase.rpc(
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
  }
}
