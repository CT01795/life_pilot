import 'dart:typed_data';
import 'package:csv/csv.dart';

import 'package:excel/excel.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/event/service_event_public.dart';
import 'package:life_pilot/utils/extension.dart';

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
      String indent = '',
      required AppLocalizations loc}) {
    final row = [
      _textCell('$indent${event.name}'),
      _textCell(event.type),
      _textCell(event.city),
      _textCell(event.location),
      //_textCell(event.fee),
      _textCell(event.startDate?.formatDateString() ?? ''),
      _textCell(event.startTime?.formatTimeString() ?? ''),
      _textCell(event.endDate?.formatDateString() ?? ''),
      _textCell(event.endTime?.formatTimeString() ?? ''),
      _textCell(event.description),
      _textCell(event.unit),
      _textCell(event.ageMin?.toString() ?? ''),
      _textCell(event.ageMax?.toString() ?? ''),
      _textCell(event.isFree == null
          ? ''
          : (event.isFree! ? loc.free : loc.pay)),
      _textCell(event.priceMin?.toString() ?? ''),
      _textCell(event.priceMax?.toString() ?? ''),
      _textCell(event.isOutdoor == null
          ? ''
          : (event.isOutdoor! ? loc.outdoor : loc.indoor)),
      _textCell(event.id),
      _textCell(event.masterUrl ?? ''),
    ];
    sheet.appendRow(row);
  }

  TextCellValue _textCell(String value) => TextCellValue(value);

  List<EventItem> parseCsv(String csvText, AppLocalizations loc) {
    final rows = const CsvToListConverter().convert(csvText);
    if (rows.length <= 1) return [];

    List<EventItem> events = [];
    final headerRow = rows[0];
    Map<String, int> colsToDetail = {};
    for (int i = 0; i < headerRow.length; i++) {
      final tmp = headerRow[i].toString();
      if (tmp.contains(loc.activityName)) {
        colsToDetail["name"] = i;
      } else if (tmp.contains(loc.keywords)) {
        colsToDetail["type"] = i;
      } else if (tmp.contains(loc.city)) {
        colsToDetail["city"] = i;
      } else if (tmp.contains(loc.location)) {
        colsToDetail["location"] = i;
      } else if (tmp.contains(loc.startDate)) {
        colsToDetail["startDate"] = i;
      } else if (tmp.contains(loc.startTime)) {
        colsToDetail["startTime"] = i;
      } else if (tmp.contains(loc.endDate)) {
        colsToDetail["endDate"] = i;
      } else if (tmp.contains(loc.endTime)) {
        colsToDetail["endTime"] = i;
      } else if (tmp.contains(loc.description)) {
        colsToDetail["description"] = i;
      } else if (tmp.contains(loc.sponsor)) {
        colsToDetail["unit"] = i;
      } else if (tmp.contains(loc.ageMin)) {
        colsToDetail["ageMin"] = i;
      } else if (tmp.contains(loc.ageMax)) {
        colsToDetail["ageMax"] = i;
      } else if (tmp.contains(loc.fee)) {
        colsToDetail["isFree"] = i;
      } else if (tmp.contains(loc.priceMin)) {
        colsToDetail["priceMin"] = i;
      } else if (tmp.contains(loc.priceMax)) {
        colsToDetail["priceMax"] = i;
      } else if (tmp.contains(loc.outdoor)) {
        colsToDetail["isOutdoor"] = i;
      } else if (tmp.contains(loc.excelColumnHeaderId)) {
        colsToDetail["id"] = i;
      } else if (tmp.contains(loc.excelColumnHeaderMasterUrl)) {
        colsToDetail["masterUrl"] = i;
      }
    }
    // 假設第 1 列是 header
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty || row.length <= 17) continue;
      events.add(EventItem(
          name: row[colsToDetail["name"] ?? 99]?.toString() ?? '',
          type: row[colsToDetail["type"] ?? 99]?.toString() ?? '',
          city: row[colsToDetail["city"] ?? 99]?.toString() ?? '',
          location: row[colsToDetail["location"] ?? 99]?.toString() ?? '',
          //fee: row[?]?.toString(),
          startDate: DateTime.tryParse(
              row[colsToDetail["startDate"] ?? 99]?.toString() ?? ''),
          startTime: DateTimeParser.parseTime(
              row[colsToDetail["startTime"] ?? 99]?.toString() ?? ''),
          endDate: DateTime.tryParse(
              row[colsToDetail["endDate"] ?? 99]?.toString() ?? ''),
          endTime: DateTimeParser.parseTime(
              row[colsToDetail["endTime"] ?? 99]?.toString() ?? ''),
          description: row[colsToDetail["description"] ?? 99]?.toString() ?? '',
          unit: row[colsToDetail["unit"] ?? 99]?.toString() ?? '',
          ageMin: (row[colsToDetail["ageMin"] ?? 99]?.toString() ?? '').trim().isNotEmpty
              ? num.parse(
                  row[colsToDetail["ageMin"] ?? 99]!.value!.toString().trim())
              : null,
          ageMax: (row[colsToDetail["ageMax"] ?? 99]?.toString() ?? '').trim().isNotEmpty
              ? num.parse(
                  row[colsToDetail["ageMax"] ?? 99]!.value!.toString().trim())
              : null,
          isFree:
              (row[colsToDetail["isFree"] ?? 99]?.toString() ?? '').trim().isNotEmpty
                  ? row[colsToDetail["isFree"] ?? 99]?.toString().contains(loc.free)
                  : null,
          priceMin: (row[colsToDetail["priceMin"] ?? 99]?.toString() ?? '').trim().isNotEmpty
              ? num.parse(row[colsToDetail["priceMin"] ?? 99]!.value!.toString().trim())
              : null,
          priceMax: (row[colsToDetail["priceMax"] ?? 99]?.toString() ?? '').trim().isNotEmpty ? num.parse(row[colsToDetail["priceMax"] ?? 99]!.value!.toString().trim()) : null,
          isOutdoor: (row[colsToDetail["isOutdoor"] ?? 99]?.toString() ?? '').trim().isNotEmpty ? row[colsToDetail["isOutdoor"] ?? 99]?.toString().contains(loc.outdoor) : null,
          id: row[colsToDetail["id"] ?? 99]?.toString(),
          masterUrl: row[colsToDetail["masterUrl"] ?? 99]?.toString(),
          subEvents: []));
    }
    return events;
  }

  List<EventItem> parseExcel(Sheet sheet, AppLocalizations loc) {
    if (sheet.rows.length <= 1) return [];

    List<EventItem> events = [];
    final headerRow = sheet.rows[0];
    Map<String, int> colsToDetail = {};
    for (int i = 0; i < headerRow.length; i++) {
      final tmp = headerRow[i]?.value?.toString();
      if (tmp == null) {
        continue;
      }else if (tmp.contains(loc.activityName)) {
        colsToDetail["name"] = i;
      } else if (tmp.contains(loc.keywords)) {
        colsToDetail["type"] = i;
      } else if (tmp.contains(loc.city)) {
        colsToDetail["city"] = i;
      } else if (tmp.contains(loc.location)) {
        colsToDetail["location"] = i;
      } else if (tmp.contains(loc.startDate)) {
        colsToDetail["startDate"] = i;
      } else if (tmp.contains(loc.startTime)) {
        colsToDetail["startTime"] = i;
      } else if (tmp.contains(loc.endDate)) {
        colsToDetail["endDate"] = i;
      } else if (tmp.contains(loc.endTime)) {
        colsToDetail["endTime"] = i;
      } else if (tmp.contains(loc.description)) {
        colsToDetail["description"] = i;
      } else if (tmp.contains(loc.sponsor)) {
        colsToDetail["unit"] = i;
      } else if (tmp.contains(loc.ageMin)) {
        colsToDetail["ageMin"] = i;
      } else if (tmp.contains(loc.ageMax)) {
        colsToDetail["ageMax"] = i;
      } else if (tmp.contains(loc.free)) {
        colsToDetail["isFree"] = i;
      } else if (tmp.contains(loc.priceMin)) {
        colsToDetail["priceMin"] = i;
      } else if (tmp.contains(loc.priceMax)) {
        colsToDetail["priceMax"] = i;
      } else if (tmp.contains(loc.outdoor)) {
        colsToDetail["isOutdoor"] = i;
      } else if (tmp.contains(loc.excelColumnHeaderId)) {
        colsToDetail["id"] = i;
      } else if (tmp.contains(loc.excelColumnHeaderMasterUrl)) {
        colsToDetail["masterUrl"] = i;
      }
    }
    // 假設第 1 列是 header
    for (int i = 1; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      if (row.isEmpty || row.length <= 17) continue;
      events.add(EventItem(
          name: row[colsToDetail["name"] ?? 99]?.value?.toString() ?? '',
          type: row[colsToDetail["type"] ?? 99]?.value?.toString() ?? '',
          city: row[colsToDetail["city"] ?? 99]?.value?.toString() ?? '',
          location: row[colsToDetail["location"] ?? 99]?.value?.toString() ?? '',
          //fee: row[?]?.value?.toString(),
          startDate: DateTime.tryParse(
              row[colsToDetail["startDate"] ?? 99]?.value?.toString() ?? ''),
          startTime: DateTimeParser.parseTime(
              row[colsToDetail["startTime"] ?? 99]?.value?.toString() ?? ''),
          endDate: DateTime.tryParse(
              row[colsToDetail["endDate"] ?? 99]?.value?.toString() ?? ''),
          endTime: DateTimeParser.parseTime(
              row[colsToDetail["endTime"] ?? 99]?.value?.toString() ?? ''),
          description: row[colsToDetail["description"] ?? 99]?.value?.toString() ?? '',
          unit: row[colsToDetail["unit"] ?? 99]?.value?.toString() ?? '',
          ageMin: (row[colsToDetail["ageMin"] ?? 99]?.value?.toString() ?? '').trim().isNotEmpty
              ? num.parse(
                  row[colsToDetail["ageMin"] ?? 99]!.value!.toString().trim())
              : null,
          ageMax: (row[colsToDetail["ageMax"] ?? 99]?.value?.toString() ?? '').trim().isNotEmpty
              ? num.parse(
                  row[colsToDetail["ageMax"] ?? 99]!.value!.toString().trim())
              : null,
          isFree:
              (row[colsToDetail["isFree"] ?? 99]?.value?.toString() ?? '').trim().isNotEmpty
                  ? row[colsToDetail["isFree"] ?? 99]?.value?.toString().contains(loc.free)
                  : null,
          priceMin: (row[colsToDetail["priceMin"] ?? 99]?.value?.toString() ?? '').trim().isNotEmpty
              ? num.parse(row[colsToDetail["priceMin"] ?? 99]!.value!.toString().trim())
              : null,
          priceMax: (row[colsToDetail["priceMax"] ?? 99]?.value?.toString() ?? '').trim().isNotEmpty ? num.parse(row[colsToDetail["priceMax"] ?? 99]!.value!.toString().trim()) : null,
          isOutdoor: (row[colsToDetail["isOutdoor"] ?? 99]?.value?.toString() ?? '').trim().isNotEmpty ? row[colsToDetail["isOutdoor"] ?? 99]?.value?.toString().contains(loc.outdoor) : null,
          id: row[colsToDetail["id"] ?? 99]?.value?.toString(),
          masterUrl: row[colsToDetail["masterUrl"] ?? 99]?.value?.toString(),
          subEvents: []));
    }
    return events;
  }
}
