// lib/services/event_service.dart
import 'dart:convert';

import 'package:flutter/material.dart' hide Element;
import 'package:html/dom.dart';
import 'package:html/parser.dart' show parse;
import 'package:http/http.dart' as http;
import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/core/logger.dart';
import 'package:life_pilot/models/event/model_event_item.dart';
import 'package:life_pilot/services/event/service_event.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class ServiceEventPublic {
  final client = Supabase.instance.client;
  final Duration perEventDelay;
  ServiceEventPublic({this.perEventDelay = const Duration(seconds: 1)});

  String safeCity(String location) =>
      location.length >= 3 ? location.substring(0, 3) : location;

  String safeAddress(String location) =>
      location.length > 3 ? location.substring(3) : constEmpty;

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
      if (dbNameSet.contains(e.name)) return false;
      dbNameSet.add(e.name);
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
    Set<String> dbNameSet = (await ServiceEvent().getEvents(
              tableName: TableNames.recommendedEvents,
              inputUser: AuthConstants.sysAdminEmail,
            ) ??
            [])
        .map((e) => e.name)
        .where((name) => name.isNotEmpty)
        .toSet();

    DateTime today = DateUtils.dateOnly(DateTime.now());
    //==================================== 取得外部資源事件 strolltimesUrl ====================================
    final strolltimesUrl =
        "https://news.strolltimes.com/events/weekend/"; //'https://strolltimes.com/weekend-events/';
    if (await checkEventsUrl(strolltimesUrl, today)) {
      try {
        List<EventItem> strolltimesList =
            await fetchPageEventsStrolltimes(strolltimesUrl, today) ?? [];

        //==================================== strolltimesList事件寫入 ====================================
        dbNameSet = await _insertIfNotExists(strolltimesList, dbNameSet);
      } on Exception catch (ex) {
        logger.e(ex);
      }
    }
    //==================================== 取得外部資源事件 Accupass ====================================
    final cloudCultureUrl =
        'https://cloud.culture.tw/frontsite/trans/SearchShowAction.do?method=doFindTypeJ&category=all';
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
      "2": "戲劇",
      "3": "舞蹈",
      "4": "親子",
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
      DateTime? startDate =
          DateTimeParser.parseDate((item['startDate'] ?? constEmpty));

      // 2️⃣ 判斷是否「免費」
      final showInfoList = item['showInfo'] as List<dynamic>? ?? [];
      final eventName = item['title'] ?? constEmpty;
      final category = typeMap.containsKey(item['category'] ?? "9999") ? typeMap[item['category'] ?? "9999"] : null;
      final isFree = EventRule.isFreeEvent(item, showInfoList);
      final eventHref =
          "https://cloud.culture.tw/frontsite/inquiry/eventInquiryAction.do?method=showEventDetail&uid=${item['UID']}";
      //3️⃣ 一個活動可能有多個場次
      if (showInfoList.isEmpty) continue;
      final show0 = showInfoList[0];
      String locationName0 = show0['locationName'] ?? constEmpty;
      if (!isFree) {
        continue;
      }
      String location0 = show0['location'] ?? constEmpty;
      if (!tmpSet.contains(eventName)) {
        List<EventItem> subEvents = getSubEvents(showInfoList, uuid, eventName);
        tmpList.add(EventItem(
          id: uuid.v4(),
          masterUrl: eventHref,
          startDate: startDate,
          startTime: subEvents[0].startTime,
          endDate: endDate,
          endTime: subEvents.length <= 1 ? subEvents[0].endTime : null,
          type: category,
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
      final locationName = show['locationName'] ?? constEmpty;
      final location = show['location'] ?? constEmpty;
      final subStartDateStr = (show['time'] ?? constEmpty).toString();
      final subStartDateStrSplit = subStartDateStr.split(" ");
      final subStartDate = DateTimeParser.parseDate(subStartDateStrSplit[0]);
      final subEndDateStr = (show['endTime'] ?? constEmpty).toString();
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
      String url, DateTime today) async {
    final res = await http.get(Uri.parse(url), headers: {
      'User-Agent': 'Mozilla/5.0 (compatible; StrollTimesCrawler/1.0)'
    });
    if (res.statusCode != 200) return [];
    final document = parse(res.body);

    // 取側邊欄最新的活動子頁
    final links = document
        .querySelectorAll('ul.menu__list li a')
        .where((a) =>
            a.attributes['href']?.startsWith('/events/weekend/') ?? false)
        .cast<Element>()
        .toList();

    if (links.isEmpty) return [];

    Set<String> tmpSet = {};
    List<EventItem> tmpList = [];
    final uuid = const Uuid();
    for (int i = 1; i < links.length; i++) {
      final latestPath = links[i].attributes['href'];
      if (latestPath == null) continue;

      String url2 = 'https://news.strolltimes.com$latestPath';
      final res2 = await http.get(Uri.parse(url2), headers: {
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
            DateTime? startDate =
                DateTimeParser.parseDate(cells[0].text.trim());
            DateTime? endDate = DateTimeParser.parseDate(cells[1].text.trim());
            if (startDate != null &&
                endDate != null &&
                !endDate.isBefore(today)) {
              final location = cells[3].text.trim();
              final aTag = cells[2].querySelector('a');
              final eventName = aTag?.text.trim() ?? '';
              final eventHref = aTag?.attributes['href'] ?? '';
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

    return !containPaid(item['title'] ?? constEmpty) &&
        (containFree(item['price'] ?? constEmpty) ||
            containFree(item['discountInfo'] ?? constEmpty) ||
            containFree(item['descriptionFilterHtml'] ?? constEmpty) ||
            containFree(item['comment'] ?? '') ||
            showInfoList
                .any((s) => containFree(s['locationName'] ?? constEmpty)));
  }
}
