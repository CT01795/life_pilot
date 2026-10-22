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
import 'package:life_pilot/utils/record_row_utils.dart';
import 'package:life_pilot/utils/model_record_entry_defaults.dart';
import 'package:life_pilot/utils/model_local_record_page.dart';
import 'package:life_pilot/utils/model_local_account_list.dart';
import 'package:life_pilot/utils/value_parser.dart';
import 'package:uuid/uuid.dart';
import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:life_pilot/local_storage/repository_local_event_account.dart';
import 'package:life_pilot/local_storage/repository_local_record_history.dart';
import 'package:life_pilot/local_storage/repository_local_record_editor.dart';
import 'package:life_pilot/local_storage/repository_local_account_summary.dart';

class ServiceAccounting {
  final _localAccountSummary = RepositoryLocalAccountSummary();
  final _localEventAccounts = RepositoryLocalEventAccount();
  final _localHistory = RepositoryLocalRecordHistory();
  final _localEditor = RepositoryLocalRecordEditor();
  String? get _localOwner => supabase.auth.currentUser?.email?.toLowerCase();

  Future<bool> get _storesLocally async {
    final owner = _localOwner;
    if (owner == null) return false;
    return await LocalDataStore.instance.preferredLocation(owner) ==
        DataStorageLocation.local;
  }

  String currentTable = TableNames.accountingAccount;
  ServiceAccounting();

  Future<(bool, String)?> latestDirectionAndCategory({
    required String accountId,
    String type = 'balance',
  }) async {
    Map<String, dynamic>? row;
    if (await _storesLocally) {
      row = await _localHistory.latestRecord(
        owner: _localOwner!,
        resource: TableNames.accountingDetail,
        accountId: accountId,
        type: type,
      );
    } else {
      final rows = await supabase
          .from(TableNames.accountingDetail)
          .select('value,primary_category')
          .eq('account_id', accountId)
          .ilike('type', type)
          .order('date', ascending: false)
          .limit(1);
      if (rows.isNotEmpty) row = Map<String, dynamic>.from(rows.first);
    }
    return ModelRecordEntryDefaults.accountingDirectionAndCategory(row);
  }

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

  Future<ModelAccountingAccount?> findAccountByEventId({
    required String eventId,
    required String user,
  }) async {
    try {
      if (await _storesLocally) {
        final response = await _localEventAccounts.find(
          owner: _localOwner!,
          eventId: eventId,
          accountResource: TableNames.accountingAccount,
          detailResource: TableNames.accountingDetail,
        );
        if (response == null) return null;
        return ModelAccountingAccount.fromRow(
          response,
          masterGraphUrl: parseMasterGraph(response['master_graph_url']),
        );
      }
      var response = await supabase
          .from(TableNames.accountingAccount)
          .select()
          .eq(Fields.id, eventId)
          .eq(Fields.createdBy, user)
          .eq(Fields.isValid, true)
          .maybeSingle();

      if (response == null) {
        final linkedDetail = await supabase
            .from(TableNames.accountingDetail)
            .select('account_id')
            .eq('event_id', eventId)
            .order('date', ascending: false)
            .limit(1)
            .maybeSingle();
        final linkedAccountId = parseOptionalStringValue(
          linkedDetail?['account_id'],
        );
        if (linkedAccountId != null) {
          response = await supabase
              .from(TableNames.accountingAccount)
              .select()
              .eq(Fields.id, linkedAccountId)
              .eq(Fields.createdBy, user)
              .eq(Fields.isValid, true)
              .maybeSingle();
        }
      }

      if (response == null) return null;

      Uint8List? bytes;
      if (response['master_graph_url'] != null) {
        bytes = await compute<String?, Uint8List?>(
          decodeBase64InIsolate,
          response['master_graph_url'],
        );
      }

      return ModelAccountingAccount.fromRow(response, masterGraphUrl: bytes);
    } on Exception {
      return null;
    }
  }

  /// Lightweight exact lookup for home quick entry; no account images.
  Future<ModelAccountingAccount?> fetchAccountById({
    required String user,
    required String accountId,
  }) async {
    if (accountId.isEmpty) return null;
    final local = await _storesLocally;
    Map<String, dynamic>? row;
    num? localTotal;
    if (local) {
      if (_localOwner != user.toLowerCase()) return null;
      final result = await _localAccountSummary.read(
        owner: user.toLowerCase(),
        accountId: accountId,
        points: false,
      );
      if (result == null) return null;
      row = result.row;
      localTotal = result.total;
    } else {
      row = await supabase
          .from(TableNames.accountingAccount)
          .select('id,account,category,balance,main_currency,exchange_rate')
          .eq(Fields.id, accountId)
          .eq(Fields.createdBy, user)
          .eq(Fields.isValid, true)
          .maybeSingle();
    }
    if (row == null) return null;
    return ModelAccountingAccount.fromRow(row, balanceOverride: localTotal);
  }

  Future<List<ModelAccountingAccount>> fetchAccounts({
    required String user,
    String? category, // null = all categories
    int? projectLimit,
    bool includeGraph = true,
  }) async {
    try {
      if (await _storesLocally) {
        final owner = _localOwner!;
        final snapshots = await Future.wait([
          LocalDataStore.instance.readOnlyRows(
            owner: owner,
            resource: TableNames.accountingAccount,
          ),
          LocalDataStore.instance.readOnlyRows(
            owner: owner,
            resource: TableNames.accountingDetail,
          ),
        ]);
        final page = ModelLocalAccountList.fromSnapshots(
          accounts: snapshots[0],
          details: snapshots[1],
          points: false,
          category: category,
          projectLimit: projectLimit,
        );
        return page.rows
            .map(
              (e) => ModelAccountingAccount.fromRow(
                e,
                masterGraphUrl: includeGraph
                    ? parseMasterGraph(e['master_graph_url'])
                    : null,
                balanceOverride: page.totalFor(e),
              ),
            )
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

      if (!includeGraph) {
        return list.map((row) => ModelAccountingAccount.fromRow(row)).toList();
      }
      return await Future.wait(
        list.map((e) async {
          final graph = e['master_graph_url'];
          final bytes = graph == null
              ? null
              : await compute<String?, Uint8List?>(
                  decodeBase64InIsolate,
                  graph,
                );

          return ModelAccountingAccount.fromRow(e, masterGraphUrl: bytes);
        }),
      );
    } on Exception catch (exception) {
      logger.e(exception);
      rethrow;
    }
  }

  Future<ModelAccountingAccount> createAccount({
    required String name,
    required String user,
    required String? currency,
    required String category,
    String? eventId,
  }) async {
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
          Fields.createdAt: now,
        };
        final existing =
            (await LocalDataStore.instance.list(
              owner: _localOwner!,
              resource: TableNames.accountingAccount,
            )).any(
              (r) =>
                  parseStringValue(r[Fields.account]).toLowerCase() ==
                      name.toLowerCase() &&
                  r['category'] == category &&
                  r[Fields.isValid] == true,
            );
        if (existing) throw Exception('Account already exists');
        await LocalDataStore.instance.put(
          owner: _localOwner!,
          resource: TableNames.accountingAccount,
          id: id,
          data: data,
        );
        return ModelAccountingAccount(
          id: id,
          accountName: name,
          category: category,
          masterGraphUrl: null,
          balance: 0,
          currency: currency,
          exchangeRate: null,
        );
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
              .update({Fields.isValid: true})
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
        balance: parseNumValue(result['balance']),
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
      if (await _storesLocally) {
        final rows = await LocalDataStore.instance.list(
          owner: _localOwner!,
          resource: TableNames.accountingAccount,
        );
        final matches = rows.where(
          (row) => parseStringValue(row[Fields.id]) == accountId,
        );
        if (matches.isNotEmpty) {
          await LocalDataStore.instance.put(
            owner: _localOwner!,
            resource: TableNames.accountingAccount,
            id: accountId,
            data: {...matches.first, Fields.isValid: false},
            syncState: LocalSyncState.modifiedLocally,
          );
        }
        final settings = await LocalDataStore.instance.list(
          owner: _localOwner!,
          resource: TableNames.dashboardSetting,
        );
        for (final setting in settings) {
          if (parseStringValue(setting['accounting_account_id']) != accountId) {
            continue;
          }
          await LocalDataStore.instance.put(
            owner: _localOwner!,
            resource: TableNames.dashboardSetting,
            id: _localOwner!,
            data: {
              ...setting,
              'accounting_account_id': null,
              'accounting_account_name': null,
            },
            syncState: LocalSyncState.modifiedLocally,
          );
        }
        return;
      }
      await supabase
          .from(TableNames.accountingAccount)
          .update({Fields.isValid: false})
          .eq(Fields.id, accountId);

      await supabase
          .from(TableNames.dashboardSetting)
          .update({
            'accounting_account_id': null,
            'accounting_account_name': null,
          })
          .eq('accounting_account_id', accountId);
    } catch (e, st) {
      logger.e('deleteAccount failed $e\n$st');
      rethrow;
    }
  }

  Future<Uint8List> uploadAccountImageBytesDirect(
    String accountId,
    Uint8List imageBytes,
  ) async {
    // 不管 Web / Mobile 都轉 base64
    // Mobile / Web 統一存 bytea (Uint8List)
    try {
      if (await _storesLocally) {
        await _localEditor.updateFields(
          owner: _localOwner!,
          resource: TableNames.accountingAccount,
          id: accountId,
          fields: {'master_graph_url': base64Encode(imageBytes)},
          notFoundMessage: 'accounting_account_not_found',
        );
        return imageBytes;
      }
      final result = await supabase
          .from(TableNames.accountingAccount)
          .update({'master_graph_url': base64Encode(imageBytes)})
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
      final rows = await LocalDataStore.instance.readOnlyRows(
        owner: _localOwner!,
        resource: TableNames.accountingDetail,
      );
      final page = ModelLocalRecordPage.accounting(
        rows,
        accountId: accountId,
        type: type,
        from: dateFrom,
        to: dateTo,
        includeLatestFallback: includeLatestFallback,
        includeReservedRecords: includeReservedRecords,
      );
      return page.rows.map((row) => _mapDetail(row, page.total)).toList();
    }
    final upperBound = recordDayUpperBound(dateTo);
    var query = supabase
        .from(TableNames.accountingDetail)
        .select()
        .eq('account_id', accountId)
        .ilike('type', type);
    if (includeReservedRecords) {
      query = query.or(
        recordRangeOrReservedFilter(from: dateFrom, upperBound: upperBound),
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
      result.addAll(
        localRows.where(
          (row) =>
              recordRowMatchesAccountAndType(
                row,
                accountId: accountId,
                type: type,
              ) &&
              recordRowIsInRange(
                row,
                from: dateFrom,
                upperBound: upperBound,
                includeReservedRecords: includeReservedRecords,
              ),
        ),
      );
    }
    final hasRegularRecord = result.any((row) => !isReservedRecordRow(row));
    if (includeLatestFallback && !hasRegularRecord) {
      final fallback = await supabase
          .from(TableNames.accountingDetail)
          .select()
          .eq('account_id', accountId)
          .ilike('type', type)
          .neq('primary_category', reservedRecordCategory)
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
        : parseNumValue(totalRows.first['balance']);
    if (owner != null && await _storesLocally) {
      final allLocal = await LocalDataStore.instance.list(
        owner: owner,
        resource: TableNames.accountingDetail,
      );
      balance += allLocal
          .where(
            (row) =>
                parseStringValue(row['account_id']) == accountId &&
                parseStringValue(row['type']) == type,
          )
          .fold<num>(0, (sum, row) => sum + parseNumValue(row['value']));
    }
    final unique = uniqueRecordRowsNewestFirst(result);
    return unique.map((detail) => _mapDetail(detail, balance)).toList();
  }

  Future<bool> hasRecordsBefore({
    required String accountId,
    required String type,
    required DateTime before,
  }) async {
    if (await _storesLocally) {
      return _localHistory.hasRecordsBefore(
        owner: _localOwner!,
        resource: TableNames.accountingDetail,
        accountId: accountId,
        type: type,
        before: before,
      );
    }
    final rows = await supabase
        .from(TableNames.accountingDetail)
        .select(Fields.id)
        .eq('account_id', accountId)
        .ilike('type', type)
        .lt('date', before.toUtc().toIso8601String())
        .neq('primary_category', reservedRecordCategory)
        .limit(1);
    return rows.isNotEmpty;
  }

  Future<DateTime?> latestRecordDateBefore({
    required String accountId,
    required String type,
    required DateTime before,
  }) async {
    if (await _storesLocally) {
      return _localHistory.latestRecordDateBefore(
        owner: _localOwner!,
        resource: TableNames.accountingDetail,
        accountId: accountId,
        type: type,
        before: before,
      );
    }
    final rows = await supabase
        .from(TableNames.accountingDetail)
        .select('date')
        .eq('account_id', accountId)
        .ilike('type', type)
        .lt('date', before.toUtc().toIso8601String())
        .neq('primary_category', reservedRecordCategory)
        .order('date', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    return tryParseDateTimeValue(rows.first['date'], toLocal: true);
  }

  ModelAccountingDetail _mapDetail(
    Map<String, dynamic> detail,
    dynamic balance,
  ) {
    return ModelAccountingDetail(
      id: parseStringValue(detail[Fields.id]),
      accountId: parseStringValue(detail['account_id']),
      createdAt:
          tryParseDateTimeValue(detail[Fields.createdAt]) ?? DateTime.now(),
      date:
          tryParseDateTimeValue(detail['date']) ??
          tryParseDateTimeValue(detail[Fields.createdAt]) ??
          DateTime.now(),
      primaryCategory: parseStringValue(
        detail['primary_category'],
        fallback: 'uncategorized',
      ),
      secondaryCategory: parseStringValue(detail['group']),
      description: parseStringValue(detail['description']),
      type: parseStringValue(detail['type']),
      value: parseNumValue(detail['value']),
      currency: parseStringValue(detail['currency']),
      exchangeRate: detail['exchange_rate'],
      balance: parseNumValue(balance),
    );
  }

  Future<void> insertRecordsBatch({
    required String accountId,
    required String type,
    required List<AccountingPreview> records,
    required String? currency,
  }) async {
    final now = DateTime.now();
    final recordsMap = records
        .map(
          (r) => {
            Fields.id: const Uuid().v4(),
            'description': r.description,
            'value': r.value,
            'currency': r.currency ?? currency,
            'primary_category': r.primaryCategory,
            'group': parseStringValue(r.secondaryCategory).trim(),
            'account_id': accountId,
            'event_id': r.eventId,
            'type': type,
            'date': (r.date ?? now).toUtc().toIso8601String(),
            Fields.createdAt: now.toUtc().toIso8601String(),
          },
        )
        .toList();

    try {
      if (await _storesLocally) {
        final owner = _localOwner!;
        for (final row in recordsMap) {
          await LocalDataStore.instance.put(
            owner: owner,
            resource: TableNames.accountingDetail,
            id: parseStringValue(row[Fields.id]),
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
    required num newValue,
    required String newCurrency,
    required String newDescription,
    required DateTime newDate,
    required String newPrimaryCategory,
    String? newSecondaryCategory,
  }) async {
    try {
      final owner = _localOwner;
      if (await _storesLocally) {
        if (owner == null) {
          throw StateError('Local accounting owner is unavailable.');
        }
        await _localEditor.updateFields(
          owner: owner,
          resource: TableNames.accountingDetail,
          id: detailId,
          fields: {
            'value': newValue,
            'currency': newCurrency,
            'description': newDescription,
            'date': newDate.toUtc().toIso8601String(),
            'primary_category': newPrimaryCategory,
            'group': parseStringValue(newSecondaryCategory).trim(),
          },
          notFoundMessage: 'accounting_detail_not_found',
        );
        return;
      }
      await supabase
          .from(TableNames.accountingDetail)
          .update({
            'value': newValue,
            'currency': newCurrency,
            'description': newDescription,
            'date': newDate.toUtc().toIso8601String(),
            'primary_category': newPrimaryCategory,
            'group': parseStringValue(newSecondaryCategory).trim(),
          })
          .eq(Fields.id, detailId);
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
      if (await _storesLocally) {
        final rows = await LocalDataStore.instance.readOnlyRows(
          owner: _localOwner!,
          resource: TableNames.accountingAccount,
        );
        return ModelRecordEntryDefaults.latestAccountCurrency(rows, category);
      }
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
      if (await _storesLocally) {
        final owner = _localOwner!;
        final rows = await LocalDataStore.instance.list(
          owner: owner,
          resource: TableNames.accountingAccount,
        );
        final account = rows
            .where((row) => parseStringValue(row[Fields.id]) == accountId)
            .firstOrNull;
        if (account == null) {
          throw StateError('Local accounting account not found.');
        }
        final details = await LocalDataStore.instance.list(
          owner: owner,
          resource: TableNames.accountingDetail,
        );
        final balance = details
            .where(
              (row) =>
                  parseStringValue(row['account_id']) == accountId &&
                  parseStringValue(row['currency']) == currency,
            )
            .fold<num>(0, (sum, row) => sum + parseNumValue(row['value']));
        await LocalDataStore.instance.put(
          owner: owner,
          resource: TableNames.accountingAccount,
          id: accountId,
          data: {
            ...account,
            'main_currency': currency,
            'balance': balance,
            'exchange_rate': null,
          },
          syncState: LocalSyncState.modifiedLocally,
        );
        return;
      }
      await supabase.rpc(
        'switch_main_currency',
        params: {'p_account_id': accountId, 'p_currency': currency},
      );
    } catch (e, st) {
      logger.e('switchMainCurrency failed $e\n$st');
      rethrow;
    }
  }

  Future<void> deleteAccountingDetail({required String detailId}) async {
    final owner = _localOwner;
    if (await _storesLocally) {
      if (owner == null) {
        throw StateError('Local accounting owner is unavailable.');
      }
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
