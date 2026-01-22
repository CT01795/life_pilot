import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/models/event/model_event_item.dart';
import 'package:life_pilot/models/event/model_event_base.dart';
import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/core/date_time.dart';

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
      loc.excelColumnHeaderIsOutdoor
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
    ];
    sheet.appendRow(row);
  }

  TextCellValue _textCell(String value) => TextCellValue(value);
}
