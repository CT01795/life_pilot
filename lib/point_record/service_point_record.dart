import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:life_pilot/point_record/model_point_record_account.dart';
import 'package:life_pilot/point_record/model_point_record_detail.dart';
import 'package:life_pilot/point_record/model_point_record_preview.dart';
import 'package:life_pilot/utils/supabase.dart';
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

class ServicePointRecord {
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

  String currentTable = TableNames.pointRecordAccount;
  ServicePointRecord();

  Future<(bool, String)?> latestDirectionAndCategory({
    required String accountId,
    String type = 'points',
  }) async {
    Map<String, dynamic>? row;
    if (await _storesLocally) {
      row = await _localHistory.latestRecord(
        owner: _localOwner!,
        resource: TableNames.pointRecordDetail,
        accountId: accountId,
        type: type,
      );
    } else {
      final rows = await supabase
          .from(TableNames.pointRecordDetail)
          .select('value,primary_category')
          .eq('account_id', accountId)
          .ilike('type', type)
          .order('date', ascending: false)
          .limit(1);
      if (rows.isNotEmpty) row = Map<String, dynamic>.from(rows.first);
    }
    return ModelRecordEntryDefaults.pointDirectionAndCategory(row);
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
        return ModelPointRecordAccount.fromRow(
          response,
          masterGraphUrl: parseMasterGraph(response['master_graph_url']),
        );
      }
      var response = await supabase
          .from(currentTable)
          .select()
          .eq(Fields.id, eventId)
          .eq(Fields.createdBy, user)
          .eq(Fields.isValid, true)
          .maybeSingle();

      if (response == null) {
        final linkedDetail = await supabase
            .from(TableNames.pointRecordDetail)
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
              .from(currentTable)
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

      return ModelPointRecordAccount.fromRow(response, masterGraphUrl: bytes);
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
    int? projectLimit,
    bool includeGraph = true,
  }) async {
    try {
      if (await _storesLocally) {
        final owner = _localOwner!;
        final snapshots = await Future.wait([
          LocalDataStore.instance.readOnlyRows(
            owner: owner,
            resource: TableNames.pointRecordAccount,
          ),
          LocalDataStore.instance.readOnlyRows(
            owner: owner,
            resource: TableNames.pointRecordDetail,
          ),
        ]);
        final page = ModelLocalAccountList.fromSnapshots(
          accounts: snapshots[0],
          details: snapshots[1],
          points: true,
          category: category,
          projectLimit: projectLimit,
        );
        return page.rows
            .map(
              (e) => ModelPointRecordAccount.fromRow(
                e,
                masterGraphUrl: includeGraph
                    ? parseMasterGraph(e['master_graph_url'])
                    : null,
                pointsOverride: page.totalFor(e).toInt(),
              ),
            )
            .toList();
      }
      final columns = includeGraph ? '*' : 'id,account,category,points';
      final List<dynamic> list;
      if (category == null && projectLimit != null) {
        final responses = await Future.wait([
          supabase
              .from(TableNames.pointRecordAccount)
              .select(columns)
              .eq(Fields.createdBy, user)
              .eq(Fields.isValid, true)
              .eq('category', AccountCategory.personal.name)
              .order(Fields.account, ascending: true),
          supabase
              .from(TableNames.pointRecordAccount)
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
            .from(TableNames.pointRecordAccount)
            .select(columns)
            .eq(Fields.createdBy, user)
            .eq(Fields.isValid, true);
        if (category != null) {
          query = query.eq('category', category);
        }
        list = await query.order(Fields.account, ascending: true);
      }

      if (list.isEmpty) return [];
      if (!includeGraph) {
        return list.map((row) => ModelPointRecordAccount.fromRow(row)).toList();
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
          return ModelPointRecordAccount.fromRow(e, masterGraphUrl: bytes);
        }),
      );
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
        final existing =
            (await LocalDataStore.instance.list(
              owner: _localOwner!,
              resource: TableNames.pointRecordAccount,
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
      // 查詢是否已存在
      final exist = await supabase
          .from(TableNames.pointRecordAccount)
          .select()
          .eq(Fields.createdBy, user)
          .eq(Fields.account, name)
          .eq('category', category)
          .maybeSingle();

      Map<String, dynamic> response;

      if (exist != null) {
        // 已存在但被刪除 -> 恢復
        if (exist[Fields.isValid] != true) {
          response = await supabase
              .from(TableNames.pointRecordAccount)
              .update({Fields.isValid: true})
              .eq(Fields.id, exist[Fields.id])
              .select()
              .single();
        } else {
          throw Exception('Account already exists');
        }
      } else {
        // 新增帳戶
        response = await supabase
            .from(TableNames.pointRecordAccount)
            .insert({
              Fields.id: eventId ?? const Uuid().v4(),
              Fields.account: name,
              Fields.createdBy: user,
              'category': category,
              'points': 0,
              Fields.isValid: true,
            })
            .select()
            .single();
      }

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
        final rows = await LocalDataStore.instance.list(
          owner: _localOwner!,
          resource: TableNames.pointRecordAccount,
        );
        final matches = rows.where(
          (row) => parseStringValue(row[Fields.id]) == accountId,
        );
        if (matches.isNotEmpty) {
          await LocalDataStore.instance.put(
            owner: _localOwner!,
            resource: TableNames.pointRecordAccount,
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
          if (parseStringValue(setting['point_account_id']) != accountId) {
            continue;
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
    try {
      if (await _storesLocally) {
        await _localEditor.updateFields(
          owner: _localOwner!,
          resource: TableNames.pointRecordAccount,
          id: accountId,
          fields: {'master_graph_url': base64Encode(imageBytes)},
          notFoundMessage: 'point_account_not_found',
        );
        return imageBytes;
      }
      // 不管 Web / Mobile 都轉 base64
      // Mobile / Web 統一存 bytea (Uint8List)
      final result = await supabase
          .from(TableNames.pointRecordAccount)
          .update({'master_graph_url': base64Encode(imageBytes)})
          .eq(Fields.id, accountId)
          .eq(Fields.isValid, true)
          .select();

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
  Future<List<ModelPointRecordDetail>> fetchRecordsPage({
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
        resource: TableNames.pointRecordDetail,
      );
      final page = ModelLocalRecordPage.points(
        rows,
        accountId: accountId,
        type: type,
        from: dateFrom,
        to: dateTo,
        includeLatestFallback: includeLatestFallback,
        includeReservedRecords: includeReservedRecords,
      );
      return page.rows.map((detail) {
        return ModelPointRecordDetail(
          id: parseStringValue(detail[Fields.id]),
          accountId: parseStringValue(detail['account_id']),
          createdAt:
              tryParseDateTimeValue(detail[Fields.createdAt]) ?? DateTime.now(),
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
      }).toList();
    }
    final upperBound = recordDayUpperBound(dateTo);
    var query = supabase
        .from(TableNames.pointRecordDetail)
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
        resource: TableNames.pointRecordDetail,
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
          .from(TableNames.pointRecordDetail)
          .select()
          .eq('account_id', accountId)
          .ilike('type', type)
          .neq('primary_category', reservedRecordCategory)
          .order('date', ascending: false)
          .limit(1);
      result.addAll(List<Map<String, dynamic>>.from(fallback));
    }
    final totalRows = await supabase
        .from(TableNames.pointRecordAccount)
        .select('points')
        .eq(Fields.id, accountId)
        .limit(1);
    var points = totalRows.isEmpty
        ? 0
        : parseIntValue(totalRows.first['points']);
    if (owner != null && await _storesLocally) {
      final allLocal = await LocalDataStore.instance.list(
        owner: owner,
        resource: TableNames.pointRecordDetail,
      );
      points += allLocal
          .where(
            (row) =>
                parseStringValue(row['account_id']) == accountId &&
                parseStringValue(row['type']) == type,
          )
          .fold<int>(0, (sum, row) => sum + parseIntValue(row['value']));
    }
    final unique = uniqueRecordRowsNewestFirst(result);
    return unique.map((detail) {
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
    }).toList();
  }

  Future<bool> hasRecordsBefore({
    required String accountId,
    required String type,
    required DateTime before,
  }) async {
    if (await _storesLocally) {
      return _localHistory.hasRecordsBefore(
        owner: _localOwner!,
        resource: TableNames.pointRecordDetail,
        accountId: accountId,
        type: type,
        before: before,
      );
    }
    final rows = await supabase
        .from(TableNames.pointRecordDetail)
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
        resource: TableNames.pointRecordDetail,
        accountId: accountId,
        type: type,
        before: before,
      );
    }
    final rows = await supabase
        .from(TableNames.pointRecordDetail)
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

  Future<void> insertRecordsBatch({
    required String accountId,
    required String type,
    required List<PointRecordPreview> records,
  }) async {
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
      await supabase
          .from(TableNames.pointRecordDetail)
          .update({
            'value': newValue,
            'description': newDescription,
            'date': newDate.toUtc().toIso8601String(),
            'primary_category': newPrimaryCategory,
            'group': parseStringValue(newSecondaryCategory).trim(),
          })
          .eq(Fields.id, detailId);
    } catch (e, st) {
      logger.e('updatePointRecordDetail failed $e\n$st');
      rethrow;
    }
  }

  Future<void> deletePointRecordDetail({required String detailId}) async {
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
