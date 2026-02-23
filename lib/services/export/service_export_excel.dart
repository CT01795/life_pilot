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
      _textCell(event.isFree == null
          ? constEmpty
          : (event.isFree! ? loc.free : loc.pay)),
      _textCell(event.priceMin?.toString() ?? constEmpty),
      _textCell(event.priceMax?.toString() ?? constEmpty),
      _textCell(event.isOutdoor == null
          ? constEmpty
          : (event.isOutdoor! ? loc.outdoor : loc.indoor)),
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
    final headerRow = rows[0];
    Map<String, int> colsToDetail = {};
    for (int i = 0; i < headerRow.length; i++) {
      final tmp = headerRow[i].toString();
      if (tmp.contains("活動名稱")) {
        colsToDetail["name"] = i;
      } else if (tmp.contains("關鍵字")) {
        colsToDetail["type"] = i;
      } else if (tmp.contains("縣市")) {
        colsToDetail["city"] = i;
      } else if (tmp.contains("地點")) {
        colsToDetail["location"] = i;
      } else if (tmp.contains("開始日期")) {
        colsToDetail["startDate"] = i;
      } else if (tmp.contains("開始時間")) {
        colsToDetail["startTime"] = i;
      } else if (tmp.contains("結束日期")) {
        colsToDetail["endDate"] = i;
      } else if (tmp.contains("結束時間")) {
        colsToDetail["endTime"] = i;
      } else if (tmp.contains("描述")) {
        colsToDetail["description"] = i;
      } else if (tmp.contains("相關單位")) {
        colsToDetail["unit"] = i;
      } else if (tmp.contains("最低年齡")) {
        colsToDetail["ageMin"] = i;
      } else if (tmp.contains("最大年齡")) {
        colsToDetail["ageMax"] = i;
      } else if (tmp.contains("免費")) {
        colsToDetail["isFree"] = i;
      } else if (tmp.contains("最低價格")) {
        colsToDetail["priceMin"] = i;
      } else if (tmp.contains("最高價格")) {
        colsToDetail["priceMax"] = i;
      } else if (tmp.contains("戶外")) {
        colsToDetail["isOutdoor"] = i;
      } else if (tmp.contains("活動 id")) {
        colsToDetail["id"] = i;
      } else if (tmp.contains("活動網址")) {
        colsToDetail["masterUrl"] = i;
      }
    }
    // 假設第 1 列是 header
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty || row.length <= 17) continue;
      events.add(EventItem(
          name: row[colsToDetail["name"] ?? 99]?.toString(),
          type: row[colsToDetail["type"] ?? 99]?.toString(),
          city: row[colsToDetail["city"] ?? 99]?.toString(),
          location: row[colsToDetail["location"] ?? 99]?.toString(),
          //fee: row[?]?.toString(),
          startDate: DateTime.tryParse(
              row[colsToDetail["startDate"] ?? 99]?.toString() ?? constEmpty),
          startTime: DateTimeParser.parseTime(
              row[colsToDetail["startTime"] ?? 99]?.toString() ?? constEmpty),
          endDate: DateTime.tryParse(
              row[colsToDetail["endDate"] ?? 99]?.toString() ?? constEmpty),
          endTime: DateTimeParser.parseTime(
              row[colsToDetail["endTime"] ?? 99]?.toString() ?? constEmpty),
          description: row[colsToDetail["description"] ?? 99]?.toString(),
          unit: row[colsToDetail["unit"] ?? 99]?.toString(),
          ageMin: (row[colsToDetail["ageMin"] ?? 99]?.toString() ?? constEmpty).trim().isNotEmpty
              ? num.parse(
                  row[colsToDetail["ageMin"] ?? 99]!.value!.toString().trim())
              : null,
          ageMax: (row[colsToDetail["ageMax"] ?? 99]?.toString() ?? constEmpty).trim().isNotEmpty
              ? num.parse(
                  row[colsToDetail["ageMax"] ?? 99]!.value!.toString().trim())
              : null,
          isFree:
              (row[colsToDetail["isFree"] ?? 99]?.toString() ?? constEmpty).trim().isNotEmpty
                  ? row[colsToDetail["isFree"] ?? 99]?.toString().contains("免費")
                  : null,
          priceMin: (row[colsToDetail["priceMin"] ?? 99]?.toString() ?? constEmpty).trim().isNotEmpty
              ? num.parse(row[colsToDetail["priceMin"] ?? 99]!.value!.toString().trim())
              : null,
          priceMax: (row[colsToDetail["priceMax"] ?? 99]?.toString() ?? constEmpty).trim().isNotEmpty ? num.parse(row[colsToDetail["priceMax"] ?? 99]!.value!.toString().trim()) : null,
          isOutdoor: (row[colsToDetail["isOutdoor"] ?? 99]?.toString() ?? constEmpty).trim().isNotEmpty ? row[colsToDetail["isOutdoor"] ?? 99]?.toString().contains("戶外") : null,
          id: row[colsToDetail["id"] ?? 99]?.toString(),
          masterUrl: row[colsToDetail["masterUrl"] ?? 99]?.toString(),
          subEvents: []));
    }
    return events;
  }

  List<EventItem> parseExcel(Sheet sheet) {
    if (sheet.rows.length <= 1) return [];

    List<EventItem> events = [];
    final headerRow = sheet.rows[0];
    Map<String, int> colsToDetail = {};
    for (int i = 0; i < headerRow.length; i++) {
      final tmp = headerRow[i]?.value?.toString();
      if (tmp == null) {
        continue;
      }else if (tmp.contains("活動名稱")) {
        colsToDetail["name"] = i;
      } else if (tmp.contains("關鍵字")) {
        colsToDetail["type"] = i;
      } else if (tmp.contains("縣市")) {
        colsToDetail["city"] = i;
      } else if (tmp.contains("地點")) {
        colsToDetail["location"] = i;
      } else if (tmp.contains("開始日期")) {
        colsToDetail["startDate"] = i;
      } else if (tmp.contains("開始時間")) {
        colsToDetail["startTime"] = i;
      } else if (tmp.contains("結束日期")) {
        colsToDetail["endDate"] = i;
      } else if (tmp.contains("結束時間")) {
        colsToDetail["endTime"] = i;
      } else if (tmp.contains("描述")) {
        colsToDetail["description"] = i;
      } else if (tmp.contains("相關單位")) {
        colsToDetail["unit"] = i;
      } else if (tmp.contains("最低年齡")) {
        colsToDetail["ageMin"] = i;
      } else if (tmp.contains("最大年齡")) {
        colsToDetail["ageMax"] = i;
      } else if (tmp.contains("免費")) {
        colsToDetail["isFree"] = i;
      } else if (tmp.contains("最低價格")) {
        colsToDetail["priceMin"] = i;
      } else if (tmp.contains("最高價格")) {
        colsToDetail["priceMax"] = i;
      } else if (tmp.contains("戶外")) {
        colsToDetail["isOutdoor"] = i;
      } else if (tmp.contains("活動 id")) {
        colsToDetail["id"] = i;
      } else if (tmp.contains("活動網址")) {
        colsToDetail["masterUrl"] = i;
      }
    }
    // 假設第 1 列是 header
    for (int i = 1; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      if (row.isEmpty || row.length <= 17) continue;
      events.add(EventItem(
          name: row[colsToDetail["name"] ?? 99]?.value?.toString(),
          type: row[colsToDetail["type"] ?? 99]?.value?.toString(),
          city: row[colsToDetail["city"] ?? 99]?.value?.toString(),
          location: row[colsToDetail["location"] ?? 99]?.value?.toString(),
          //fee: row[?]?.value?.toString(),
          startDate: DateTime.tryParse(
              row[colsToDetail["startDate"] ?? 99]?.value?.toString() ?? constEmpty),
          startTime: DateTimeParser.parseTime(
              row[colsToDetail["startTime"] ?? 99]?.value?.toString() ?? constEmpty),
          endDate: DateTime.tryParse(
              row[colsToDetail["endDate"] ?? 99]?.value?.toString() ?? constEmpty),
          endTime: DateTimeParser.parseTime(
              row[colsToDetail["endTime"] ?? 99]?.value?.toString() ?? constEmpty),
          description: row[colsToDetail["description"] ?? 99]?.value?.toString(),
          unit: row[colsToDetail["unit"] ?? 99]?.value?.toString(),
          ageMin: (row[colsToDetail["ageMin"] ?? 99]?.value?.toString() ?? constEmpty).trim().isNotEmpty
              ? num.parse(
                  row[colsToDetail["ageMin"] ?? 99]!.value!.toString().trim())
              : null,
          ageMax: (row[colsToDetail["ageMax"] ?? 99]?.value?.toString() ?? constEmpty).trim().isNotEmpty
              ? num.parse(
                  row[colsToDetail["ageMax"] ?? 99]!.value!.toString().trim())
              : null,
          isFree:
              (row[colsToDetail["isFree"] ?? 99]?.value?.toString() ?? constEmpty).trim().isNotEmpty
                  ? row[colsToDetail["isFree"] ?? 99]?.value?.toString().contains("免費")
                  : null,
          priceMin: (row[colsToDetail["priceMin"] ?? 99]?.value?.toString() ?? constEmpty).trim().isNotEmpty
              ? num.parse(row[colsToDetail["priceMin"] ?? 99]!.value!.toString().trim())
              : null,
          priceMax: (row[colsToDetail["priceMax"] ?? 99]?.value?.toString() ?? constEmpty).trim().isNotEmpty ? num.parse(row[colsToDetail["priceMax"] ?? 99]!.value!.toString().trim()) : null,
          isOutdoor: (row[colsToDetail["isOutdoor"] ?? 99]?.value?.toString() ?? constEmpty).trim().isNotEmpty ? row[colsToDetail["isOutdoor"] ?? 99]?.value?.toString().contains("戶外") : null,
          id: row[colsToDetail["id"] ?? 99]?.value?.toString(),
          masterUrl: row[colsToDetail["masterUrl"] ?? 99]?.value?.toString(),
          subEvents: []));
    }
    return events;
  }
}
