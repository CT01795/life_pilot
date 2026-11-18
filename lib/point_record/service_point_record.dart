import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:life_pilot/point_record/model_point_record_account.dart';
import 'package:life_pilot/point_record/model_point_record_detail.dart';
import 'package:life_pilot/point_record/model_point_record_preview.dart';
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

class ServicePointRecord {
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

  Future<ModelPointRecordAccount?> findAccountByEventId({
    required String eventId,
    required String user,
  }) async {
    try {
      if (await _storesLocally) {
        final response = await _localEventAccounts.find(
          owner: _localOwner!,
          eventId: eventId,
          accountResource: TableNames.pointRecordAccount,
          detailResource: TableNames.pointRecordDetail,
        );
        if (response == null) return null;
        return ModelPointRecordAccount.fromRow(response);
      }
      final response = await RepositoryLedgerAccountLookup(
        supabase,
      ).find(kind: 'points', eventId: eventId, expectedEmail: user);

      if (response == null) return null;

      return ModelPointRecordAccount.fromRow(response);
    } on Exception catch (exception) {
      logger.e(exception);
      return null;
    }
  }

  /// Lightweight exact lookup for home quick entry; no account images.
  Future<ModelPointRecordAccount?> fetchAccountById({
    required String user,
    required String accountId,
  }) async {
    if (accountId.isEmpty) return null;
    final local = await _storesLocally;
    Map<String, dynamic>? row;
    int? localTotal;
    if (local) {
      if (_localOwner != user.toLowerCase()) return null;
      final result = await _localAccountSummary.read(
        owner: user.toLowerCase(),
        accountId: accountId,
        points: true,
      );
      if (result == null) return null;
      row = result.row;
      localTotal = result.total.toInt();
    } else {
      row = await supabase
          .from(TableNames.pointRecordAccount)
          .select('id,account,category,points')
          .eq(Fields.id, accountId)
          .eq(Fields.createdBy, user)
          .eq(Fields.isValid, true)
          .maybeSingle();
    }
    if (row == null) return null;
    return ModelPointRecordAccount.fromRow(row, pointsOverride: localTotal);
  }

  Future<List<ModelPointRecordAccount>> fetchAccounts({
    required String user,
    String? category, // null = all categories
    String? searchQuery,
    int? projectLimit,
    int? offset,
    int? limit,
  }) async {
    try {
      if (await _storesLocally) {
        final owner = _localOwner!;
        final normalizedSearch = searchQuery?.trim().toLowerCase() ?? '';
        final accountRows = offset != null && limit != null
            ? await LocalDataStore.instance.readOnlyMatchingPage(
                owner: owner,
                resource: TableNames.pointRecordAccount,
                matches: (row) =>
                    row[Fields.isValid] == true &&
                    (category == null || row['category'] == category) &&
                    (normalizedSearch.isEmpty ||
                        parseStringValue(
                          row[Fields.account],
                        ).toLowerCase().contains(normalizedSearch)),
                offset: offset,
                limit: limit,
              )
            : await LocalDataStore.instance.readOnlyRows(
                owner: owner,
                resource: TableNames.pointRecordAccount,
              );
        final selected = ModelLocalAccountList.selectAccounts(
          accounts: accountRows,
          category: category,
          projectLimit: projectLimit,
        );
        final totals = await LocalDataStore.instance.ledgerTotals(
          owner: owner,
          resource: TableNames.pointRecordDetail,
          accounts: selected.map(
            (row) =>
                (accountId: parseStringValue(row[Fields.id]), currency: null),
          ),
        );
        final page = ModelLocalAccountList.fromIndexedTotals(
          accounts: selected,
          totals: totals,
          points: true,
        );
        return page.rows
            .map(
              (e) => ModelPointRecordAccount.fromRow(
                e,
                pointsOverride: page.totalFor(e).toInt(),
              ),
            )
            .toList();
      }
      const columns = 'id,account,category,points';
      final List<dynamic> list;
      if (category == null && projectLimit != null) {
        final response = await supabase.rpc(
          'get_my_ledger_account_options',
          params: {'p_kind': 'points', 'p_project_limit': projectLimit},
        );
        if (response is! List) {
          throw const FormatException('Invalid point account options');
        }
        list = List<dynamic>.from(response);
      } else {
        var query = supabase
            .from(TableNames.pointRecordAccount)
            .select(columns)
            .eq(Fields.createdBy, user)
            .eq(Fields.isValid, true);
        if (category != null) {
          query = query.eq('category', category);
        }
        final normalizedSearch = searchQuery?.trim() ?? '';
        if (normalizedSearch.isNotEmpty) {
          query = query.ilike(Fields.account, '%$normalizedSearch%');
        }
        final ordered = query.order(Fields.account, ascending: true);
        list = offset != null && limit != null
            ? await ordered.range(offset, offset + limit - 1)
            : await ordered;
      }

      return list.map((row) => ModelPointRecordAccount.fromRow(row)).toList();
    } on Exception catch (exception) {
      logger.e(exception);
      rethrow;
    }
  }

  Future<ModelPointRecordAccount> createAccount({
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
        final existing = await LocalDataStore.instance.readOnlyFirstMatchingRow(
          owner: _localOwner!,
          resource: TableNames.pointRecordAccount,
          matches: (row) =>
              parseStringValue(row[Fields.account]).toLowerCase() ==
                  name.toLowerCase() &&
              row['category'] == category &&
              row[Fields.isValid] == true,
        );
        if (existing != null) throw Exception('Account already exists');
        await LocalDataStore.instance.put(
          owner: _localOwner!,
          resource: TableNames.pointRecordAccount,
          id: id,
          data: {
            Fields.id: id,
            Fields.account: name,
            Fields.createdBy: user,
            'category': category,
            'points': 0,
            Fields.isValid: true,
            Fields.createdAt: now,
          },
        );
        return ModelPointRecordAccount(
          id: id,
          accountName: name,
          category: category,
          masterGraphUrl: null,
          points: 0,
        );
      }
      final result = await supabase.rpc(
        'create_or_restore_my_ledger_account',
        params: {
          'p_kind': 'points',
          'p_account_id': eventId ?? const Uuid().v4(),
          'p_name': name,
          'p_category': category,
          'p_currency': currency,
        },
      );
      if (result is! Map) {
        throw const FormatException('Invalid point account response');
      }
      final response = Map<String, dynamic>.from(result);

      final bytes = parseMasterGraph(response['master_graph_url']);
      return ModelPointRecordAccount(
        id: response[Fields.id],
        accountName: response[Fields.account],
        category: response['category'],
        masterGraphUrl: bytes,
        points: parseIntValue(response['points']),
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
          resource: TableNames.pointRecordAccount,
          id: accountId,
        );
        if (account != null) {
          await LocalDataStore.instance.put(
            owner: _localOwner!,
            resource: TableNames.pointRecordAccount,
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
          if (parseStringValue(setting['point_account_id']) != accountId) {
            return;
          }
          await LocalDataStore.instance.put(
            owner: _localOwner!,
            resource: TableNames.dashboardSetting,
            id: _localOwner!,
            data: {
              ...setting,
              'point_account_id': null,
              'point_account_name': null,
            },
            syncState: LocalSyncState.modifiedLocally,
          );
        }
        return;
      }
      await supabase
          .from(TableNames.pointRecordAccount)
          .update({Fields.isValid: false})
          .eq(Fields.id, accountId);

      await supabase
          .from(TableNames.dashboardSetting)
          .update({'point_account_id': null, 'point_account_name': null})
          .eq('point_account_id', accountId);
    } catch (e, stacktrace) {
      logger.e("deleteAccount error", error: e, stackTrace: stacktrace);
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
    try {
      if (await _storesLocally) {
        await _localEditor.updateFields(
          owner: _localOwner!,
          resource: TableNames.pointRecordAccount,
          id: accountId,
          fields: fields,
          notFoundMessage: 'point_account_not_found',
        );
        return imageBytes;
      }
      // 不管 Web / Mobile 都轉 base64
      // Mobile / Web 統一存 bytea (Uint8List)
      final result = await RepositoryAccountImage.writeCloud(
        TableNames.pointRecordAccount,
        accountId,
        fields,
      );

      if (result.isEmpty) {
        throw Exception("account not found or invalid");
      }
      return imageBytes;
    } catch (e, st) {
      logger.e('uploadAccountImageBytesDirect failed $e,$st');
      rethrow;
    }
  }

  // ===== 明細 =====
  Future<ModelRecordHistoryPage<ModelPointRecordDetail>> fetchRecordsPage({
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
        resource: TableNames.pointRecordDetail,
        accountId: accountId,
        type: type,
        points: true,
        from: dateFrom,
        to: dateTo,
        includeLatestFallback: includeLatestFallback,
        includeReservedRecords: includeReservedRecords,
      );
      return ModelRecordHistoryPage(
        rows: page.rows.map((detail) {
          return ModelPointRecordDetail(
            id: parseStringValue(detail[Fields.id]),
            accountId: parseStringValue(detail['account_id']),
            createdAt:
                tryParseDateTimeValue(detail[Fields.createdAt]) ??
                DateTime.now(),
            date: tryParseDateTimeValue(detail['date']) ?? DateTime.now(),
            primaryCategory: parseStringValue(
              detail['primary_category'],
              fallback: 'uncategorized',
            ),
            secondaryCategory: parseStringValue(detail['group']),
            description: parseStringValue(detail['description']),
            type: parseStringValue(detail['type']),
            value: parseIntValue(detail['value']),
            points: page.total.toInt(),
          );
        }).toList(),
        total: page.total,
        nextBefore: page.nextBefore,
        nextDate: page.nextDate,
      );
    }
    final upperBound = recordDayUpperBound(dateTo);
    final combinedRows = await _cloudHistory.window(
      supabase,
      table: TableNames.pointRecordDetail,
      kind: 'points',
      accountId: accountId,
      type: type,
      from: dateFrom,
      until: upperBound,
      includeReserved: includeReservedRecords,
      includeLatest: includeLatestFallback,
    );
    final points = combinedRows.total.toInt();
    final unique = uniqueRecordRowsNewestFirst(combinedRows.rows);
    return ModelRecordHistoryPage(
      rows: unique.map((detail) {
        return ModelPointRecordDetail(
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
          value: parseIntValue(detail['value']),
          points: points,
        );
      }).toList(),
      total: combinedRows.total,
      nextBefore: combinedRows.nextBefore,
      nextDate: combinedRows.nextDate,
    );
  }

  Future<void> insertRecordsBatch({
    required String accountId,
    required String type,
    required List<PointRecordPreview> records,
  }) async {
    _cloudHistory.invalidate();
    final now = DateTime.now();
    try {
      if (await _storesLocally) {
        final owner = _localOwner!;
        for (final record in records) {
          final id = const Uuid().v4();
          await LocalDataStore.instance.put(
            owner: owner,
            resource: TableNames.pointRecordDetail,
            id: id,
            data: {
              Fields.id: id,
              'account_id': accountId,
              'type': type,
              'description': record.description,
              'value': record.value,
              'primary_category': record.primaryCategory,
              'group': parseStringValue(record.secondaryCategory).trim(),
              'event_id': record.eventId,
              'date': (record.date ?? now).toUtc().toIso8601String(),
              Fields.createdAt: now.toUtc().toIso8601String(),
            },
          );
        }
        return;
      }
      await supabase.rpc(
        'add_point_records_batch',
        params: {
          'p_account_id': accountId,
          'p_type': type,
          'p_records': records
              .map(
                (r) => {
                  'description': r.description,
                  'value': r.value,
                  'primary_category': r.primaryCategory,
                  'group': parseStringValue(r.secondaryCategory).trim(),
                  'event_id': r.eventId,
                  'date': (r.date ?? now).toUtc().toIso8601String(),
                },
              )
              .toList(),
        },
      );
    } catch (e, st) {
      logger.e('insertRecordsBatch failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> updatePointRecordDetail({
    required String detailId,
    required int newValue,
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
          throw StateError('Local point owner is unavailable.');
        }
        await _localEditor.updateFields(
          owner: owner,
          resource: TableNames.pointRecordDetail,
          id: detailId,
          fields: {
            'value': newValue,
            'description': newDescription,
            'date': newDate.toUtc().toIso8601String(),
            'primary_category': newPrimaryCategory,
            'group': parseStringValue(newSecondaryCategory).trim(),
          },
          notFoundMessage: 'point_detail_not_found',
        );
        return;
      }
      await supabase.rpc(
        'update_my_ledger_detail',
        params: {
          'p_kind': 'points',
          'p_detail_id': detailId,
          'p_changes': {
            'value': newValue,
            'description': newDescription,
            'date': newDate.toUtc().toIso8601String(),
            'primary_category': newPrimaryCategory,
            'group': parseStringValue(newSecondaryCategory).trim(),
          },
        },
      );
    } catch (e, st) {
      logger.e('updatePointRecordDetail failed $e\n$st');
      rethrow;
    }
  }

  Future<void> deletePointRecordDetail({required String detailId}) async {
    _cloudHistory.invalidate();
    final owner = _localOwner;
    if (await _storesLocally) {
      if (owner == null) {
        throw StateError('Local point owner is unavailable.');
      }
      await LocalDataStore.instance.delete(
        owner: owner,
        resource: TableNames.pointRecordDetail,
        id: detailId,
      );
      return;
    }
    await supabase.rpc(
      'delete_my_point_record_detail',
      params: {'p_detail_id': detailId},
    );
  }
}
