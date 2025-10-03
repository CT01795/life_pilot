import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/models/model_event.dart';
import 'package:life_pilot/utils/core/utils_const.dart';

Uint8List buildExcelBytes(
    {required List<Event> events, required AppLocalizations loc}) {
  final excel = Excel.createExcel();
  final sheet = excel['Sheet1'];

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
    appendEventRow(sheet: sheet, event: e);
    for (final sub in e.subEvents) {
      appendEventRow(sheet: sheet, event: sub, indent: '  └ ');
    }
  }

  return Uint8List.fromList(excel.encode()!);
}

void appendEventRow({required Sheet sheet, required var event,
  String indent = constEmpty}) 
{
  sheet.appendRow([
    TextCellValue('$indent${event.name}'),
    TextCellValue(event.type),
    TextCellValue(event.city ?? constEmpty),
    TextCellValue(event.location ?? constEmpty),
    TextCellValue(event.fee ?? constEmpty),
    TextCellValue(event.startDate?.formatDateString()),
    TextCellValue(event.startTime?.formatTimeString() ?? constEmpty),
    TextCellValue(event.endDate?.formatDateString()),
    TextCellValue(event.endTime?.formatTimeString() ?? constEmpty),
    TextCellValue(event.description ?? constEmpty),
    TextCellValue(event.unit ?? constEmpty),
  ]);
}
