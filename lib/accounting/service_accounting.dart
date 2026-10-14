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
import 'package:life_pilot/utils/value_parser.dart';
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

  Future<(bool, String)?> latestDirectionAndCategory({
    required String accountId,
    String type = 'balance',
  }) async {
    Map<String, dynamic>? row;
    if (await _storesLocally) {
      final rows = await LocalDataStore.instance.list(
        owner: _localOwner!,
        resource: TableNames.accountingDetail,
      );
      row = latestRecordRowForAccountAndType(
        rows,
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
    if (row == null) return null;
    final value = parseNumValue(row['value']);
    return (value > 0, parseStringValue(row['primary_category'], fallback: 'uncategorized'));
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
        final accounts = await LocalDataStore.instance.list(
          owner: _localOwner!,
          resource: TableNames.accountingAccount,
        );
        final matchingAccount = accounts
            .where(
              (row) =>
                  parseStringValue(row[Fields.id]) == eventId &&
                  row[Fields.isValid] == true,
            )
            .firstOrNull;
        String? accountId = parseOptionalStringValue(
          matchingAccount?[Fields.id],
        );
        if (accountId == null) {
          final details = await LocalDataStore.instance.list(
            owner: _localOwner!,
            resource: TableNames.accountingDetail,
          );
          accountId = parseOptionalStringValue(
            latestRecordRowForEvent(details, eventId)?['account_id'],
          );
        }
        final response = accounts
            .where(
              (row) =>
                  parseStringValue(row[Fields.id]) == accountId &&
                  row[Fields.isValid] == true,
            )
            .firstOrNull;
        if (response == null) return null;
        return ModelAccountingAccount(
          id: response[Fields.id],
          accountName: response[Fields.account],
          category: response['category'],
          masterGraphUrl: parseMasterGraph(response['master_graph_url']),
          balance: parseNumValue(response['balance']),
          currency: response['main_currency'],
          exchangeRate: response['exchange_rate'],
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

      return ModelAccountingAccount(
        id: response[Fields.id],
        accountName: response[Fields.account],
        category: response['category'],
        masterGraphUrl: bytes,
        balance: parseNumValue(response['balance']),
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
        var rows = await LocalDataStore.instance.list(
          owner: _localOwner!,
          resource: TableNames.accountingAccount,
        );
        final details = await LocalDataStore.instance.list(
          owner: _localOwner!,
          resource: TableNames.accountingDetail,
        );
        rows = rows
            .where(
              (row) =>
                  row[Fields.isValid] == true &&
                  (category == null || parseStringValue(row['category']) == category),
            )
            .toList();
        if (category == null && projectLimit != null) {
          final personal = rows.where(
            (r) => r['category'] == AccountCategory.personal.name,
          );
          final projects =
              rows
                  .where((r) => r['category'] == AccountCategory.project.name)
                  .toList()
                ..sort(
                  (a, b) => parseStringValue(b[Fields.createdAt]).compareTo(
                    parseStringValue(a[Fields.createdAt]),
                  ),
                );
          rows = [...personal, ...projects.take(projectLimit)];
        }
        return rows
            .map(
              (e) => ModelAccountingAccount(
                id: e[Fields.id],
                accountName: e[Fields.account],
                category: e['category'],
                masterGraphUrl: includeGraph
                    ? parseMasterGraph(e['master_graph_url'])
                    : null,
                balance: details
                    .where(
                      (d) =>
                          parseStringValue(d['account_id']) ==
                              parseStringValue(e[Fields.id]) &&
                          parseStringValue(d['currency']) ==
                              parseStringValue(e['main_currency']),
                    )
                    .fold<num>(0, (sum, d) => sum + parseNumValue(d['value'])),
                currency: e['main_currency'],
                exchangeRate: e['exchange_rate'],
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

      return await Future.wait(
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
            balance: parseNumValue(e['balance']),
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
        final rows = await LocalDataStore.instance.list(
          owner: _localOwner!,
          resource: TableNames.accountingAccount,
        );
        final matches = rows.where(
          (row) => parseStringValue(row[Fields.id]) == accountId,
        );
        if (matches.isEmpty) {
          throw StateError('accounting_account_not_found');
        }
        final row = matches.first;
        await LocalDataStore.instance.put(
          owner: _localOwner!,
          resource: TableNames.accountingAccount,
          id: accountId,
          data: {...row, 'master_graph_url': base64Encode(imageBytes)},
          syncState: LocalSyncState.modifiedLocally,
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
      final rows = await LocalDataStore.instance.list(
        owner: _localOwner!,
        resource: TableNames.accountingDetail,
      );
      final accountRows = rows.where(
        (row) =>
            parseStringValue(row['account_id']) == accountId &&
            parseStringValue(row['type']).toLowerCase() == type.toLowerCase(),
      );
      final balance = accountRows.fold<num>(
        0,
        (sum, row) => sum + parseNumValue(row['value']),
      );
      final filtered = filterRecordRows(
        accountRows,
        from: dateFrom,
        to: dateTo,
        includeLatestFallback: includeLatestFallback,
        includeReservedRecords: includeReservedRecords,
      );
      return filtered.map((row) => _mapDetail(row, balance)).toList();
    }
    final upperBound = recordDayUpperBound(dateTo);
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
      final rows = await LocalDataStore.instance.list(
        owner: _localOwner!,
        resource: TableNames.accountingDetail,
      );
      return hasRecordRowBefore(
        rows.where(
          (row) => recordRowMatchesAccountAndType(
            row,
            accountId: accountId,
            type: type,
          ),
        ),
        before,
      );
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
      return latestRecordRowDateBefore(
        rows.where(
          (row) => recordRowMatchesAccountAndType(
            row,
            accountId: accountId,
            type: type,
          ),
        ),
        before,
      );
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
        final rows = await LocalDataStore.instance.list(
          owner: owner,
          resource: TableNames.accountingDetail,
        );
        final matches = rows.where(
          (item) => parseStringValue(item[Fields.id]) == detailId,
        );
        if (matches.isEmpty) {
          throw StateError('accounting_detail_not_found');
        }
        final row = matches.first;
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
            'group': parseStringValue(newSecondaryCategory).trim(),
          },
          syncState: LocalSyncState.modifiedLocally,
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
        final rows = await LocalDataStore.instance.list(
          owner: _localOwner!,
          resource: TableNames.accountingAccount,
        );
        final matching =
            rows
                .where(
                  (row) =>
                      row[Fields.isValid] == true &&
                      parseStringValue(row['category']) == category,
                )
                .toList()
              ..sort(
                (a, b) => parseStringValue(b[Fields.createdAt]).compareTo(
                  parseStringValue(a[Fields.createdAt]),
                ),
              );
        return matching.isEmpty
            ? 'TWD'
            : parseStringValue(matching.first['main_currency'], fallback: 'TWD');
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
