// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/models/model_recommended_event.dart';
import 'package:life_pilot/utils/utils_common_function.dart';

Future<void> exportRecommendedEventsToExcel(
    BuildContext context, List<RecommendedEvent> events) async {
  final excel = Excel.createExcel();
  final sheet = excel['Sheet1'];
  final loc = AppLocalizations.of(context)!;

  sheet.appendRow([
    TextCellValue(loc.excel_column_header_activity_name),
    TextCellValue(loc.excel_column_header_keywords),
    TextCellValue(loc.excel_column_header_city),
    TextCellValue(loc.excel_column_header_location),
    TextCellValue(loc.excel_column_header_fee),
    TextCellValue(loc.excel_column_header_start_date),
    TextCellValue(loc.excel_column_header_start_time),
    TextCellValue(loc.excel_column_header_end_date),
    TextCellValue(loc.excel_column_header_end_time),
    TextCellValue(loc.excel_column_header_description),
    TextCellValue(loc.excel_column_header_sponsor),
  ]);

  for (final e in events) {
    sheet.appendRow([
      TextCellValue(e.name),
      TextCellValue(e.type),
      TextCellValue(e.city),
      TextCellValue(e.location),
      TextCellValue(e.fee),
      TextCellValue(_formatDate(e.startDate)),
      TextCellValue(_formatTime(context, e.startTime)),
      TextCellValue(_formatDate(e.endDate)),
      TextCellValue(_formatTime(context, e.endTime)),
      TextCellValue(e.description),
      TextCellValue(e.unit),
    ]);

    for (final sub in e.subRecommendedEvents) {
      sheet.appendRow([
        TextCellValue('  └ ${sub.name}'),
        TextCellValue(sub.type),
        TextCellValue(''),
        TextCellValue(sub.location),
        TextCellValue(sub.fee),
        TextCellValue(_formatDate(sub.startDate)),
        TextCellValue(_formatTime(context, sub.startTime)),
        TextCellValue(_formatDate(sub.endDate)),
        TextCellValue(_formatTime(context, sub.endTime)),
        TextCellValue(sub.description),
        TextCellValue(sub.unit),
      ]);
    }
  }

  final excelBytes = Uint8List.fromList(excel.encode()!);
  final filename =
      'events_${DateTime.now().millisecondsSinceEpoch}.xlsx';

  _downloadOnWeb(filename, excelBytes);
  showSnackBar(context, '${loc.downloaded}：$filename');
}

void _downloadOnWeb(String filename, Uint8List data) {
  final blob = html.Blob([data]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}

String _formatDate(DateTime? date) {
  return date != null
      ? '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'
      : '';
}

String _formatTime(BuildContext context, TimeOfDay? time) {
  return time != null ? time.format(context) : '';
}
