import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/api.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/service/export/service_export_platform.dart';
import 'package:life_pilot/utils/value_parser.dart';

class ServicePersonalData {
  Future<String> export({
    required String email,
    required ServiceExportPlatform exporter,
    required AppLocalizations loc,
  }) async {
    final cloudRows = await _fetchAllCloudRows();
    final workbook = Excel.createExcel();
    final meta = workbook[loc.dataExportSummarySheet];
    workbook.delete('Sheet1');
    meta.appendRow([TextCellValue(loc.accountName), TextCellValue(email)]);
    meta.appendRow([
      TextCellValue(loc.description),
      TextCellValue(loc.dataExportIncludedPages),
    ]);
    _appendRowsByTable(workbook, cloudRows, loc);
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
      final tableName = parseStringValue(wrapper['table_name']);
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
      TableNames.calendarEvents => loc.personalEvent,
      TableNames.memoryTrace => loc.memoryTrace,
      TableNames.accountingAccount => loc.accountRecords,
      TableNames.accountingDetail => '${loc.accountRecords} ${loc.description}',
      TableNames.pointRecordAccount => loc.pointsRecord,
      TableNames.pointRecordDetail => '${loc.pointsRecord} ${loc.description}',
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
      TableNames.calendarEvents ||
      TableNames.memoryTrace ||
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
      TableNames.accountingAccount => [
        'account_name',
        'primary_currency',
        'amount',
      ],
      TableNames.accountingDetail => [
        'account_name',
        'date',
        'time',
        'description',
        'category',
        'secondary_category',
        'value',
        'currency',
      ],
      TableNames.pointRecordAccount => ['account_name', 'points'],
      TableNames.pointRecordDetail => [
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
        tableName == TableNames.accountingDetail ||
        tableName == TableNames.pointRecordDetail;
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
    return parseStringValue(value);
  }

  String _fieldValue(Map<String, dynamic> record, String key) {
    if (key == 'time' && record['time'] == null && record['date'] != null) {
      final raw = parseStringValue(record['date']);
      final separator = raw.indexOf('T');
      return separator < 0 ? '' : raw.substring(separator + 1).split('.').first;
    }
    if (key == 'date' && record['date'] != null) {
      return parseStringValue(record['date']).split('T').first;
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
      for (final row in grouped[TableNames.accountingAccount] ?? const [])
        if (row[Fields.id] != null)
          parseStringValue(row[Fields.id]): parseStringValue(
            row['name'] ?? row[Fields.account],
          ),
    };
    final pointAccountNames = <String, String>{
      for (final row in grouped[TableNames.pointRecordAccount] ?? const [])
        if (row[Fields.id] != null)
          parseStringValue(row[Fields.id]): parseStringValue(
            row['name'] ?? row[Fields.account],
          ),
    };
    final prepared = records.map((row) {
      final copy = Map<String, dynamic>.from(row);
      if (tableName == TableNames.accountingAccount) {
        copy['account_name'] = parseStringValue(
          copy['name'] ?? copy[Fields.account],
        );
        copy['primary_currency'] = parseStringValue(
          copy['main_currency'] ?? copy['currency'],
        );
        copy['amount'] = parseNumValue(copy['balance']);
      } else if (tableName == TableNames.pointRecordAccount) {
        copy['account_name'] = parseStringValue(
          copy['name'] ?? copy[Fields.account],
        );
      } else if (tableName == TableNames.accountingDetail) {
        copy['account_name'] =
            accountNames[parseStringValue(copy['account_id'])] ?? '';
        copy['category'] = _localizedCategory(copy['primary_category'], loc);
        copy['secondary_category'] = _localizedCategory(
          parseStringValue(copy['group'] ?? copy['secondary_category']),
          loc,
        );
        copy['description'] = parseStringValue(
          copy['description'] ?? copy['title'],
        );
      } else if (tableName == TableNames.pointRecordDetail) {
        copy['account_name'] =
            pointAccountNames[parseStringValue(copy['account_id'])] ?? '';
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
      if (tableName == TableNames.accountingAccount ||
          tableName == TableNames.pointRecordAccount) {
        return parseStringValue(a['account_name']).toLowerCase().compareTo(
          parseStringValue(b['account_name']).toLowerCase(),
        );
      }
      if (tableName.contains('detail')) {
        final account = parseStringValue(
          a['account_name'],
        ).compareTo(parseStringValue(b['account_name']));
        if (account != 0) return account;
      }
      final date = parseStringValue(
        a[dateKey],
      ).compareTo(parseStringValue(b[dateKey]));
      if (date != 0) return date;
      final time = parseStringValue(
        a['start_time'] ?? a['time'],
      ).compareTo(parseStringValue(b['start_time'] ?? b['time']));
      if (time != 0) return time;
      if (!tableName.contains('detail')) {
        final endDate =
            parseStringValue(
              a['end_date'],
              fallback: parseStringValue(a['start_date']),
            ).compareTo(
              parseStringValue(
                b['end_date'],
                fallback: parseStringValue(b['start_date']),
              ),
            );
        if (endDate != 0) return endDate;
        final endTime = parseStringValue(
          a['end_time'],
        ).compareTo(parseStringValue(b['end_time']));
        if (endTime != 0) return endTime;
        final city = parseStringValue(
          a['city'],
        ).compareTo(parseStringValue(b['city']));
        if (city != 0) return city;
        final location = parseStringValue(
          a['location'],
        ).compareTo(parseStringValue(b['location']));
        if (location != 0) return location;
        return parseStringValue(
          a['name'],
        ).compareTo(parseStringValue(b['name']));
      }
      return parseStringValue(
        a['description'],
      ).compareTo(parseStringValue(b['description']));
    });
    return prepared;
  }

  String _localizedCategory(Object? value, AppLocalizations loc) {
    final category = parseStringValue(value).trim();
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
