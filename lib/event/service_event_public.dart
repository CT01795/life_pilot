// lib/services/event_service.dart
import 'dart:convert';

import 'package:charset/charset.dart';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart' hide Element;
import 'package:html/parser.dart' show parse;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/event/service_event.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class ServiceEventPublic {
  final client = Supabase.instance.client;
  final Duration perEventDelay;
  ServiceEventPublic({this.perEventDelay = const Duration(seconds: 1)});

  String safeCity(String location) =>
      location.length >= 3 ? location.substring(0, 3) : location;

  String safeAddress(String location) =>
      location.length > 3 ? location.substring(3) : '';

  Future<bool> checkIfUrlExists(String url, DateTime today) async {
    final result = await client
        .from(TableNames.recommendedEventUrl)
        .select('master_url')
        .eq('start_date', today)
        .eq('master_url', url)
        .limit(1);
    return result.isNotEmpty;
  }

  Future<bool> checkEventsUrl(String url, DateTime today) async {
    // 檢查今日是否已經檢視過
    bool exists = await checkIfUrlExists(url, today);
    if (exists) {
      return false;
    }

    try {
      await client.from(TableNames.recommendedEventUrl).upsert(
        {'master_url': url, 'start_date': today.toIso8601String()},
        onConflict: 'master_url,start_date',
      );
      return true;
    } on Exception catch (ex) {
      logger.e(ex);
      return false;
    }
  }

  Future<Set<String>> _insertIfNotExists(
    List<EventItem> events,
    Set<String> dbNameSet,
  ) async {
    if (events.isEmpty) return dbNameSet;

    final newEvents = events.where((e) {
      if (dbNameSet.contains(e.name) || dbNameSet.contains(e.id)) return false;
      dbNameSet.add(e.name);
      dbNameSet.add(e.id);
      return true;
    }).toList();

    if (newEvents.isNotEmpty) {
      await client
          .from(TableNames.recommendedEvents)
          .insert(newEvents.map((e) => e.toJson()).toList());
    }
    return dbNameSet;
  }

  Future<void> fetchAndSaveAllEvents() async {
    //==================================== 取得目前資料庫事件 ====================================
    List<EventItem> historyList = (await ServiceEvent().getEvents(
          tableName: TableNames.recommendedEvents,
          inputUser: AuthConstants.sysAdminEmail,
        ) ??
        []);
    Set<String> dbNameSet =
        historyList.map((e) => e.name).where((name) => name.isNotEmpty).toSet();
    dbNameSet.addAll(
        historyList.map((e) => e.id).where((id) => id.isNotEmpty).toSet());

    DateTime today = DateUtils.dateOnly(DateTime.now());
    //==================================== 取得外部資源事件 strolltimes.com/weekend ====================================
    String strolltimesWeekendUrl =
        "https://strolltimes.com/weekend.json"; //https://news.strolltimes.com/events/weekend/"; //'https://strolltimes.com/weekend-events/';
    if (await checkEventsUrl(strolltimesWeekendUrl, today)) {
      try {
        List<EventItem> strolltimesList =
            await fetchPageEventsStrolltimes(strolltimesWeekendUrl, today) ??
                [];

        //==================================== strolltimesList事件寫入 ====================================
        dbNameSet = await _insertIfNotExists(strolltimesList, dbNameSet);
      } on Exception catch (ex) {
        logger.e(ex);
      }
    }
    //==================================== 取得外部資源事件 strolltimes.com/weekend ====================================
    String strolltimesEventsUrl = "https://strolltimes.com/events-data.csv";
    if (await checkEventsUrl(strolltimesEventsUrl, today)) {
      try {
        final url = Uri.parse(strolltimesEventsUrl);

        final response = await http.get(url);

        if (response.statusCode == 200) {
          String csv;
          try {
            csv = utf8.decode(response.bodyBytes);
          } catch (e, s) {
            logger.e('❌ utf8 decode error: $e', stackTrace: s);
            csv = Charset.getByName('big5')!.decode(response.bodyBytes);
          }
          List<EventItem> strolltimesList = parseStrolltimesCsv(csv, today);
          //==================================== strolltimesList事件寫入 ====================================
          dbNameSet = await _insertIfNotExists(strolltimesList, dbNameSet);
        }
      } on Exception catch (ex) {
        logger.e(ex);
      }
    }
    //==================================== 取得外部資源事件 cloud.culture.tw ====================================
    Map<int, String> tmpMap = {
      1: "音樂",
      2: "戲劇",
      3: "舞蹈",
      4: "親子",
      5: "獨立音樂",
      6: "展覽",
      7: "講座",
      8: "電影",
      11: "綜藝",
      13: "競賽",
      14: "徵選",
      15: "其他",
      17: "演唱會",
      19: "研習課程",
      200: "閱讀"
    };
    for (int i in tmpMap.keys) {
      final cloudCultureUrl =
          'https://cloud.culture.tw/frontsite/trans/SearchShowAction.do?method=doFindTypeJ&category=$i';

      if (await checkEventsUrl(cloudCultureUrl, today)) {
        try {
          List<EventItem> cloudCultureList =
              await fetchPageEventsCloudCulture(cloudCultureUrl, today) ?? [];

          //==================================== strolltimesList事件寫入 ====================================
          dbNameSet = await _insertIfNotExists(cloudCultureList, dbNameSet);
        } on Exception catch (ex) {
          logger.e(ex);
        }
      }
    }

    //==================================== 取得 ACCUPASS 活動 ====================================
    String accupassUrl =
        "https://www.accupass.com/search?p=free&q=活動&s=latest&t=none";

    if (await checkEventsUrl(accupassUrl, today)) {
      try {
        List<EventItem> accupassList =
            await fetchPageEventsAccupass(accupassUrl, today) ?? [];

        dbNameSet = await _insertIfNotExists(accupassList, dbNameSet);
      } catch (ex) {
        logger.e(ex);
      }
    }
  }

  //==================================== 取得外部資源事件 strolltimesUrl ====================================
  Future<List<EventItem>?> fetchPageEventsAccupass(
      String inUrl, DateTime today) async {
    final url = Uri.parse(inUrl);
    final res = await http.get(
      url,
      headers: {"User-Agent": "Mozilla/5.0"},
    );
    if (res.statusCode != 200) return [];

    final html = res.body;

    // 1️⃣ 抓所有 <script> 標籤
    final scriptRegex = RegExp(r'<script.*?>(.*?)<\/script>', dotAll: true);
    final scripts =
        scriptRegex.allMatches(html).map((m) => m.group(1)!).toList();

    String? targetScript;
    List<EventItem> events = [];
    for (int i = 60; i < scripts.length; i++) {
      if (events.isNotEmpty) {
        break;
      }
      if (scripts[i].contains('self.__next_f.push')) {
        targetScript = scripts[i];
        int start = targetScript.indexOf('searchedRankingEvents');
        if (start == -1) {
          continue;
        }
        start = targetScript.indexOf('[', start);
        int depth = 0;
        int end = start;

        for (; end < targetScript.length; end++) {
          if (targetScript[end] == '[') depth++;
          if (targetScript[end] == ']') depth--;

          if (depth == 0) break;
        }

        final jsonStr = targetScript
            .substring(start, end + 1)
            .replaceAll(r'\"', '"')
            .replaceAll(r'\n', '');

        final tmpEvents = jsonDecode(jsonStr);
        for (var map in tmpEvents) {
          final sdt = DateTime.parse("${map["startDateTime"]}Z").toLocal();
          final edt = DateTime.parse("${map["endDateTime"]}Z").toLocal();
          if (edt.isBefore(today)) {
            continue;
          }
          final detailUrl =
              "https://www.accupass.com/event/${map["eventIdNumber"]}";
          String city = map["location"];
          String location = "";
          /*final res2 = await http.get(
            Uri.parse(detailUrl),
            headers: {"User-Agent": "Mozilla/5.0"},
          );

          if (res2.statusCode == 200) {
            final html2 = res2.body;
            // 先找 "location":" 的起始位置
            int locKeyIndex = html2.indexOf('"location":');

            if (locKeyIndex != -1) {
              // 地址的實際開始位置
              final tmpString = html2.substring(locKeyIndex, locKeyIndex + 200);
              int start = tmpString.indexOf(":", tmpString.indexOf("address"));
              // 找結尾的引號
              int end = tmpString.indexOf(',', start);

              // 截取地址
              city = tmpString.substring(start+2, start + 7);
              location = tmpString.substring(start + 7, end-1);
            }
          }*/

          events.add(EventItem(
            id: map["eventIdNumber"],
            masterUrl: detailUrl,
            startDate: sdt,
            endDate: edt,
            city: city,
            location: location,
            name: map["name"],
            account: AuthConstants.sysAdminEmail,
          ));
        }
      }
    }
    return events;
  }

  List<EventItem> parseStrolltimesCsv(String csvText, DateTime today) {
    final rows = const CsvToListConverter(
      eol: '\n',
      shouldParseNumbers: false,
    ).convert(csvText);
    if (rows.length <= 1) return [];

    List<EventItem> events = [];
    final headerRow = rows[0];
    Map<String, int> colsToDetail = {};
    final uuid = const Uuid();
    for (int i = 0; i < headerRow.length; i++) {
      final tmp = headerRow[i].toString();
      if (tmp.contains("活動名稱")) {
        colsToDetail["name"] = i;
      } else if (tmp.contains("關鍵字詞")) {
        colsToDetail["type"] = i;
      } else if (tmp.contains("所在縣市")) {
        colsToDetail["city"] = i;
      } else if (tmp.contains("活動地點")) {
        colsToDetail["location"] = i;
      } else if (tmp.contains("開始時間")) {
        colsToDetail["startDate"] = i;
      } else if (tmp.contains("結束時間")) {
        colsToDetail["endDate"] = i;
      } else if (tmp.contains("活動摘要")) {
        colsToDetail["description"] = i;
      } else if (tmp.contains("文章網址")) {
        colsToDetail["masterUrl2"] = i;
      } else if (tmp.contains("資料來源")) {
        colsToDetail["masterUrl"] = i;
      }
    }
    // 假設第 1 列是 header
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty) continue;
      String strS =
          row[colsToDetail["startDate"] ?? 99]?.toString().trim() ?? '';
      DateTime? startDate =
          strS.length >= 8 ? DateFormat('yyyy-M-d').parse(strS) : null;

      String strE = row[colsToDetail["endDate"] ?? 99]?.toString().trim() ?? '';
      DateTime? endDate =
          strE.length >= 8 ? DateFormat('yyyy-M-d').parse(strE) : null;
      if (startDate == null || endDate == null || endDate.isBefore(today)) {
        continue;
      }

      String? tmpUrl = row[colsToDetail["masterUrl"] ?? 99]?.toString();
      String? replaceUrl = row[colsToDetail["masterUrl2"] ?? 99]?.toString();
      if (replaceUrl != null && replaceUrl.startsWith("/events")) {
        replaceUrl = "https://strolltimes.com$replaceUrl";
      } else {
        replaceUrl = "";
      }
      String otherUrl = "";
      if (tmpUrl == null ||
          tmpUrl.isEmpty ||
          tmpUrl.contains("/permalink.php")) {
        row[colsToDetail["masterUrl"] ?? 99] = replaceUrl;
      } else {
        final urls = tmpUrl.split("|");
        row[colsToDetail["masterUrl"] ?? 99] = urls[0];
        for (int i = 1; i < urls.length; i++) {
          otherUrl += "${urls[i]}\n";
        }
      }
      events.add(EventItem(
          id: uuid.v4(),
          name: row[colsToDetail["name"] ?? 99]?.toString() ?? '',
          type: row[colsToDetail["type"] ?? 99]?.toString() ?? '',
          city: row[colsToDetail["city"] ?? 99]?.toString() ?? '',
          location: row[colsToDetail["location"] ?? 99]?.toString() ?? '',
          //fee: row[?]?.toString(),
          startDate: startDate,
          //startTime: DateTimeParser.parseTime(
          //    row[colsToDetail["startTime"] ?? 99]?.toString() ?? ''),
          endDate: endDate,
          //endTime: DateTimeParser.parseTime(
          //    row[colsToDetail["endTime"] ?? 99]?.toString() ?? ''),
          description:
              "${replaceUrl.isNotEmpty ? "$replaceUrl\n" : ""}${otherUrl.isNotEmpty ? otherUrl : ""}${row[colsToDetail["description"] ?? 99] ?? ''}\n",
          //unit: row[colsToDetail["unit"] ?? 99]?.toString() ?? '',
          masterUrl: row[colsToDetail["masterUrl"] ?? 99]?.toString(),
          account: AuthConstants.sysAdminEmail,
          subEvents: []));
    }
    return events;
  }

  //==================================== 取得外部資源事件 cloud.Culture ====================================
  Future<List<EventItem>?> fetchPageEventsCloudCulture(
      String url, DateTime today) async {
    final res = await http.get(
      Uri.parse(url),
      headers: {
        'User-Agent': 'Mozilla/5.0 (compatible; StrollTimesCrawler/1.0)',
      },
    );

    if (res.statusCode != 200) return [];

    final List<dynamic> data = jsonDecode(res.body);
    Set<String> tmpSet = {};
    List<EventItem> tmpList = [];
    final uuid = const Uuid();
    Map<String, String> typeMap = {
      "1": "音樂表演",
      "2": "戲劇",
      "3": "舞蹈",
      "4": "親子",
      "5": "獨立音樂",
      "6": "展覽",
      "7": "講座",
      "8": "電影",
      "11": "綜藝",
      "13": "競賽",
      "17": "演唱會",
      "19": "研習課程",
      "200": "閱讀"
    };
    for (final item in data) {
      /// 1️⃣ 解析 endDate
      final endDateStr = item['endDate'];
      if (endDateStr == null) continue;

      final endDate = DateTimeParser.parseDate(endDateStr);
      if (endDate == null || endDate.isBefore(today)) continue;
      DateTime? startDate = DateTimeParser.parseDate((item['startDate'] ?? ''));

      // 2️⃣ 判斷是否「免費」
      final showInfoList = item['showInfo'] as List<dynamic>? ?? [];
      final eventName = item['title'] ?? '';
      final category = typeMap.containsKey(item['category'] ?? "9999")
          ? typeMap[item['category'] ?? "9999"]
          : null;
      final isFree = EventRule.isFreeEvent(item, showInfoList);
      final eventHref =
          "https://cloud.culture.tw/frontsite/inquiry/eventInquiryAction.do?method=showEventDetail&uid=${item['UID']}";
      //3️⃣ 一個活動可能有多個場次
      if (showInfoList.isEmpty) continue;
      final show0 = showInfoList[0];
      String locationName0 = show0['locationName'] ?? '';
      if (!isFree) {
        continue;
      }
      String location0 = show0['location'] ?? '';
      if (!tmpSet.contains(eventName)) {
        List<EventItem> subEvents = getSubEvents(showInfoList, uuid, eventName);
        tmpList.add(EventItem(
          id: uuid.v4(),
          masterUrl: eventHref,
          startDate: startDate,
          startTime: subEvents[0].startTime,
          endDate: endDate,
          endTime: subEvents.length <= 1 ? subEvents[0].endTime : null,
          type: category ?? '',
          city: safeCity(location0),
          location: "$locationName0(${safeAddress(location0)})",
          name: eventName,
          subEvents: subEvents.length <= 1 ? [] : subEvents,
          account: AuthConstants.sysAdminEmail,
        ));
        tmpSet.add(eventName);
      }
    }
    return tmpList;
  }

  List<EventItem> getSubEvents(
      List<dynamic> showInfoList, Uuid uuid, String eventName) {
    List<EventItem> subEvents = [];
    for (int i = 0; i < showInfoList.length; i++) {
      final show = showInfoList[i];
      final locationName = show['locationName'] ?? '';
      final location = show['location'] ?? '';
      final subStartDateStr = (show['time'] ?? '').toString();
      final subStartDateStrSplit = subStartDateStr.split(" ");
      final subStartDate = DateTimeParser.parseDate(subStartDateStrSplit[0]);
      final subEndDateStr = (show['endTime'] ?? '').toString();
      final subEndDateStrSplit = subEndDateStr.split(" ");
      final subEndDate = DateTimeParser.parseDate(subEndDateStrSplit[0]);
      subEvents.add(EventItem(
        id: uuid.v4(),
        startDate: subStartDate,
        startTime: subStartDateStrSplit.length > 1
            ? DateTimeParser.parseTime(subStartDateStrSplit[1])
            : null,
        endDate: subEndDate,
        endTime: subEndDateStrSplit.length > 1
            ? DateTimeParser.parseTime(subEndDateStrSplit[1])
            : null,
        city: safeCity(location),
        location: locationName,
        name: eventName,
        account: AuthConstants.sysAdminEmail,
      ));
    }
    return subEvents;
  }

  //==================================== 取得外部資源事件 strolltimesUrl ====================================
  Future<List<EventItem>?> fetchPageEventsStrolltimes(
      String inUrl, DateTime today) async {
    final url = Uri.parse(inUrl);
    final res = await http.get(url);
    if (res.statusCode != 200) return [];
    final List<dynamic> data = jsonDecode(res.body);
    List<dynamic> links =
        data.take(2).map((e) => 'https://strolltimes.com${e['link']}').toList();
    if (links.isEmpty) return [];

    Set<String> tmpSet = {};
    List<EventItem> tmpList = [];
    final uuid = const Uuid();
    for (int i = 1; i < links.length; i++) {
      final res2 = await http.get(Uri.parse(links[i]), headers: {
        'User-Agent': 'Mozilla/5.0 (compatible; StrollTimesCrawler/1.0)'
      });
      if (res2.statusCode != 200) return [];
      final document2 = parse(res2.body);

      // 找到所有 <h2> 標題
      final h2List = document2.querySelectorAll('h2');
      for (var h2 in h2List) {
        String title = h2.text.trim();
        if (!title.contains("活動")) continue;
        title = title.replaceAll("活動", '');

        // 找該 h2 之後的 <figure class="wp-block-table">
        var sibling = h2.nextElementSibling;
        if (sibling == null) continue;
        final rows = sibling.querySelectorAll('tbody tr');
        for (var row in rows) {
          final cells = row.querySelectorAll('td');
          if (cells.length >= 4) {
            DateTime? startDate = cells[0].text.trim().length >= 8
                ? DateFormat('yyyy/M/d').parse(cells[0].text.trim())
                : null;
            DateTime? endDate = cells[1].text.trim().length >= 8
                ? DateFormat('yyyy/M/d').parse(cells[1].text.trim())
                : null;
            if (startDate != null &&
                endDate != null &&
                !endDate.isBefore(today)) {
              final location = cells[3].text.trim();
              final aTag = cells[2].querySelector('a');
              final eventName = aTag?.text.trim() ?? '';
              String eventHref = aTag?.attributes['href'] ?? '';
              if (eventHref.startsWith("/events/")) {
                eventHref = inUrl.replaceAll("/weekend.json", '') + eventHref;
              }
              if (!tmpSet.contains(eventName)) {
                tmpList.add(EventItem(
                  id: uuid.v4(),
                  masterUrl: eventHref,
                  startDate: startDate,
                  endDate: endDate,
                  city: title,
                  location: location,
                  name: eventName,
                  account: AuthConstants.sysAdminEmail,
                ));
                tmpSet.add(eventName);
              }
            }
          }
        }
      }
    }
    return tmpList;
  }
}

class DateTimeParser {
  static DateTime? parseDate(String? s) {
    if (s == null || s.isEmpty) return null;
    return DateTime.tryParse(s.replaceAll('/', '-'));
  }

  static TimeOfDay? parseTime(String? s) {
    if (s == null) return null;

    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(s);
    if (match == null) return null;

    return TimeOfDay(
      hour: int.parse(match.group(1)!),
      minute: int.parse(match.group(2)!),
    );
  }
}

class EventRule {
  static const _freeKeywords = ['免費', '自由入場', '索票'];
  static const _paidKeywords = ['付費', '售票', '購票'];
  static bool isFreeEvent(Map item, List<dynamic> showInfoList) {
    bool containFree(String s) => _freeKeywords.any(s.contains);
    bool containPaid(String s) => _paidKeywords.any(s.contains);

    return !containPaid(item['title'] ?? '') &&
        (containFree(item['price'] ?? '') ||
            containFree(item['discountInfo'] ?? '') ||
            containFree(item['descriptionFilterHtml'] ?? '') ||
            containFree(item['comment'] ?? '') ||
            showInfoList.any((s) => containFree(s['locationName'] ?? '')));
  }
}
