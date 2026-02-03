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
  final Set<String> seenUrls = {};
  ServiceEventPublic({this.perEventDelay = const Duration(seconds: 1)});

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

    DateTime today = DateTime.now();
    today = DateTime(today.year, today.month, today.day);
    //==================================== 取得外部資源事件 strolltimesUrl ====================================
    final strolltimesUrl =
        "https://news.strolltimes.com/events/weekend/"; //'https://strolltimes.com/weekend-events/';
    if (await checkEventsUrl(strolltimesUrl, today)) {
      try {
        List<EventItem> strolltimesList =
            await fetchPageEventsStrolltimes(strolltimesUrl, today) ?? [];

        //==================================== strolltimesList事件寫入 ====================================
        List<Map> dataList = strolltimesList.isEmpty
            ? []
            : (dbNameSet.isEmpty
                    ? strolltimesList
                    : strolltimesList.where((e) {
                        final name = e.name;
                        bool resultBool = !dbNameSet.contains(name);
                        if(resultBool){
                          dbNameSet.add(name);
                        }
                        return resultBool;
                      }).toList())
                .map((e) => e.toJson())
                .toList();

        if (dataList.isNotEmpty) {
          await client.from(TableNames.recommendedEvents).insert(dataList);
        }
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
        List<Map> dataList = cloudCultureList.isEmpty
            ? []
            : (dbNameSet.isEmpty
                    ? cloudCultureList
                    : cloudCultureList.where((e) {
                        final name = e.name;
                        bool resultBool = !dbNameSet.contains(name);
                        if(resultBool){
                          dbNameSet.add(name);
                        }
                        return resultBool;
                      }).toList())
                .map((e) => e.toJson())
                .toList();

        if (dataList.isNotEmpty) {
          await client.from(TableNames.recommendedEvents).insert(dataList);
        }
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

    for (final item in data) {
      /// 1️⃣ 解析 endDate
      final endDateStr = item['endDate'];
      if (endDateStr == null) continue;

      final endDate = DateTime.tryParse(endDateStr.replaceAll('/', '-'));
      if (endDate == null || endDate.isBefore(today)) continue;
      DateTime? startDate = DateTime.tryParse(
          (item['startDate'] ?? constEmpty).replaceAll('/', '-'));

      // 2️⃣ 判斷是否「免費」
      final price = item['price'] ?? constEmpty;
      final discountInfo = item['discountInfo'] ?? constEmpty;
      final descriptionFilterHtml = item['descriptionFilterHtml'] ?? constEmpty;
      final comment = item['comment'] ?? constEmpty;
      final showInfoList = item['showInfo'] as List<dynamic>? ?? [];
      final eventName = item['title'] ?? constEmpty;
      bool isFree = (price.contains('免費') ||
              discountInfo.contains('免費') ||
              descriptionFilterHtml.contains('免費') ||
              comment.contains('免費'));
      final eventHref =
          "https://cloud.culture.tw/frontsite/inquiry/eventInquiryAction.do?method=showEventDetail&uid=${item['UID']}";
      //3️⃣ 一個活動可能有多個場次
      final show0 = showInfoList[0];
      String locationName0 = show0['locationName'] ?? constEmpty;
      if (eventName.contains('付費') || (!isFree && !locationName0.contains('免費'))) {
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
          city: location0.substring(0, 3),
          location: "$locationName0(${location0.substring(3)})",
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
      final subStartDate =
          DateTime.tryParse(subStartDateStrSplit[0].replaceAll('/', '-'));
      final partsStartTime = subStartDateStrSplit.length > 1
          ? subStartDateStrSplit[1].split(':')
          : null;
      final subEndDateStr = (show['endTime'] ?? constEmpty).toString();
      final subEndDateStrSplit = subEndDateStr.split(" ");
      final subEndDate =
          DateTime.tryParse(subEndDateStrSplit[0].replaceAll('/', '-'));
      final partsEndTime = subEndDateStrSplit.length > 1
          ? subEndDateStrSplit[1].split(':')
          : null;
      subEvents.add(EventItem(
        id: uuid.v4(),
        startDate: subStartDate,
        startTime: partsStartTime == null
            ? null
            : TimeOfDay(
                hour: int.parse(partsStartTime[0]),
                minute: int.parse(partsStartTime[1])),
        endDate: subEndDate,
        endTime: partsEndTime == null
            ? null
            : TimeOfDay(
                hour: int.parse(partsEndTime[0]),
                minute: int.parse(partsEndTime[1])),
        city: location,
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
                DateTime.tryParse(cells[0].text.trim().replaceAll('/', '-'));
            DateTime? endDate =
                DateTime.tryParse(cells[1].text.trim().replaceAll('/', '-'));
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
