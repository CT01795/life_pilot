import 'dart:convert';

import 'package:charset/charset.dart';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart' hide Element;
import 'package:html/parser.dart' show parse;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/event/service_event.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class ServiceEventPublic {
  final client = Supabase.instance.client;
  final Duration perEventDelay;
  ServiceEventPublic({this.perEventDelay = const Duration(seconds: 1)});

  String safeCity(String location) =>
      location.length >= 3 ? location.substring(0, 3) : location;

  String safeCity2(String location) => location.length >= 3
      ? location.substring(0, location.substring(2, 3) == "縣" ? 3 : 2)
      : location;

  String safeAddress(String location) =>
      location.length > 3 ? location.substring(3) : '';

  String safeAddress2(String location) => location.length > 3
      ? location.substring(location.substring(2, 3) == "縣" ? 3 : 2)
      : '';

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
    Set<String> dbNameDateSet,
  ) async {
    if (events.isEmpty) return dbNameDateSet;

    final newEvents = events.where((e) {
      final tmpName = e.name.replaceAll(" ", "").replaceAll("_", "") +
          DateFormat('yyyy-MM-dd').format(e.startDate!);
      final tmpId = e.id + DateFormat('yyyy-MM-dd').format(e.startDate!);
      if (dbNameDateSet.contains(tmpName) || dbNameDateSet.contains(tmpId)) {
        return false;
      }
      dbNameDateSet.add(tmpName);
      dbNameDateSet.add(tmpId);
      return true;
    }).toList();

    if (newEvents.isNotEmpty) {
      await client
          .from(TableNames.recommendedEvents)
          .insert(newEvents.map((e) => e.toJson()).toList());
    }
    return dbNameDateSet;
  }

  static EventItem parseFacebookText(String text1) {
    final uuid = const Uuid();

    // ========= 活動名稱（強化） =========
    String name = _extractEventName(text1);

    // ========= 日期（支援民國年） =========
    DateTime? startDate;
    DateTime? endDate;
    final normalized = normalizeText(text1);
    final dateMatches = RegExp(r'(?:(\d{4})[\/\.\-](\d{1,2})[\/\.\-](\d{1,2}))|(?:(\d{1,2})[\/\.\-](\d{1,2}))')
        .allMatches(normalized)
        .toList();

    if (dateMatches.isNotEmpty) {
      final m = dateMatches[0];

      int y, m1, d1;
      if (m.group(1) != null) {
        // yyyy.mm.dd
        y = int.parse(m.group(1)!);
        if (y < 1911) y += 1911;
        m1 = int.parse(m.group(2)!);
        d1 = int.parse(m.group(3)!);
      } else {
        // mm.dd，年份 fallback 當前年份
        y = DateTime.now().year;
        m1 = int.parse(m.group(4)!);
        d1 = int.parse(m.group(5)!);
      }

      startDate = DateTime(y, m1, d1);

      // 如果有第二個 match，就解析 endDate
      if (dateMatches.length > 1) {
        final m2 = dateMatches[1];
        int y2, m2v, d2;
        if (m2.group(1) != null) {
          y2 = int.parse(m2.group(1)!);
          if (y2 < 1911) y2 += 1911;
          m2v = int.parse(m2.group(2)!);
          d2 = int.parse(m2.group(3)!);
        } else {
          y2 = y;
          m2v = int.parse(m2.group(4)!);
          d2 = int.parse(m2.group(5)!);
        }
        endDate = DateTime(y2, m2v, d2);
      } else {
        endDate = startDate;
      }
    }

    // ========= 時間 =========
    final timeMatches =
        RegExp(r'(\d{1,2}):(\d{2})').allMatches(normalized).toList();

    TimeOfDay? startTime;
    TimeOfDay? endTime;

    if (timeMatches.isNotEmpty) {
      startTime = TimeOfDay(
        hour: int.parse(timeMatches[0].group(1)!),
        minute: int.parse(timeMatches[0].group(2)!),
      );

      if (timeMatches.length > 1) {
        endTime = TimeOfDay(
          hour: int.parse(timeMatches[1].group(1)!),
          minute: int.parse(timeMatches[1].group(2)!),
        );
      }
    }

    // ========= 地點（強化） =========
    String location = "";
    final locMatch =
        RegExp(r'(?:地點|活動地點)\s*[：:\s*]?\s*(.+)').firstMatch(normalized);
    if (locMatch != null) {
      location = locMatch.group(1)!.trim();
    }

    // ========= 城市 =========
    String city = detectCity(normalized);

    // ========= URL =========
    String masterUrl = "";
    final urlMatch = RegExp(r'https?:\/\/[^\s]+').firstMatch(normalized);
    if (urlMatch != null) {
      masterUrl = urlMatch.group(0)!;
    }

    // ========= 主辦 =========
    String unit = "";
    final unitMatch =
        RegExp(r'(?:主辦單位|主辦)[：:\s]*([^\n]+)').firstMatch(normalized);
    if (unitMatch != null) {
      unit = unitMatch.group(1)!.trim();
    }

    // ========= 類型 =========
    String type = detectType(normalized);

    return EventItem(
      id: uuid.v4(),
      name: name,
      startDate: startDate,
      endDate: endDate,
      startTime: startTime,
      endTime: endTime,
      city: city,
      location: location,
      masterUrl: masterUrl,
      unit: unit,
      description: normalized,
      type: type,
    );
  }

  static String _extractEventName(String text) {
    // 1️⃣ 《活動名稱》
    final match1 = RegExp(r'《([^》]+)》').firstMatch(text);
    if (match1 != null) return match1.group(1)!.trim();

    // 2️⃣ hashtag（過濾垃圾tag）
    final matches = RegExp(r'#([\u4e00-\u9fa5A-Za-z0-9]+)')
        .allMatches(text)
        .map((e) => e.group(1)!)
        .toList();

    for (var tag in matches) {
      if (tag.contains("節")) {
        return tag;
      }
    }

    // 3️⃣ fallback：第一行清洗
    return text
        .split('\n')
        .first
        .replaceAll(RegExp(r'[^\u4e00-\u9fa5A-Za-z0-9 ]'), '')
        .trim();
  }

  static String normalizeText(String input) {
    // 2️⃣ 常見符號 → 半形
    input = input.replaceAll(RegExp(r'[．。∙·]'), '.'); // 點
    input = input.replaceAll(RegExp(r'[：﹕]'), ':'); // 冒號
    input = input.replaceAll(RegExp(r'[－–—]'), '-'); // dash

    // 3️⃣ 刪掉零寬字元
    input = input.replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '');

    // 4️⃣ 將 Mathematical Bold / Italic 拉丁字母轉回 ASCII
    input = input.split('').map((c) {
      int code = c.runes.first;

      // A-Z
      if (code >= 0x1D400 && code <= 0x1D419) {
        return String.fromCharCode(code - 0x1D400 + 0x41);
      }
      // a-z
      if (code >= 0x1D41A && code <= 0x1D433) {
        return String.fromCharCode(code - 0x1D41A + 0x61);
      }
      // 0-9 (補充平面)
      if (code >= 0x1D7CE && code <= 0x1D7D7) {
        return String.fromCharCode(code - 0x1D7CE + 0x30);
      }
      // 其他粗體/斜體數字或符號可繼續補充
      return c;
    }).join();

    // 1️⃣ 數字 normalize
    input = normalizeNumbers(input);
    return input;
  }

  static String normalizeNumbers(String input) {
    const halfWidth = '0123456789';
    const targetWidth = [
      "𝟬",
      "𝟭",
      "2",
      "𝟯",
      "𝟰",
      "𝟱",
      "𝟲",
      "𝟳",
      "8",
      "9"
    ];
    for (int i = 0; i < halfWidth.length; i++) {
      input = input.replaceAll(targetWidth[i], halfWidth[i]);
    }
    // 映射兩種全形數字（U+FF10~FF19 + U+1D7CE~U+1D7D7）
    final Map<int, String> map = {};

    // 全形 ０-９
    for (int i = 0; i < 10; i++) {
      map[0xFF10 + i] = halfWidth[i];
    }

    // Mathematical digits 𝟬–𝟿 (U+1D7CE–U+1D7D7)
    for (int i = 0; i < 10; i++) {
      map[0x1D7CE + i] = halfWidth[i];
    }

    // Mathematical double-struck digits 𝟘–𝟡 (U+1D7D8–1D7E1)
    for (int i = 0; i < 10; i++) {
      map[0x1D7D8 + i] = halfWidth[i];
    }

    // Mathematical sans-serif digits 𝟢–𝟩 (U+1D7E2–U+1D7EB)
    for (int i = 0; i < 10; i++) {
      map[0x1D7E2 + i] = halfWidth[i];
    }

    // Mathematical bold digits 𝟬–𝟿 (U+1D7F6–U+1D7FF)
    for (int i = 0; i < 10; i++) {
      map[0x1D7F6 + i] = halfWidth[i];
    }

    final buffer = StringBuffer();
    for (var rune in input.runes) {
      buffer.write(map[rune] ?? String.fromCharCode(rune));
    }

    return buffer.toString();
  }

  static String detectCity(String text) {
    if (text.contains("台北") || text.contains("臺北")) return "臺北市";
    if (text.contains("新北")) return "新北市";
    if (text.contains("基隆")) return "基隆";
    if (text.contains("桃園")) return "桃園市";
    if (text.contains("新竹")) return "新竹";
    if (text.contains("苗栗")) return "苗栗";
    if (text.contains("台中") || text.contains("臺中")) return "臺中";
    if (text.contains("彰化")) return "彰化";
    if (text.contains("南投")) return "南投";
    if (text.contains("雲林")) return "雲林";
    if (text.contains("嘉義")) return "嘉義";
    if (text.contains("台南") || text.contains("臺南")) return "臺南";
    if (text.contains("高雄")) return "高雄";
    if (text.contains("屏東")) return "屏東";
    if (text.contains("宜蘭")) return "宜蘭";
    if (text.contains("花蓮")) return "花蓮";
    if (text.contains("台東") || text.contains("臺東")) return "臺東";
    if (text.contains("澎湖")) return "澎湖";
    if (text.contains("金門")) return "金門";
    if (text.contains("連江")) return "連江";
    if (text.contains("馬祖")) return "馬祖";
    return text;
  }

  static String detectType(String text) {
    if (text.contains("戲劇")) return "戲劇";
    if (text.contains("表演")) return "表演";
    if (text.contains("市集")) return "市集";
    return "";
  }

  Future<void> fetchAndSaveAllEvents() async {
    //==================================== 取得目前資料庫事件 ====================================
    List<EventItem> historyList = (await ServiceEvent().getEvents(
          tableName: TableNames.recommendedEvents,
          inputUser: AuthConstants.sysAdminEmail,
        ) ??
        []);
    Set<String> dbNameDateSet = historyList
        .map((e) =>
            e.name.replaceAll(" ", "").replaceAll("_", "") +
            DateFormat('yyyy-MM-dd').format(e.startDate!))
        .where((name) => name.isNotEmpty)
        .toSet();
    dbNameDateSet.addAll(historyList
        .map((e) => e.id + DateFormat('yyyy-MM-dd').format(e.startDate!))
        .where((id) => id.isNotEmpty)
        .toSet());

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
        dbNameDateSet =
            await _insertIfNotExists(strolltimesList, dbNameDateSet);
      } on Exception catch (ex) {
        logger.e(ex);
      }
    }
    //==================================== 取得外部資源事件 strolltimes.com/events-data ====================================
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
          dbNameDateSet =
              await _insertIfNotExists(strolltimesList, dbNameDateSet);
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
          dbNameDateSet =
              await _insertIfNotExists(cloudCultureList, dbNameDateSet);
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

        dbNameDateSet = await _insertIfNotExists(accupassList, dbNameDateSet);
      } catch (ex) {
        logger.e(ex);
      }
    }

    //==================================== 取得紙風車活動 ====================================
    String paperWindmillUrl = "https://www.paperwindmill.com.tw/paper/";

    if (await checkEventsUrl(paperWindmillUrl, today)) {
      try {
        List<EventItem> paperWindmillList =
            await fetchPageEventsPaperWindmill(paperWindmillUrl, today) ?? [];

        dbNameDateSet =
            await _insertIfNotExists(paperWindmillList, dbNameDateSet);
      } catch (ex) {
        logger.e(ex);
      }
    }

    //==================================== 取得文化部活動 ====================================
    final types = ["B2", "I7", "I8"];
    final formatToday = DateFormat("yyyy-MM-dd").format(today);
    for (String tmpType in types) {
      String moclUrl =
          "https://event.moc.gov.tw/sp.asp?xdurl=ccEvent2016/eventSearchList.asp&ev_char1=$tmpType&ev_start=$formatToday&action=query&ctNode=676&mp=1&pageSize=100";
      if (await checkEventsUrl(moclUrl, today)) {
        try {
          List<EventItem> moclUrlList =
              await fetchPageEventsMoc(moclUrl, today) ?? [];

          dbNameDateSet = await _insertIfNotExists(moclUrlList, dbNameDateSet);
        } catch (ex) {
          logger.e(ex);
        }
      }
    }

    //==================================== 取得交通部觀光署-觀光資訊網活動 ====================================
    bool isBreakTime = false;
    int pageIndex = 1;
    while (!isBreakTime) {
      String taiwanNetUrl =
          "https://www.taiwan.net.tw/m1.aspx?sNo=0001019&page=$pageIndex";

      if (await checkEventsUrl(taiwanNetUrl, today)) {
        try {
          List<EventItem> taiwanNetList =
              await fetchPageEventsTaiwanNet(taiwanNetUrl, today) ?? [];

          dbNameDateSet =
              await _insertIfNotExists(taiwanNetList, dbNameDateSet);
          pageIndex = pageIndex + 1;
          isBreakTime = taiwanNetList.isEmpty && pageIndex >= 15;
        } catch (ex) {
          logger.e(ex);
          isBreakTime = true;
        }
      } else {
        pageIndex = pageIndex + 1;
        isBreakTime = pageIndex >= 15;
      }
    }
  }

  //==================================== 取得外部資源事件 文化局 ====================================
  Future<List<EventItem>?> fetchPageEventsMoc(
      String url, DateTime today) async {
    final res =
        await http.get(Uri.parse(url), headers: {'User-Agent': 'Mozilla/5.0'});
    if (res.statusCode != 200) return [];

    final document = parse(res.body);
    final events = <EventItem>[];
    final uuid = const Uuid();

    // 選擇 table 的 tr，跳過第一行表頭
    final rows = document.querySelectorAll("table tr");
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      final cells = row.querySelectorAll("td");
      if (cells.length < 6) continue;

      try {
        // 日期
        String dateText =
            cells[1].text.trim(); // ex: "2026/03/18 19:30 ~ 2026/03/18 21:30"
        DateTime? startDate;
        DateTime? endDate;
        TimeOfDay? startTime;
        TimeOfDay? endTime;

        final dateMatch =
            RegExp(r'(\d{4})/(\d{1,2})/(\d{1,2})\s*(\d{1,2}):(\d{2})')
                .allMatches(dateText)
                .toList();
        if (dateMatch.isNotEmpty) {
          int y = int.parse(dateMatch[0].group(1)!);
          int m = int.parse(dateMatch[0].group(2)!);
          int d = int.parse(dateMatch[0].group(3)!);
          int h1 = int.parse(dateMatch[0].group(4)!);
          int min1 = int.parse(dateMatch[0].group(5)!);

          startDate = DateTime(y, m, d);
          startTime = TimeOfDay(hour: h1, minute: min1);

          if (dateMatch.length > 1) {
            int y2 = int.parse(dateMatch[1].group(1)!);
            int m2 = int.parse(dateMatch[1].group(2)!);
            int d2 = int.parse(dateMatch[1].group(3)!);
            int h2 = int.parse(dateMatch[1].group(4)!);
            int min2 = int.parse(dateMatch[1].group(5)!);
            endDate = DateTime(y2, m2, d2);
            endTime = TimeOfDay(hour: h2, minute: min2);
          } else {
            endDate = startDate;
          }
        }
        if (endDate == null || endDate.isBefore(today)) continue;

        // 活動名稱 & 詳細頁
        final titleEl = cells[2].querySelector("a");
        String title = titleEl?.text.trim() ?? "文化部活動";
        String masterUrl = titleEl?.attributes['href'] ?? "";
        if (masterUrl.isNotEmpty && !masterUrl.startsWith("http")) {
          masterUrl =
              "https://event.moc.gov.tw/${masterUrl.replaceAll('../', '')}";
        }

        // 縣市 & 地點
        String city = cells[3].text.trim();
        String location = cells[4].text.trim();

        // 活動類別
        String type = cells[5].text.trim();

        events.add(EventItem(
          id: uuid.v4(),
          masterUrl: masterUrl,
          startDate: startDate,
          startTime: startTime,
          endDate: endDate,
          endTime: endTime,
          city: city,
          location: location,
          name: title,
          account: AuthConstants.sysAdminEmail,
          type: type,
          description: "",
        ));
      } catch (e) {
        logger.e("解析 Moc 活動列錯誤: $e");
      }
    }

    return events;
  }

  //==================================== 取得外部資源事件 www.taiwan.net.tw ====================================
  Future<List<EventItem>?> fetchPageEventsTaiwanNet(
      String url, DateTime today) async {
    final res =
        await http.get(Uri.parse(url), headers: {'User-Agent': 'Mozilla/5.0'});
    if (res.statusCode != 200) return [];

    final document = parse(res.body);
    final events = <EventItem>[];
    final uuid = const Uuid();

    // 取得所有 li 活動項目
    final items = document.querySelectorAll("li");
    for (var li in items) {
      final infoDiv = li.querySelector(".columnBlock-info");
      if (infoDiv == null) continue;

      // 活動名稱
      final titleEl = infoDiv.querySelector(".columnBlock-title");
      final title = titleEl?.attributes['title']?.trim() ?? "台灣活動";
      String masterUrl = titleEl?.attributes['href']?.trim() ?? "";
      if (masterUrl.isNotEmpty) {
        masterUrl = "https://www.taiwan.net.tw/$masterUrl";
      }

      // 日期文字
      String dateText = infoDiv.querySelector(".date")?.text.trim() ?? "";

      // 簡單解析日期（範例: "每年3、12月" 或 "3/28–3/29"）
      DateTime? startDate;
      final dateMatch0 =
          RegExp(r'(\d{4})/(\d{1,2})/(\d{1,2})').firstMatch(dateText);
      if (dateMatch0 != null) {
        int year = int.parse(dateMatch0.group(1)!);
        int month = int.parse(dateMatch0.group(2)!);
        int day = int.parse(dateMatch0.group(3)!);
        startDate = DateTime(year, month, day);
      }
      final dateMatch1 = RegExp(r'(\d{1,2})/(\d{1,2})').firstMatch(dateText);
      if (startDate == null && dateMatch1 != null) {
        int month = int.parse(dateMatch1.group(1)!);
        int day = int.parse(dateMatch1.group(2)!);
        startDate = DateTime(today.year, month, day);
      }
      final dateMatch2 =
          RegExp(r'(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(dateText);
      if (startDate == null && dateMatch2 != null) {
        int year = int.parse(dateMatch2.group(1)!);
        int month = int.parse(dateMatch2.group(2)!);
        int day = int.parse(dateMatch2.group(3)!);
        startDate = DateTime(year, month, day);
      } else {
        continue; // 無法解析時
      }
      final leftDateText = dateText.split("~");
      DateTime? endDate;
      if (leftDateText.length > 1) {
        final endDateMatch0 =
            RegExp(r'(\d{4})/(\d{1,2})/(\d{1,2})').firstMatch(leftDateText[1]);
        if (endDateMatch0 != null) {
          int year = int.parse(endDateMatch0.group(1)!);
          int month = int.parse(endDateMatch0.group(2)!);
          int day = int.parse(endDateMatch0.group(3)!);
          endDate = DateTime(year, month, day);
        }
        final endDateMatch1 =
            RegExp(r'(\d{1,2})/(\d{1,2})').firstMatch(leftDateText[1]);
        if (endDate == null && endDateMatch1 != null) {
          int month = int.parse(endDateMatch1.group(1)!);
          int day = int.parse(endDateMatch1.group(2)!);
          endDate = DateTime(today.year, month, day);
        }
        final endDateMatch2 =
            RegExp(r'(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(leftDateText[1]);
        if (endDate == null && endDateMatch2 != null) {
          int year = int.parse(endDateMatch2.group(1)!);
          int month = int.parse(endDateMatch2.group(2)!);
          int day = int.parse(endDateMatch2.group(3)!);
          endDate = DateTime(year, month, day);
        }
      }
      endDate = endDate ?? startDate;
      if (endDate.isBefore(today)) continue;

      // 活動簡介
      final description = "${infoDiv.querySelector("p")?.text.trim() ?? ""}\n";

      // ⚡ 抓詳細頁資訊
      String city = "";
      String location = "";
      String? organizer;
      try {
        if (masterUrl.isNotEmpty) {
          final detailRes = await http.get(Uri.parse(masterUrl),
              headers: {'User-Agent': 'Mozilla/5.0'});
          if (detailRes.statusCode == 200) {
            final detailDoc = parse(detailRes.body);
            final infoTable = detailDoc.querySelector("dl.info-table");
            if (infoTable != null) {
              // 取所有 dt 元素
              final dtList = infoTable.querySelectorAll("dt");
              for (var dt in dtList) {
                final dtText = dt.text.trim();
                final dd = dt.nextElementSibling; // dt + dd
                if (dd == null) continue;

                if (dtText.contains("主辦單位")) {
                  organizer = dd.text.trim();
                } else if (dtText.contains("地址")) {
                  final addr = dd.querySelector("a span")?.text.trim();
                  if (addr != null) {
                    city = safeCity(addr);
                    location = safeAddress(addr);
                  }
                } else if (dtText.contains("網站連結")) {
                  final webUrl =
                      dd.querySelector("a")?.attributes['href']?.trim();
                  if (webUrl != null && webUrl.isNotEmpty) masterUrl = webUrl;
                }
              }
            }
          }
        }
      } catch (e) {
        logger.e("抓取詳細頁錯誤: $e");
      }

      events.add(EventItem(
        id: uuid.v4(),
        masterUrl: masterUrl,
        startDate: startDate,
        endDate: endDate,
        city: city,
        location: location,
        name: title,
        account: AuthConstants.sysAdminEmail,
        description: description,
        unit: organizer ?? '',
      ));
    }

    return events;
  }

  //==================================== 取得外部資源事件 PaperWindmill ====================================
  Future<List<EventItem>?> fetchPageEventsPaperWindmill(
      String url, DateTime today) async {
    final res =
        await http.get(Uri.parse(url), headers: {'User-Agent': 'Mozilla/5.0'});

    if (res.statusCode != 200) return [];

    final document = parse(res.body);

    final items = document.querySelectorAll("li");

    List<EventItem> events = [];
    final uuid = const Uuid();

    for (var li in items) {
      final dataDiv = li.querySelector(".DATA");
      if (dataDiv == null) continue;

      final h6 = dataDiv.querySelectorAll("h6");
      if (h6.length < 2) continue;

      int month = int.tryParse(h6[0].text.trim()) ?? 0;
      int day = int.tryParse(h6[1].text.trim()) ?? 0;

      if (month == 0 || day == 0) continue;

      final text = li.text.replaceAll("\n", "").trim();

      // 取得時間
      final timeMatch = RegExp(r'(下午|晚上)?\s*(\d{1,2}:\d{2})').firstMatch(text);

      TimeOfDay? startTime;

      if (timeMatch != null) {
        int hour = int.parse(timeMatch.group(2)!.split(":")[0]);
        int minute = int.parse(timeMatch.group(2)!.split(":")[1]);

        if (timeMatch.group(1) == "下午" || timeMatch.group(1) == "晚上") {
          if (hour < 12) hour += 12;
        }

        startTime = TimeOfDay(hour: hour, minute: minute);
      }

      // 抓活動名稱 《》
      final nameMatch = RegExp(r'《([^》]+)》').firstMatch(text);
      final eventName =
          "${(nameMatch?.group(1) ?? "紙風車演出")} ${timeMatch?.group(0)}";

      // 地點
      String location = text
          .replaceAll(RegExp(r'^\(\S+\)'), '')
          .replaceAll(RegExp(r'(下午|晚上)?.*?\d{1,2}:\d{2}'), '')
          .replaceAll(RegExp(r'《[^》]+》'), '')
          .trim();

      final startDate =
          DateTime((month < today.month ? 1 : 0) + today.year, month, day);

      if (startDate.isBefore(today)) continue;

      events.add(
        EventItem(
          id: uuid.v4(),
          masterUrl: url,
          startDate: startDate,
          startTime: startTime,
          endDate: startDate,
          city: safeCity2(location),
          location: safeAddress2(location),
          name: eventName,
          type: "紙風車",
          account: AuthConstants.sysAdminEmail,
        ),
      );
    }

    return events;
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
