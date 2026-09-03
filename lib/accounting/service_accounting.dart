import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:life_pilot/accounting/model_accounting_account.dart';
import 'package:life_pilot/accounting/model_accounting_detail.dart';
import 'package:life_pilot/accounting/model_accounting_preview.dart';
import 'package:life_pilot/utils/api.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/enum.dart';
import 'package:life_pilot/utils/graph.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:uuid/uuid.dart';
import 'package:life_pilot/local_storage/local_data_store.dart';

class ServiceAccounting {
  String? get _localOwner => supabase.auth.currentUser?.email?.toLowerCase();

  Future<bool> get _storesLocally async {
    final owner = _localOwner;
    if (owner == null) return false;
    return await LocalDataStore.instance.preferredLocation(owner) ==
        DataStorageLocation.local;
  }

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
      if (await _storesLocally) {
        final rows = await LocalDataStore.instance
            .list(owner: _localOwner!, resource: TableNames.accountingAccount);
        final response = rows
            .where((row) =>
                row[Fields.id]?.toString() == eventId &&
                row[Fields.isValid] == true)
            .firstOrNull;
        if (response == null) return null;
        return ModelAccountingAccount(
            id: response[Fields.id],
            accountName: response[Fields.account],
            category: response['category'],
            masterGraphUrl: parseMasterGraph(response['master_graph_url']),
            balance: (response['balance'] as num?)?.toInt() ?? 0,
            currency: response['main_currency'],
            exchangeRate: response['exchange_rate']);
      }
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
    String? category, // null = all categories
    int? projectLimit,
    bool includeGraph = true,
  }) async {
    try {
      if (await _storesLocally) {
        var rows = await LocalDataStore.instance
            .list(owner: _localOwner!, resource: TableNames.accountingAccount);
        final details = await LocalDataStore.instance
            .list(owner: _localOwner!, resource: TableNames.accountingDetail);
        rows = rows
            .where((row) =>
                row[Fields.isValid] == true &&
                (category == null || row['category']?.toString() == category))
            .toList();
        if (category == null && projectLimit != null) {
          final personal =
              rows.where((r) => r['category'] == AccountCategory.personal.name);
          final projects = rows
              .where((r) => r['category'] == AccountCategory.project.name)
              .toList()
            ..sort((a, b) => (b[Fields.createdAt]?.toString() ?? '')
                .compareTo(a[Fields.createdAt]?.toString() ?? ''));
          rows = [...personal, ...projects.take(projectLimit)];
        }
        return rows
            .map((e) => ModelAccountingAccount(
                id: e[Fields.id],
                accountName: e[Fields.account],
                category: e['category'],
                masterGraphUrl: includeGraph
                    ? parseMasterGraph(e['master_graph_url'])
                    : null,
                balance: details
                    .where((d) =>
                        d['account_id']?.toString() == e[Fields.id]?.toString())
                    .fold<int>(
                        0,
                        (sum, d) =>
                            sum +
                            (int.tryParse(d['value']?.toString() ?? '0') ?? 0)),
                currency: e['main_currency'],
                exchangeRate: e['exchange_rate']))
            .toList();
      }
      final columns = includeGraph
          ? '*'
          : 'id,account,category,balance,main_currency,exchange_rate';
      final List<dynamic> list;
      if (category == null && projectLimit != null) {
        final responses = await Future.wait([
          supabase
              .from(TableNames.accountingAccount)
              .select(columns)
              .eq(Fields.createdBy, user)
              .eq(Fields.isValid, true)
              .eq('category', AccountCategory.personal.name)
              .order(Fields.account, ascending: true),
          supabase
              .from(TableNames.accountingAccount)
              .select(columns)
              .eq(Fields.createdBy, user)
              .eq(Fields.isValid, true)
              .eq('category', AccountCategory.project.name)
              .order(Fields.createdAt, ascending: false)
              .limit(projectLimit),
        ]);
        list = [...responses[0], ...responses[1]];
      } else {
        var query = supabase
            .from(TableNames.accountingAccount)
            .select(columns)
            .eq(Fields.createdBy, user)
            .eq(Fields.isValid, true);
        if (category != null) {
          query = query.eq('category', category);
        }
        list = await query.order(Fields.account, ascending: true);
      }

      return Future.wait(
        list.map((e) async {
          final graph = e['master_graph_url'];
          final bytes = graph == null
              ? null
              : await compute<String?, Uint8List?>(
                  decodeBase64InIsolate,
                  graph,
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
      if (await _storesLocally) {
        final id = eventId ?? const Uuid().v4();
        final now = DateTime.now().toUtc().toIso8601String();
        final data = <String, Object?>{
          Fields.id: id,
          Fields.account: name,
          Fields.createdBy: user,
          'category': category,
          'main_currency': currency,
          'balance': 0,
          'exchange_rate': null,
          Fields.isValid: true,
          Fields.createdAt: now
        };
        final existing = (await LocalDataStore.instance.list(
                owner: _localOwner!, resource: TableNames.accountingAccount))
            .any((r) =>
                r[Fields.account]?.toString().toLowerCase() ==
                    name.toLowerCase() &&
                r['category'] == category &&
                r[Fields.isValid] == true);
        if (existing) throw Exception('Account already exists');
        await LocalDataStore.instance.put(
            owner: _localOwner!,
            resource: TableNames.accountingAccount,
            id: id,
            data: data);
        return ModelAccountingAccount(
            id: id,
            accountName: name,
            category: category,
            masterGraphUrl: null,
            balance: 0,
            currency: currency,
            exchangeRate: null);
      }
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
      if (await LocalDataStore.instance.contains(
          owner: _localOwner ?? '',
          resource: TableNames.accountingAccount,
          id: accountId)) {
        final rows = await LocalDataStore.instance
            .list(owner: _localOwner!, resource: TableNames.accountingAccount);
        final row =
            rows.firstWhere((r) => r[Fields.id]?.toString() == accountId);
        await LocalDataStore.instance.put(
            owner: _localOwner!,
            resource: TableNames.accountingAccount,
            id: accountId,
            data: {...row, Fields.isValid: false},
            syncState: LocalSyncState.modifiedLocally);
        return;
      }
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
      if (await LocalDataStore.instance.contains(
          owner: _localOwner ?? '',
          resource: TableNames.accountingAccount,
          id: accountId)) {
        final rows = await LocalDataStore.instance
            .list(owner: _localOwner!, resource: TableNames.accountingAccount);
        final row =
            rows.firstWhere((r) => r[Fields.id]?.toString() == accountId);
        await LocalDataStore.instance.put(
            owner: _localOwner!,
            resource: TableNames.accountingAccount,
            id: accountId,
            data: {...row, 'master_graph_url': base64Encode(imageBytes)},
            syncState: LocalSyncState.modifiedLocally);
        return imageBytes;
      }
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
  Future<List<ModelAccountingDetail>> fetchRecordsPage({
    required String accountId,
    required String type,
    required DateTime dateFrom,
    required DateTime dateTo,
    bool includeLatestFallback = false,
    bool includeReservedRecords = true,
  }) async {
    if (await _storesLocally) {
      final upperBound = DateTime(dateTo.year, dateTo.month, dateTo.day + 1);
      final rows = await LocalDataStore.instance.list(
        owner: _localOwner!,
        resource: TableNames.accountingDetail,
      );
      final accountRows = rows.where((row) =>
          row['account_id']?.toString() == accountId &&
          row['type']?.toString().toLowerCase() == type.toLowerCase());
      final balance = accountRows.fold<int>(
        0,
        (sum, row) =>
            sum + (int.tryParse(row['value']?.toString() ?? '0') ?? 0),
      );
      final filtered = accountRows.where((row) {
        if (includeReservedRecords && row['primary_category'] == 'reserved') {
          return true;
        }
        final date = DateTime.tryParse(row['date']?.toString() ?? '');
        return date != null &&
            !date.isBefore(dateFrom) &&
            date.isBefore(upperBound);
      }).toList()
        ..sort((a, b) => (b['date']?.toString() ?? '')
            .compareTo(a['date']?.toString() ?? ''));
      if (includeLatestFallback &&
          !filtered.any((row) => row['primary_category'] != 'reserved')) {
        final fallback = accountRows
            .where((row) => row['primary_category'] != 'reserved')
            .toList()
          ..sort((a, b) => (b['date']?.toString() ?? '')
              .compareTo(a['date']?.toString() ?? ''));
        if (fallback.isNotEmpty) filtered.add(fallback.first);
      }
      return filtered.map((row) => _mapDetail(row, balance)).toList();
    }
    final upperBound = DateTime(dateTo.year, dateTo.month, dateTo.day + 1);
    var query = supabase
        .from(TableNames.accountingDetail)
        .select()
        .eq('account_id', accountId)
        .ilike('type', type);
    if (includeReservedRecords) {
      query = query.or(
        'and(date.gte.${dateFrom.toUtc().toIso8601String()},date.lt.${upperBound.toUtc().toIso8601String()}),primary_category.eq.reserved',
      );
    } else {
      query = query
          .gte('date', dateFrom.toUtc().toIso8601String())
          .lt('date', upperBound.toUtc().toIso8601String());
    }
    final rows = await query.order('date', ascending: false);
    final result = List<Map<String, dynamic>>.from(rows);
    final owner = _localOwner;
    if (owner != null && await _storesLocally) {
      final localRows = await LocalDataStore.instance.list(
        owner: owner,
        resource: TableNames.accountingDetail,
      );
      result.addAll(localRows.where((row) {
        if (row['account_id']?.toString() != accountId ||
            row['type']?.toString().toLowerCase() != type.toLowerCase()) {
          return false;
        }
        if (includeReservedRecords && row['primary_category'] == 'reserved') {
          return true;
        }
        final date = DateTime.tryParse(row['date']?.toString() ?? '');
        return date != null &&
            !date.isBefore(dateFrom) &&
            date.isBefore(upperBound);
      }));
    }
    final hasRegularRecord =
        result.any((row) => row['primary_category'] != 'reserved');
    if (includeLatestFallback && !hasRegularRecord) {
      final fallback = await supabase
          .from(TableNames.accountingDetail)
          .select()
          .eq('account_id', accountId)
          .ilike('type', type)
          .neq('primary_category', 'reserved')
          .order('date', ascending: false)
          .limit(1);
      result.addAll(List<Map<String, dynamic>>.from(fallback));
    }
    final totalRows = await supabase
        .from(TableNames.accountingAccount)
        .select('balance')
        .eq(Fields.id, accountId)
        .limit(1);
    var balance = totalRows.isEmpty
        ? 0
        : int.tryParse(totalRows.first['balance']?.toString() ?? '0') ?? 0;
    if (owner != null && await _storesLocally) {
      final allLocal = await LocalDataStore.instance.list(
        owner: owner,
        resource: TableNames.accountingDetail,
      );
      balance += allLocal
          .where((row) =>
              row['account_id']?.toString() == accountId &&
              row['type']?.toString() == type)
          .fold<int>(
            0,
            (sum, row) =>
                sum + (int.tryParse(row['value']?.toString() ?? '0') ?? 0),
          );
    }
    final unique = <String, Map<String, dynamic>>{
      for (final row in result) row[Fields.id].toString(): row,
    }.values.toList()
      ..sort((a, b) =>
          (b['date']?.toString() ?? '').compareTo(a['date']?.toString() ?? ''));
    return unique.map((detail) => _mapDetail(detail, balance)).toList();
  }

  Future<bool> hasRecordsBefore({
    required String accountId,
    required String type,
    required DateTime before,
  }) async {
    if (await _storesLocally) {
      final rows = await LocalDataStore.instance.list(
        owner: _localOwner!,
        resource: TableNames.accountingDetail,
      );
      return rows.any((row) {
        final date = DateTime.tryParse(row['date']?.toString() ?? '');
        return row['account_id']?.toString() == accountId &&
            row['type']?.toString().toLowerCase() == type.toLowerCase() &&
            row['primary_category'] != 'reserved' &&
            date != null &&
            date.isBefore(before);
      });
    }
    final rows = await supabase
        .from(TableNames.accountingDetail)
        .select(Fields.id)
        .eq('account_id', accountId)
        .ilike('type', type)
        .lt('date', before.toUtc().toIso8601String())
        .neq('primary_category', 'reserved')
        .limit(1);
    return rows.isNotEmpty;
  }

  Future<DateTime?> latestRecordDateBefore({
    required String accountId,
    required String type,
    required DateTime before,
  }) async {
    if (await _storesLocally) {
      final rows = await LocalDataStore.instance.list(
        owner: _localOwner!,
        resource: TableNames.accountingDetail,
      );
      final dates = rows
          .where((row) =>
              row['account_id']?.toString() == accountId &&
              row['type']?.toString().toLowerCase() == type.toLowerCase() &&
              row['primary_category'] != 'reserved')
          .map((row) => DateTime.tryParse(row['date']?.toString() ?? ''))
          .whereType<DateTime>()
          .where((date) => date.isBefore(before))
          .toList()
        ..sort((a, b) => b.compareTo(a));
      return dates.isEmpty ? null : dates.first.toLocal();
    }
    final rows = await supabase
        .from(TableNames.accountingDetail)
        .select('date')
        .eq('account_id', accountId)
        .ilike('type', type)
        .lt('date', before.toUtc().toIso8601String())
        .neq('primary_category', 'reserved')
        .order('date', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    return DateTime.tryParse(rows.first['date']?.toString() ?? '')?.toLocal();
  }

  ModelAccountingDetail _mapDetail(
      Map<String, dynamic> detail, dynamic balance) {
    return ModelAccountingDetail(
      id: detail[Fields.id]?.toString() ?? '',
      accountId: detail['account_id']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(detail[Fields.createdAt]?.toString() ?? '') ??
              DateTime.now(),
      date: DateTime.tryParse(detail['date']?.toString() ?? '') ??
          DateTime.tryParse(detail[Fields.createdAt]?.toString() ?? '') ??
          DateTime.now(),
      primaryCategory:
          detail['primary_category']?.toString() ?? 'uncategorized',
      secondaryCategory: detail['group']?.toString(),
      description: detail['description']?.toString() ?? '',
      type: detail['type']?.toString() ?? '',
      value: detail['value'] is int
          ? detail['value'] as int
          : int.tryParse(detail['value']?.toString() ?? '0') ?? 0,
      currency: detail['currency']?.toString() ?? '',
      exchangeRate: detail['exchange_rate'],
      balance: balance is int
          ? balance
          : int.tryParse(balance?.toString() ?? '0') ?? 0,
    );
  }

  Future<void> insertRecordsBatch(
      {required String accountId,
      required String type,
      required List<AccountingPreview> records,
      required String? currency}) async {
    final now = DateTime.now();
    final recordsMap = records
        .map((r) => {
              Fields.id: const Uuid().v4(),
              'description': r.description,
              'value': r.value,
              'currency': r.currency ?? currency,
              'primary_category': r.primaryCategory,
              'group': r.secondaryCategory?.trim() ?? '',
              'account_id': accountId,
              'type': type,
              'date': (r.date ?? now).toUtc().toIso8601String(),
              Fields.createdAt: now.toUtc().toIso8601String(),
            })
        .toList();

    try {
      if (await _storesLocally) {
        final owner = _localOwner!;
        for (final row in recordsMap) {
          await LocalDataStore.instance.put(
            owner: owner,
            resource: TableNames.accountingDetail,
            id: row[Fields.id]!.toString(),
            data: row,
          );
        }
        return;
      }
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
      final owner = _localOwner;
      if (owner != null &&
          await LocalDataStore.instance.contains(
            owner: owner,
            resource: TableNames.accountingDetail,
            id: detailId,
          )) {
        final rows = await LocalDataStore.instance.list(
          owner: owner,
          resource: TableNames.accountingDetail,
        );
        final row = rows.firstWhere((item) => item[Fields.id] == detailId);
        await LocalDataStore.instance.put(
          owner: owner,
          resource: TableNames.accountingDetail,
          id: detailId,
          data: {
            ...row,
            'value': newValue,
            'currency': newCurrency,
            'description': newDescription,
            'date': newDate.toUtc().toIso8601String(),
            'primary_category': newPrimaryCategory,
            'group': newSecondaryCategory?.trim() ?? '',
          },
          syncState: LocalSyncState.modifiedLocally,
        );
        return;
      }
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

  Future<void> deleteAccountingDetail({required String detailId}) async {
    final owner = _localOwner;
    if (owner != null &&
        await LocalDataStore.instance.contains(
          owner: owner,
          resource: TableNames.accountingDetail,
          id: detailId,
        )) {
      await LocalDataStore.instance.delete(
        owner: owner,
        resource: TableNames.accountingDetail,
        id: detailId,
      );
      return;
    }
    await supabase.rpc(
      'delete_my_accounting_detail',
      params: {'p_detail_id': detailId},
    );
  }
}
