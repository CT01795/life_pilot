// lib/services/event_service.dart
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
                        return !dbNameSet.contains(name);
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
    /*final accupassUrl = 'https://www.accupass.com/search?p=free';
    if (await checkEventsUrl(accupassUrl, today)) {
      try {
        List<EventItem> accupassList =
            await fetchPageEventsAccupass(accupassUrl, today) ?? [];

        //==================================== strolltimesList事件寫入 ====================================
        List<Map> dataList = accupassList.isEmpty ? [] : (dbNameSet.isEmpty ? accupassList : accupassList.where((e) {
          final name = e.name;
          return !dbNameSet.contains(name);
        }).toList()).map((e) => e.toJson()).toList();

        if(dataList.isNotEmpty) await client.from(TableNames.recommendedEvents).insert(dataList);
      } on Exception catch (ex) {
        logger.e(ex);
      }
    }*/
  }

  //==================================== 取得外部資源事件 Accupass ====================================

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
