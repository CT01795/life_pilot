import 'dart:typed_data';
import 'package:csv/csv.dart';

import 'package:excel/excel.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/models/event/model_event_item.dart';
import 'package:life_pilot/models/event/model_event_base.dart';
import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/core/date_time.dart';
import 'package:life_pilot/services/event/service_event_public.dart';

class ServiceExportExcel {
  ServiceExportExcel();

  Uint8List buildExcelBytes(List<EventItem> events, AppLocalizations loc) {
    final excel = Excel.createExcel();
    final sheet = excel['Sheet1'];

    // Excel 標題列
    final headers = [
      loc.excelColumnHeaderActivityName,
      loc.excelColumnHeaderKeywords,
      loc.excelColumnHeaderCity,
      loc.excelColumnHeaderLocation,
      //loc.excelColumnHeaderFee,
      loc.excelColumnHeaderStartDate,
      loc.excelColumnHeaderStartTime,
      loc.excelColumnHeaderEndDate,
      loc.excelColumnHeaderEndTime,
      loc.excelColumnHeaderDescription,
      loc.excelColumnHeaderSponsor,
      loc.excelColumnHeaderAgeMin,
      loc.excelColumnHeaderAgeMax,
      loc.excelColumnHeaderIsFree,
      loc.excelColumnHeaderPriceMin,
      loc.excelColumnHeaderPriceMax,
      loc.excelColumnHeaderIsOutdoor,
      loc.excelColumnHeaderId,
      loc.excelColumnHeaderMasterUrl
    ];

    sheet.appendRow(headers.map(_textCell).toList());

    for (final e in events) {
      _appendEventRow(sheet: sheet, event: e, loc: loc);
      for (final sub in e.subEvents) {
        _appendEventRow(sheet: sheet, event: sub, indent: '  └ ', loc: loc);
      }
    }
    return Uint8List.fromList(excel.encode()!);
  }

  void _appendEventRow(
      {required Sheet sheet,
      required EventBase event,
      String indent = constEmpty,
      required AppLocalizations loc}) {
    final row = [
      _textCell('$indent${event.name}'),
      _textCell(event.type),
      _textCell(event.city),
      _textCell(event.location),
      //_textCell(event.fee),
      _textCell(event.startDate?.formatDateString() ?? constEmpty),
      _textCell(event.startTime?.formatTimeString() ?? constEmpty),
      _textCell(event.endDate?.formatDateString() ?? constEmpty),
      _textCell(event.endTime?.formatTimeString() ?? constEmpty),
      _textCell(event.description),
      _textCell(event.unit),
      _textCell(event.ageMin?.toString() ?? constEmpty),
      _textCell(event.ageMax?.toString() ?? constEmpty),
      _textCell(event.isFree == null ? constEmpty : ( event.isFree! ? loc.free: loc.pay)),
      _textCell(event.priceMin?.toString() ?? constEmpty),
      _textCell(event.priceMax?.toString() ?? constEmpty),
      _textCell(event.isOutdoor == null ? constEmpty : ( event.isOutdoor! ? loc.outdoor: loc.indoor)),
      _textCell(event.id),
      _textCell(event.masterUrl ?? constEmpty),
    ];
    sheet.appendRow(row);
  }

  TextCellValue _textCell(String value) => TextCellValue(value);

  List<EventItem> parseCsv(String csvText) {
    final rows = const CsvToListConverter().convert(csvText);
    if (rows.length <= 1) return [];

    List<EventItem> events = [];

    // 假設第 1 列是 header
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty || row.length <= 17) continue;
      events.add(EventItem(
        name: row[0]?.toString(),
        type: row[1]?.toString(),
        city: row[2]?.toString(),
        location: row[3]?.toString(),
        //fee: row[?]?.toString(),
        startDate: DateTime.tryParse(row[4]?.toString() ?? constEmpty),
        startTime: DateTimeParser.parseTime(row[5]?.toString() ?? constEmpty),
        endDate: DateTime.tryParse(row[6]?.toString() ?? constEmpty),
        endTime: DateTimeParser.parseTime(row[7]?.toString() ?? constEmpty),
        description: row[8]?.toString(),
        unit: row[9]?.toString(),
        ageMin: (row[10]?.toString() ?? constEmpty).trim().isNotEmpty ? num.parse(row[10]!.value!.toString().trim()) : null,
        ageMax: (row[11]?.toString() ?? constEmpty).trim().isNotEmpty ? num.parse(row[11]!.value!.toString().trim()) : null,
        isFree: (row[12]?.toString() ?? constEmpty).trim().isNotEmpty ? row[12]?.toString().contains("免費") : null,
        priceMin: (row[13]?.toString() ?? constEmpty).trim().isNotEmpty ? num.parse(row[13]!.value!.toString().trim()) : null,
        priceMax: (row[14]?.toString() ?? constEmpty).trim().isNotEmpty ? num.parse(row[14]!.value!.toString().trim()) : null,
        isOutdoor: (row[15]?.toString() ?? constEmpty).trim().isNotEmpty ? row[15]?.toString().contains("戶外") : null,
        id: row[16]?.toString(),
        masterUrl: row[17]?.toString(),
      ));
    }
    return events;
  }
}
