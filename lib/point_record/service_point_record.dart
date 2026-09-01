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

class ServicePointRecord {
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
    final points = totalRows.isEmpty ? 0 : totalRows.first['points'] ?? 0;
    return result.map((detail) {
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
        points: points is int
            ? points
            : int.tryParse(points?.toString() ?? '0') ?? 0,
      );
    }).toList();
  }

  Future<bool> hasRecordsBefore({
    required String accountId,
    required String type,
    required DateTime before,
  }) async {
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
}
