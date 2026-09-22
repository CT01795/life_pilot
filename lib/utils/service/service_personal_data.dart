import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:life_pilot/utils/api.dart';
import 'package:life_pilot/utils/service/export/service_export_platform.dart';

class ServicePersonalData {
  Future<String> export({
    required String email,
    required ServiceExportPlatform exporter,
    required AppLocalizations loc,
  }) async {
    final cloudRows = await _fetchAllCloudRows();
    final localRows = await LocalDataStore.instance.exportAllRecords(
      owner: email,
    );
    final workbook = Excel.createExcel();
    final meta = workbook[loc.dataExportSummarySheet];
    workbook.delete('Sheet1');
    meta.appendRow([TextCellValue(loc.accountName), TextCellValue(email)]);
    meta.appendRow([
      TextCellValue(loc.description),
      TextCellValue(loc.dataExportIncludedPages),
    ]);
    _appendRowsByTable(workbook, [...cloudRows, ...localRows], loc);
    final bytes = Uint8List.fromList(workbook.encode()!);
    final stamp = DateTime.now().toLocal().toIso8601String().split('T').first;
    return exporter.exportFile('life_pilot_data_$stamp.xlsx', bytes);
  }

  Future<List<Map<String, dynamic>>> _fetchAllCloudRows() async {
    const pageSize = 1000;
    final result = <Map<String, dynamic>>[];
    var offset = 0;
    while (true) {
      final page = await supabase
          .rpc('export_my_cloud_data_for_local')
          .range(offset, offset + pageSize - 1);
      final rows = (page as List<dynamic>)
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
      result.addAll(rows);
      if (rows.length < pageSize) break;
      offset += pageSize;
    }
    return result;
  }

  void _appendRowsByTable(Excel workbook, Object? rows, AppLocalizations loc) {
    if (rows is! List) return;
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final item in rows) {
      if (item is! Map) continue;
      final wrapper = Map<String, dynamic>.from(item);
      final tableName = wrapper['table_name']?.toString() ?? '';
      final value = wrapper.containsKey('record') ? wrapper['record'] : wrapper;
      if (tableName.isEmpty) continue;
      if (value is Map) {
        grouped
            .putIfAbsent(tableName, () => [])
            .add(Map<String, dynamic>.from(value));
      } else if (value is List) {
        for (final item in value) {
          if (item is Map) {
            grouped
                .putIfAbsent(tableName, () => [])
                .add(Map<String, dynamic>.from(item));
          }
        }
      }
    }
    for (final entry in grouped.entries) {
      final records = _prepareRecords(entry.key, entry.value, grouped, loc);
      final fields = _fieldsForTable(entry.key, records, loc);
      if (fields.isEmpty) continue;
      final name = _sheetName(entry.key, loc);
      final sheet = workbook[name];
      sheet.appendRow(
        fields.map((field) => TextCellValue(field.label)).toList(),
      );
      for (final record in records) {
        sheet.appendRow(
          fields
              .map((field) => TextCellValue(_fieldValue(record, field.key)))
              .toList(),
        );
      }
    }
  }

  String _sheetName(String tableName, AppLocalizations loc) {
    final title = switch (tableName) {
      'calendar_events' => loc.personalEvent,
      'memory_trace' => loc.memoryTrace,
      'accounting_account' => loc.accountRecords,
      'accounting_detail' => '${loc.accountRecords} ${loc.description}',
      'point_record_account' => loc.pointsRecord,
      'point_record_detail' => '${loc.pointsRecord} ${loc.description}',
      _ => tableName,
    };
    return title.length > 31 ? title.substring(0, 31) : title;
  }

  List<_ExportField> _fieldsForTable(
    String tableName,
    List<Map<String, dynamic>> records,
    AppLocalizations loc,
  ) {
    final labels = <String, String>{
      'name': tableName.endsWith('_account')
          ? loc.accountName
          : loc.activityName,
      'account_name': loc.accountName,
      'city': loc.city,
      'location': loc.location,
      'start_date': loc.startDate,
      'end_date': loc.endDate,
      'start_time': loc.startTime,
      'end_time': loc.endTime,
      'description': loc.description,
      'date': loc.startDate,
      'time': loc.startTime,
      'category': loc.categoryLabel,
      'secondary_category': loc.secondaryCategoryLabel,
      'value': loc.amountLabel,
      'currency': loc.currencyLabel,
      'primary_currency': loc.currencyLabel,
      'amount': loc.totalAmount,
      'points': loc.pointsUnit,
    };
    final order = switch (tableName) {
      'calendar_events' ||
      'memory_trace' ||
      'recommended_events' ||
      'recommended_attractions' => [
        'name',
        'city',
        'location',
        'start_date',
        'end_date',
        'start_time',
        'end_time',
        'description',
      ],
      'accounting_account' => ['account_name', 'primary_currency', 'amount'],
      'accounting_detail' => [
        'account_name',
        'date',
        'time',
        'description',
        'category',
        'secondary_category',
        'value',
        'currency',
      ],
      'point_record_account' => ['account_name', 'points'],
      'point_record_detail' => [
        'account_name',
        'date',
        'time',
        'description',
        'category',
        'secondary_category',
        'points',
      ],
      _ => const <String>[],
    };
    final available = <String>{for (final record in records) ...record.keys};
    final alwaysIncludeCategory =
        tableName == 'accounting_detail' || tableName == 'point_record_detail';
    return order
        .where(
          (key) =>
              labels.containsKey(key) &&
              (available.contains(key) ||
                  (key == 'category' && alwaysIncludeCategory) ||
                  (key == 'secondary_category' && alwaysIncludeCategory) ||
                  (key == 'time' && available.contains('date'))),
        )
        .map((key) => _ExportField(key, labels[key]!))
        .toList(growable: false);
  }

  String _formatValue(Object? value) {
    if (value == null) return '';
    if (value is num) return NumberFormat('#,##0.####').format(value);
    if (value is Map || value is List) return jsonEncode(value);
    return value.toString();
  }

  String _fieldValue(Map<String, dynamic> record, String key) {
    if (key == 'time' && record['time'] == null && record['date'] != null) {
      final raw = record['date']?.toString() ?? '';
      final separator = raw.indexOf('T');
      return separator < 0 ? '' : raw.substring(separator + 1).split('.').first;
    }
    if (key == 'date' && record['date'] != null) {
      return record['date'].toString().split('T').first;
    }
    return _formatValue(record[key]);
  }

  List<Map<String, dynamic>> _prepareRecords(
    String tableName,
    List<Map<String, dynamic>> records,
    Map<String, List<Map<String, dynamic>>> grouped,
    AppLocalizations loc,
  ) {
    final accountNames = <String, String>{
      for (final row in grouped['accounting_account'] ?? const [])
        if (row['id'] != null)
          row['id'].toString(): (row['name'] ?? row['account'] ?? '')
              .toString(),
    };
    final pointAccountNames = <String, String>{
      for (final row in grouped['point_record_account'] ?? const [])
        if (row['id'] != null)
          row['id'].toString(): (row['name'] ?? row['account'] ?? '')
              .toString(),
    };
    final prepared = records.map((row) {
      final copy = Map<String, dynamic>.from(row);
      if (tableName == 'accounting_account') {
        copy['account_name'] = (copy['name'] ?? copy['account'] ?? '')
            .toString();
        copy['primary_currency'] =
            copy['main_currency'] ?? copy['currency'] ?? '';
        copy['amount'] = copy['balance'] ?? 0;
      } else if (tableName == 'point_record_account') {
        copy['account_name'] = (copy['name'] ?? copy['account'] ?? '')
            .toString();
      } else if (tableName == 'accounting_detail') {
        copy['account_name'] =
            accountNames[copy['account_id']?.toString() ?? ''] ?? '';
        copy['category'] = _localizedCategory(copy['primary_category'], loc);
        copy['secondary_category'] = _localizedCategory(
          copy['group'] ?? copy['secondary_category'],
          loc,
        );
        copy['description'] = copy['description'] ?? copy['title'] ?? '';
      } else if (tableName == 'point_record_detail') {
        copy['account_name'] =
            pointAccountNames[copy['account_id']?.toString() ?? ''] ?? '';
        copy['category'] = _localizedCategory(copy['primary_category'], loc);
        copy['secondary_category'] = _localizedCategory(
          copy['group'] ?? copy['secondary_category'],
          loc,
        );
        copy['description'] = copy['description'] ?? copy['title'] ?? '';
        copy['points'] = copy['points'] ?? copy['value'] ?? 0;
      }
      return copy;
    }).toList();
    final dateKey = tableName.contains('detail') ? 'date' : 'start_date';
    prepared.sort((a, b) {
      if (tableName == 'accounting_account' ||
          tableName == 'point_record_account') {
        return (a['account_name']?.toString().toLowerCase() ?? '').compareTo(
          b['account_name']?.toString().toLowerCase() ?? '',
        );
      }
      if (tableName.contains('detail')) {
        final account = (a['account_name']?.toString() ?? '').compareTo(
          b['account_name']?.toString() ?? '',
        );
        if (account != 0) return account;
      }
      final date = (a[dateKey]?.toString() ?? '').compareTo(
        b[dateKey]?.toString() ?? '',
      );
      if (date != 0) return date;
      final time = (a['start_time'] ?? a['time'] ?? '').toString().compareTo(
        (b['start_time'] ?? b['time'] ?? '').toString(),
      );
      if (time != 0) return time;
      if (!tableName.contains('detail')) {
        final endDate =
            (a['end_date']?.toString() ?? a['start_date']?.toString() ?? '')
                .compareTo(
                  (b['end_date']?.toString() ??
                      b['start_date']?.toString() ??
                      ''),
                );
        if (endDate != 0) return endDate;
        final endTime = (a['end_time']?.toString() ?? '').compareTo(
          b['end_time']?.toString() ?? '',
        );
        if (endTime != 0) return endTime;
        final city = (a['city']?.toString() ?? '').compareTo(
          b['city']?.toString() ?? '',
        );
        if (city != 0) return city;
        final location = (a['location']?.toString() ?? '').compareTo(
          b['location']?.toString() ?? '',
        );
        if (location != 0) return location;
        return (a['name']?.toString() ?? '').compareTo(
          b['name']?.toString() ?? '',
        );
      }
      return (a['description']?.toString() ?? '').compareTo(
        b['description']?.toString() ?? '',
      );
    });
    return prepared;
  }

  String _localizedCategory(Object? value, AppLocalizations loc) {
    final category = value?.toString().trim() ?? '';
    return switch (category.toLowerCase()) {
      'uncategorized' ||
      '未分類' ||
      '未分类' ||
      '미분류' => loc.recordCategoryUncategorized,
      'reserved' ||
      '保留項' ||
      '保留项' ||
      '保持項目' ||
      '보존 항목' => loc.recordCategoryReserved,
      'food' || '食' || '食費' || '食事' || '식' || '식비' => loc.recordCategoryFood,
      'clothing' || '衣' || '衣類' || '의' || '의류' => loc.recordCategoryClothing,
      'housing' ||
      '住' ||
      '住居' ||
      '住宅' ||
      '주' ||
      '주거' => loc.recordCategoryHousing,
      'transportation' ||
      '行' ||
      '交通' ||
      '행' ||
      '교통' => loc.recordCategoryTransportation,
      'education' || '育' || '教育' || '육' || '교육' => loc.recordCategoryEducation,
      'entertainment' ||
      '樂' ||
      '乐' ||
      '楽' ||
      '娯楽' ||
      '오락' ||
      '락' ||
      '여가' => loc.recordCategoryEntertainment,
      'virtue' || '德' || '徳' || '徳育' || '덕' || '덕성' => loc.recordCategoryVirtue,
      'intelligence' ||
      '智' ||
      '知育' ||
      '지' ||
      '지성' => loc.recordCategoryIntelligence,
      'fitness' ||
      '體' ||
      '体' ||
      '体育' ||
      '체' ||
      '체력' => loc.recordCategoryFitness,
      'social' ||
      '群' ||
      '群育' ||
      '사교' ||
      '군' ||
      '사회성' => loc.recordCategorySocial,
      'arts' || '美' || '美育' || '예술' || '미' => loc.recordCategoryArts,
      _ => category,
    };
  }

  Future<void> requestAccountDeletion() async {
    final statusRows =
        await supabase.rpc('get_my_subscription_status') as List<dynamic>;
    final storagePlan = statusRows.isEmpty
        ? 'cloud'
        : (statusRows.first as Map)['storage_plan']?.toString() ?? 'cloud';
    if (storagePlan == 'local') {
      throw StateError('cloud_deletion_request_only');
    }
    await supabase.rpc('request_account_deletion');
  }

  Future<Map<String, dynamic>?> fetchMyAccountDeletionRequest() async {
    final rows =
        await supabase.rpc('get_my_account_deletion_request') as List<dynamic>;
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first as Map);
  }

  Future<void> requestAccountDeletionCancellation() async {
    await supabase.rpc('cancel_account_deletion_request');
  }

  Future<List<Map<String, dynamic>>> fetchAccountDeletionRequests() async {
    final rows = await supabase.rpc('admin_list_account_deletion_requests');
    return (rows as List<dynamic>)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
  }

  Future<void> approveAccountDeletion(String requestId) async {
    await supabase.rpc(
      'admin_delete_account_and_data',
      params: {'p_request_id': requestId},
    );
  }

  Future<void> confirmAccountDeletionCancellation(String requestId) async {
    await supabase.rpc(
      'admin_confirm_account_deletion_cancellation',
      params: {'p_request_id': requestId},
    );
  }
}

class _ExportField {
  const _ExportField(this.key, this.label);

  final String key;
  final String label;
}
