import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:life_pilot/point_record/model_point_record_account.dart';
import 'package:life_pilot/point_record/model_point_record_detail.dart';
import 'package:life_pilot/point_record/model_point_record_preview.dart';
import 'package:life_pilot/utils/api.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/enum.dart';
import 'package:life_pilot/utils/graph.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:uuid/uuid.dart';
import 'package:life_pilot/local_storage/local_data_store.dart';

class ServicePointRecord {
  String? get _localOwner => supabase.auth.currentUser?.email?.toLowerCase();

  Future<bool> get _storesLocally async {
    final owner = _localOwner;
    if (owner == null) return false;
    return await LocalDataStore.instance.preferredLocation(owner) ==
        DataStorageLocation.local;
  }

  String currentTable = TableNames.pointRecordAccount;
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

  Future<ModelPointRecordAccount?> findAccountByEventId(
      {required String eventId, required String user}) async {
    try {
      if (await _storesLocally) {
        final rows = await LocalDataStore.instance
            .list(owner: _localOwner!, resource: TableNames.pointRecordAccount);
        final response = rows
            .where((row) =>
                row[Fields.id]?.toString() == eventId &&
                row[Fields.isValid] == true)
            .firstOrNull;
        if (response == null) return null;
        return ModelPointRecordAccount(
            id: response[Fields.id],
            accountName: response[Fields.account],
            category: response['category'],
            masterGraphUrl: parseMasterGraph(response['master_graph_url']),
            points: (response['points'] as num?)?.toInt() ?? 0);
      }
      final response = await supabase
          .from(currentTable)
          .select()
          .eq(Fields.id, eventId)
          .eq(Fields.createdBy, user)
          .eq(Fields.isValid, true)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      Uint8List? bytes;
      if (response['master_graph_url'] != null) {
        bytes = await compute<String?, Uint8List?>(
          decodeBase64InIsolate,
          response['master_graph_url'],
        );
      }

      return ModelPointRecordAccount(
        id: response[Fields.id],
        accountName: response[Fields.account],
        category: response['category'],
        masterGraphUrl: bytes,
        points: (response['points'] ?? 0).toInt(),
      );
    } on Exception catch (exception) {
      logger.e(exception);
      return null;
    }
  }

  Future<List<ModelPointRecordAccount>> fetchAccounts({
    required String user,
    String? category, // null = all categories
    int? projectLimit,
    bool includeGraph = true,
  }) async {
    try {
      if (await _storesLocally) {
        var rows = await LocalDataStore.instance
            .list(owner: _localOwner!, resource: TableNames.pointRecordAccount);
        final details = await LocalDataStore.instance
            .list(owner: _localOwner!, resource: TableNames.pointRecordDetail);
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
            .map((e) => ModelPointRecordAccount(
                id: e[Fields.id],
                accountName: e[Fields.account],
                category: e['category'],
                masterGraphUrl: includeGraph
                    ? parseMasterGraph(e['master_graph_url'])
                    : null,
                points: details
                    .where((d) =>
                        d['account_id']?.toString() == e[Fields.id]?.toString())
                    .fold<int>(
                        0,
                        (sum, d) =>
                            sum +
                            (int.tryParse(d['value']?.toString() ?? '0') ??
                                0))))
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
      return Future.wait(list.map((e) async {
        final graph = e['master_graph_url'];
        final bytes = graph == null
            ? null
            : await compute<String?, Uint8List?>(
                decodeBase64InIsolate,
                graph,
              );
        return ModelPointRecordAccount(
          id: e[Fields.id],
          accountName: e[Fields.account],
          category: e['category'],
          masterGraphUrl: bytes,
          points: (e['points'] ?? 0).toInt(),
        );
      }));
    } on Exception catch (exception) {
      logger.e(exception);
      return [];
    }
  }

  Future<ModelPointRecordAccount> createAccount(
      {required String name,
      required String user,
      required String? currency,
      required String category,
      String? eventId}) async {
    try {
      if (await _storesLocally) {
        final id = eventId ?? const Uuid().v4();
        final now = DateTime.now().toUtc().toIso8601String();
        final existing = (await LocalDataStore.instance.list(
                owner: _localOwner!, resource: TableNames.pointRecordAccount))
            .any((r) =>
                r[Fields.account]?.toString().toLowerCase() ==
                    name.toLowerCase() &&
                r['category'] == category &&
                r[Fields.isValid] == true);
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
              Fields.createdAt: now
            });
        return ModelPointRecordAccount(
            id: id,
            accountName: name,
            category: category,
            masterGraphUrl: null,
            points: 0);
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
        points: (response['points'] ?? 0).toInt(),
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
          resource: TableNames.pointRecordAccount,
          id: accountId)) {
        final rows = await LocalDataStore.instance
            .list(owner: _localOwner!, resource: TableNames.pointRecordAccount);
        final row =
            rows.firstWhere((r) => r[Fields.id]?.toString() == accountId);
        await LocalDataStore.instance.put(
            owner: _localOwner!,
            resource: TableNames.pointRecordAccount,
            id: accountId,
            data: {...row, Fields.isValid: false},
            syncState: LocalSyncState.modifiedLocally);
        return;
      }
      final result = await supabase
          .from(TableNames.pointRecordAccount)
          .update({
            Fields.isValid: false,
          })
          .eq(Fields.id, accountId)
          .select();

      if (result.isEmpty) {
        throw Exception("account not found");
      }

      await supabase.from(TableNames.dashboardSetting).update({
        'point_account_id': null,
        'point_account_name': null,
      }).eq('point_account_id', accountId);
    } catch (e, stacktrace) {
      logger.e(
        "deleteAccount error",
        error: e,
        stackTrace: stacktrace,
      );
      rethrow;
    }
  }

  Future<Uint8List> uploadAccountImageBytesDirect(
      String accountId, Uint8List imageBytes) async {
    try {
      if (await LocalDataStore.instance.contains(
          owner: _localOwner ?? '',
          resource: TableNames.pointRecordAccount,
          id: accountId)) {
        final rows = await LocalDataStore.instance
            .list(owner: _localOwner!, resource: TableNames.pointRecordAccount);
        final row =
            rows.firstWhere((r) => r[Fields.id]?.toString() == accountId);
        await LocalDataStore.instance.put(
            owner: _localOwner!,
            resource: TableNames.pointRecordAccount,
            id: accountId,
            data: {...row, 'master_graph_url': base64Encode(imageBytes)},
            syncState: LocalSyncState.modifiedLocally);
        return imageBytes;
      }
      // 不管 Web / Mobile 都轉 base64
      // Mobile / Web 統一存 bytea (Uint8List)
      final result = await supabase
          .from(TableNames.pointRecordAccount)
          .update({
            'master_graph_url': base64Encode(imageBytes),
          })
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
      final upperBound = DateTime(dateTo.year, dateTo.month, dateTo.day + 1);
      final rows = await LocalDataStore.instance.list(
        owner: _localOwner!,
        resource: TableNames.pointRecordDetail,
      );
      final accountRows = rows.where((row) =>
          row['account_id']?.toString() == accountId &&
          row['type']?.toString().toLowerCase() == type.toLowerCase());
      final points = accountRows.fold<int>(
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
      return filtered.map((detail) {
        return ModelPointRecordDetail(
          id: detail[Fields.id]?.toString() ?? '',
          accountId: detail['account_id']?.toString() ?? '',
          createdAt: DateTime.tryParse(
                detail[Fields.createdAt]?.toString() ?? '',
              ) ??
              DateTime.now(),
          date: DateTime.tryParse(detail['date']?.toString() ?? '') ??
              DateTime.now(),
          primaryCategory:
              detail['primary_category']?.toString() ?? 'uncategorized',
          secondaryCategory: detail['group']?.toString(),
          description: detail['description']?.toString() ?? '',
          type: detail['type']?.toString() ?? '',
          value: int.tryParse(detail['value']?.toString() ?? '0') ?? 0,
          points: points,
        );
      }).toList();
    }
    final upperBound = DateTime(dateTo.year, dateTo.month, dateTo.day + 1);
    var query = supabase
        .from(TableNames.pointRecordDetail)
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
        resource: TableNames.pointRecordDetail,
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
          .from(TableNames.pointRecordDetail)
          .select()
          .eq('account_id', accountId)
          .ilike('type', type)
          .neq('primary_category', 'reserved')
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
        : int.tryParse(totalRows.first['points']?.toString() ?? '0') ?? 0;
    if (owner != null && await _storesLocally) {
      final allLocal = await LocalDataStore.instance.list(
        owner: owner,
        resource: TableNames.pointRecordDetail,
      );
      points += allLocal
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
    return unique.map((detail) {
      return ModelPointRecordDetail(
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
      final rows = await LocalDataStore.instance.list(
        owner: _localOwner!,
        resource: TableNames.pointRecordDetail,
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
        .from(TableNames.pointRecordDetail)
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
        resource: TableNames.pointRecordDetail,
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
        .from(TableNames.pointRecordDetail)
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

  Future<void> insertRecordsBatch(
      {required String accountId,
      required String type,
      required List<PointRecordPreview> records}) async {
    try {
      if (await _storesLocally) {
        final owner = _localOwner!;
        final now = DateTime.now();
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
              'group': record.secondaryCategory?.trim() ?? '',
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
              .map((r) => {
                    'description': r.description,
                    'value': r.value,
                    'primary_category': r.primaryCategory,
                    'group': r.secondaryCategory?.trim() ?? '',
                  })
              .toList(),
        },
      );
    } catch (e, st) {
      logger.e(
        'insertRecordsBatch failed',
        error: e,
        stackTrace: st,
      );
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
      if (owner != null &&
          await LocalDataStore.instance.contains(
            owner: owner,
            resource: TableNames.pointRecordDetail,
            id: detailId,
          )) {
        final rows = await LocalDataStore.instance.list(
          owner: owner,
          resource: TableNames.pointRecordDetail,
        );
        final row = rows.firstWhere((item) => item[Fields.id] == detailId);
        await LocalDataStore.instance.put(
          owner: owner,
          resource: TableNames.pointRecordDetail,
          id: detailId,
          data: {
            ...row,
            'value': newValue,
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
        'update_point_record_detail',
        params: {
          'p_detail_id': detailId,
          'p_new_value': newValue,
          'p_new_description': newDescription,
          'p_new_date': newDate.toUtc().toIso8601String(),
          'p_new_primary_category': newPrimaryCategory,
          'p_new_group': newSecondaryCategory?.trim() ?? '',
        },
      );
    } catch (e, st) {
      logger.e('updatePointRecordDetail failed $e\n$st');
      rethrow;
    }
  }

  Future<void> deletePointRecordDetail({required String detailId}) async {
    final owner = _localOwner;
    if (owner != null &&
        await LocalDataStore.instance.contains(
          owner: owner,
          resource: TableNames.pointRecordDetail,
          id: detailId,
        )) {
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
