import 'dart:io' as io;
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/models/model_event.dart';
import 'package:life_pilot/utils/utils_common_function.dart';
import 'package:life_pilot/utils/utils_const.dart';
import 'package:path_provider/path_provider.dart';

Future<void> exportRecommendedEventsToExcel(BuildContext context, List<Event> events) async {
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
            TextCellValue(e.name), TextCellValue(e.type),
            TextCellValue(e.city), TextCellValue(e.location), TextCellValue(e.fee),
            TextCellValue(_formatDate(e.startDate)), TextCellValue(_formatTime(context, e.startTime)),
            TextCellValue(_formatDate(e.endDate)), TextCellValue(_formatTime(context, e.endTime)),
            TextCellValue(e.description), TextCellValue(e.unit),
        ]);

        for (final sub in e.subEvents) {
            sheet.appendRow([
                TextCellValue('  └ ${sub.name}'), TextCellValue(sub.type),
                TextCellValue(constEmpty), TextCellValue(sub.location), TextCellValue(sub.fee),
                TextCellValue(_formatDate(sub.startDate)), TextCellValue(_formatTime(context, sub.startTime)),
                TextCellValue(_formatDate(sub.endDate)), TextCellValue(_formatTime(context, sub.endTime)),
                TextCellValue(sub.description), TextCellValue(sub.unit),
            ]);
        }
    }

    final excelBytes = Uint8List.fromList(excel.encode()!);
    final filename = 'events_${DateTime.now().millisecondsSinceEpoch}.xlsx';

    try {
        final file = await _saveToFile(filename, excelBytes);
        showSnackBar(context, '${loc.export_success}：${file.path}');
    } catch (e) {
        showSnackBar(context, '${loc.export_failed}：$e');
    }
}

Future<io.File> _saveToFile(String filename, Uint8List bytes) async {
    io.Directory dir;

    if (io.Platform.isAndroid) {
        dir = io.Directory('/storage/emulated/0/Download');
    } else if (io.Platform.isWindows) {
        dir = io.Directory('${io.Platform.environment['USERPROFILE']}\\Downloads');
    } else if (io.Platform.isMacOS) {
        dir = io.Directory('${io.Platform.environment['HOME']}/Downloads');
    } else {
        dir = await getApplicationDocumentsDirectory(); 
    }

    final file = io.File('${dir.path}/$filename');
    await file.create(recursive: true);
    return file.writeAsBytes(bytes);
}

String _formatDate(DateTime? date) {
    return date != null
        ? '${date.year}-${date.month.toString().padLeft(2, constZero)}-${date.day.toString().padLeft(2, constZero)}'
        : constEmpty;
}

String _formatTime(BuildContext context, TimeOfDay? time) {
    return time != null ? time.format(context) : constEmpty;
}