import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:life_pilot/accounting/model_accounting_account.dart';
import 'package:life_pilot/accounting/model_accounting_detail.dart';
import 'package:life_pilot/accounting/model_accounting_preview.dart';
import 'package:life_pilot/utils/supabase.dart';
import 'package:life_pilot/accounting/repository_account_image.dart';
import 'package:life_pilot/accounting/repository_ledger_account_lookup.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:life_pilot/utils/record_row_utils.dart';
import 'package:life_pilot/record_statistics/repository_cloud_record_history.dart';
import 'package:life_pilot/utils/model_local_account_list.dart';
import 'package:life_pilot/utils/model_record_history_page.dart';
import 'package:life_pilot/utils/value_parser.dart';
import 'package:uuid/uuid.dart';
import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:life_pilot/local_storage/repository_local_event_account.dart';
import 'package:life_pilot/local_storage/repository_local_record_history.dart';
import 'package:life_pilot/local_storage/repository_local_record_editor.dart';
import 'package:life_pilot/local_storage/repository_local_account_summary.dart';

class ServiceAccounting {
  static const _accountModelColumns =
      'id,account,category,master_graph_url,balance,main_currency,exchange_rate';
  final _localAccountSummary = RepositoryLocalAccountSummary();
  final _localEventAccounts = RepositoryLocalEventAccount();
  final _localHistory = RepositoryLocalRecordHistory();
  final _cloudHistory = RepositoryCloudRecordHistory();
  final _localEditor = RepositoryLocalRecordEditor();
  String? get _localOwner => supabase.auth.currentUser?.email?.toLowerCase();

  Future<bool> get _storesLocally async {
    final owner = _localOwner;
    if (owner == null) return false;
    return await LocalDataStore.instance.preferredLocation(owner) ==
        DataStorageLocation.local;
  }

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
        return ModelAccountingAccount.fromRow(response);
      }
      final response = await RepositoryLedgerAccountLookup(
        supabase,
      ).find(kind: 'accounting', eventId: eventId, expectedEmail: user);

      if (response == null) return null;

      return ModelAccountingAccount.fromRow(response);
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
    int? offset,
    int? limit,
  }) async {
    try {
      if (await _storesLocally) {
        final owner = _localOwner!;
        final accountRows = offset != null && limit != null
            ? await LocalDataStore.instance.readOnlyMatchingPage(
                owner: owner,
                resource: TableNames.accountingAccount,
                matches: (row) =>
                    row[Fields.isValid] == true &&
                    (category == null || row['category'] == category),
                offset: offset,
                limit: limit,
              )
            : await LocalDataStore.instance.readOnlyRows(
                owner: owner,
                resource: TableNames.accountingAccount,
              );
        final selected = ModelLocalAccountList.selectAccounts(
          accounts: accountRows,
          category: category,
          projectLimit: projectLimit,
        );
        final totals = await LocalDataStore.instance.ledgerTotals(
          owner: owner,
          resource: TableNames.accountingDetail,
          accounts: selected.map(
            (row) => (
              accountId: parseStringValue(row[Fields.id]),
              currency: parseStringValue(row['main_currency']),
            ),
          ),
        );
        final page = ModelLocalAccountList.fromIndexedTotals(
          accounts: selected,
          totals: totals,
          points: false,
        );
        return page.rows
            .map(
              (e) => ModelAccountingAccount.fromRow(
                e,
                balanceOverride: page.totalFor(e),
              ),
            )
            .toList();
      }
      const columns = 'id,account,category,balance,main_currency,exchange_rate';
      final List<dynamic> list;
      if (category == null && projectLimit != null) {
        final response = await supabase.rpc(
          'get_my_ledger_account_options',
          params: {'p_kind': 'accounting', 'p_project_limit': projectLimit},
        );
        if (response is! List) {
          throw const FormatException('Invalid accounting account options');
        }
        list = List<dynamic>.from(response);
      } else {
        var query = supabase
            .from(TableNames.accountingAccount)
            .select(columns)
            .eq(Fields.createdBy, user)
            .eq(Fields.isValid, true);
        if (category != null) {
          query = query.eq('category', category);
        }
        final ordered = query.order(Fields.account, ascending: true);
        list = offset != null && limit != null
            ? await ordered.range(offset, offset + limit - 1)
            : await ordered;
      }

      return list.map((row) => ModelAccountingAccount.fromRow(row)).toList();
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
        final existing = await LocalDataStore.instance.readOnlyFirstMatchingRow(
          owner: _localOwner!,
          resource: TableNames.accountingAccount,
          matches: (row) =>
              parseStringValue(row[Fields.account]).toLowerCase() ==
                  name.toLowerCase() &&
              row['category'] == category &&
              row[Fields.isValid] == true,
        );
        if (existing != null) throw Exception('Account already exists');
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
          .select('id,is_valid')
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
              .select(_accountModelColumns)
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
            .select(_accountModelColumns)
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
        final account = await LocalDataStore.instance.readOnlyRow(
          owner: _localOwner!,
          resource: TableNames.accountingAccount,
          id: accountId,
        );
        if (account != null) {
          await LocalDataStore.instance.put(
            owner: _localOwner!,
            resource: TableNames.accountingAccount,
            id: accountId,
            data: {...account, Fields.isValid: false},
            syncState: LocalSyncState.modifiedLocally,
          );
        }
        final setting = await LocalDataStore.instance.readOnlyRow(
          owner: _localOwner!,
          resource: TableNames.dashboardSetting,
          id: _localOwner!,
        );
        if (setting != null) {
          if (parseStringValue(setting['accounting_account_id']) != accountId) {
            return;
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
    final owner = _localOwner;
    final fields = await RepositoryAccountImage.imageFields(imageBytes);
    if (_localOwner != owner) throw StateError('Account changed');
    // 不管 Web / Mobile 都轉 base64
    // Mobile / Web 統一存 bytea (Uint8List)
    try {
      if (await _storesLocally) {
        await _localEditor.updateFields(
          owner: _localOwner!,
          resource: TableNames.accountingAccount,
          id: accountId,
          fields: fields,
          notFoundMessage: 'accounting_account_not_found',
        );
        return imageBytes;
      }
      final result = await RepositoryAccountImage.writeCloud(
        TableNames.accountingAccount,
        accountId,
        fields,
      );

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
  Future<ModelRecordHistoryPage<ModelAccountingDetail>> fetchRecordsPage({
    required String accountId,
    required String type,
    required DateTime dateFrom,
    required DateTime dateTo,
    bool includeLatestFallback = false,
    bool includeReservedRecords = true,
  }) async {
    if (await _storesLocally) {
      final page = await _localHistory.page(
        owner: _localOwner!,
        resource: TableNames.accountingDetail,
        accountId: accountId,
        type: type,
        points: false,
        from: dateFrom,
        to: dateTo,
        includeLatestFallback: includeLatestFallback,
        includeReservedRecords: includeReservedRecords,
      );
      return ModelRecordHistoryPage(
        rows: page.rows.map((row) => _mapDetail(row, page.total)).toList(),
        total: page.total,
        nextBefore: page.nextBefore,
        nextDate: page.nextDate,
      );
    }
    final upperBound = recordDayUpperBound(dateTo);
    final combinedRows = await _cloudHistory.window(
      supabase,
      table: TableNames.accountingDetail,
      kind: 'accounting',
      accountId: accountId,
      type: type,
      from: dateFrom,
      until: upperBound,
      includeReserved: includeReservedRecords,
      includeLatest: includeLatestFallback,
    );
    final unique = uniqueRecordRowsNewestFirst(combinedRows.rows);
    return ModelRecordHistoryPage(
      rows: unique
          .map((detail) => _mapDetail(detail, combinedRows.total))
          .toList(),
      total: combinedRows.total,
      nextBefore: combinedRows.nextBefore,
      nextDate: combinedRows.nextDate,
    );
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
    _cloudHistory.invalidate();
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
    _cloudHistory.invalidate();
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
      await supabase.rpc(
        'update_my_ledger_detail',
        params: {
          'p_kind': 'accounting',
          'p_detail_id': detailId,
          'p_changes': {
            'value': newValue,
            'currency': newCurrency,
            'description': newDescription,
            'date': newDate.toUtc().toIso8601String(),
            'primary_category': newPrimaryCategory,
            'group': parseStringValue(newSecondaryCategory).trim(),
          },
        },
      );
    } catch (e, st) {
      logger.e('updateAccountingDetail failed $e\n$st');
      rethrow;
    }
  }

  Future<void> switchMainCurrency({
    required String accountId,
    required String currency,
  }) async {
    try {
      if (await _storesLocally) {
        final owner = _localOwner!;
        final account = await LocalDataStore.instance.readOnlyRow(
          owner: owner,
          resource: TableNames.accountingAccount,
          id: accountId,
        );
        if (account == null) {
          throw StateError('Local accounting account not found.');
        }
        final totals = await LocalDataStore.instance.ledgerTotals(
          owner: owner,
          resource: TableNames.accountingDetail,
          accounts: [(accountId: accountId, currency: currency)],
        );
        await LocalDataStore.instance.put(
          owner: owner,
          resource: TableNames.accountingAccount,
          id: accountId,
          data: {
            ...account,
            'main_currency': currency,
            'balance': totals[(accountId, currency)] ?? 0,
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
    _cloudHistory.invalidate();
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
