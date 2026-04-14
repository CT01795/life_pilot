import 'dart:convert';
import 'dart:core';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/event/service_event.dart';
import 'package:life_pilot/utils/logger.dart';

class ClusterItem {
  final String id;
  final LatLng position;
  final List<EventItem> events;

  ClusterItem({
    required this.id,
    required this.position,
    required this.events,
  });

  bool get isCluster => events.length > 1;
  EventItem get single => events.first;

  static String detectCountryHint(String location) {
    final l = location.trim();

    /// ======================
    /// 🇹🇼 TAIWAN（22 縣市）
    /// ======================
    if (RegExp(r'(台灣|臺灣|Taiwan|'
            r'台北|臺北|Taipei|新北|基隆|Keelung|桃園|Taoyuan|新竹|Hsinchu|苗栗|Miaoli|'
            r'台中|臺中|Taichung|彰化|Changhua|南投|Nantou|'
            r'雲林|Yunlin|嘉義|Chiayi|'
            r'台南|Tainan|臺南|高雄|Kaohsiung|'
            r'屏東|Pingtung|'
            r'宜蘭|Yilan|花蓮|Hualien|台東|臺東|Taitung|'
            r'澎湖|Penghu|金門|Kinmen|連江|Lienchiang|馬祖|Matsu)')
        .hasMatch(l)) {
      return ',TW'; //',Taiwan';
    }

    /// ======================
    /// 🇯🇵 JAPAN
    /// ======================
    // 日本熱門城市 / 縣市 / 景點
    if (RegExp(r'(東京|大阪|京都|奈良|神戸|横浜|名古屋|札幌|函館|小樽|旭川|'
            r'福岡|博多|九州|長崎|佐世保|大分|別府|由布院|'
            r'沖縄|那覇|石垣|宮古島|'
            r'広島|宮島|岡山|倉敷|下関|'
            r'金沢|富山|高山|白川郷|'
            r'松本|上高地|軽井沢|草津|'
            r'箱根|熱海|伊豆|鎌倉|江ノ島|'
            r'河口湖|富士|'
            r'仙台|山形|福島|青森|弘前|'
            r'秋田|盛岡|岩手|'
            r'徳島|高松|松山|今治|'
            r'高知|'
            r'鳥取|米子|出雲|松江|'
            r'熊本|阿蘇|鹿児島|指宿|'
            r'宮崎)')
        .hasMatch(l)) {
      return ',JP'; //',Japan';
    }

    /// ======================
    /// 🇨🇳 CHINA（常見城市）
    /// ======================
    if (RegExp(r'(北京|上海|广州|深圳|'
            r'杭州|苏州|南京|无锡|'
            r'成都|重庆|西安|武汉|'
            r'天津|青岛|厦门|福州|'
            r'长沙|郑州|合肥|南昌)')
        .hasMatch(l)) {
      return ',CN'; //',China';
    }

    /// ======================
    /// 🇰🇷 SOUTH KOREA
    /// ======================
    if (RegExp(r'[가-힣]').hasMatch(l) ||
        RegExp(r'(서울|부산|인천|대구|대전|광주|울산|'
                r'수원|성남|용인|'
                r'제주|서귀포)')
            .hasMatch(l)) {
      return ',KR'; //',South Korea';
    }

    /// ======================
    /// 🇭🇰 HONG KONG
    /// ======================
    if (RegExp(r'(Hong Kong|香港)').hasMatch(l)) {
      return ',HK'; //',Hong Kong';
    }

    /// ======================
    /// 🇸🇬 SINGAPORE
    /// ======================
    if (RegExp(r'(新加坡|Singapore)').hasMatch(l)) {
      return ',SG'; //',Singapore';
    }

    /// ======================
    /// 🇹🇭 THAILAND
    /// ======================
    if (RegExp(r'(曼谷|清迈|普吉|芭提雅|Bangkok|Chiang\s?Mai|Phuket)').hasMatch(l)) {
      return ',TH'; //',Thailand';
    }

    /// ======================
    /// 🇺🇸 USA（常見城市）
    /// ======================
    if (RegExp(r'(New\s?York|Los\s?Angeles|San\s?Francisco|'
            r'Seattle|Chicago|Boston|'
            r'CA|NY|TX|WA|IL)')
        .hasMatch(l)) {
      return ',US'; //',USA';
    }

    /// 🇬🇧 UK
    if (RegExp(r'(London|Manchester|Birmingham|Liverpool|Leeds)').hasMatch(l)) {
      return ',GB'; //',UK';
    }

    /// 🇫🇷 France
    if (RegExp(r'(Paris|Lyon|Marseille|Nice)').hasMatch(l)) {
      return ',FR'; //',France';
    }

    /// 🇩🇪 Germany
    if (RegExp(r'(Berlin|Munich|München|Frankfurt|Hamburg)').hasMatch(l)) {
      return ',DE'; //',Germany';
    }

    /// 🇮🇹 Italy
    if (RegExp(r'(Rome|Roma|Milan|Milano|Venice|Venezia|Florence)')
        .hasMatch(l)) {
      return ',IT'; //',Italy';
    }

    /// 🇪🇸 Spain
    if (RegExp(r'(Madrid|Barcelona|Valencia|Seville)').hasMatch(l)) {
      return ',ES'; //',Spain';
    }

    /// 🇦🇺 Australia
    if (RegExp(r'(Sydney|Melbourne|Brisbane|Perth)').hasMatch(l)) {
      return ',AU'; //',Australia';
    }

    /// 🇨🇦 Canada
    if (RegExp(r'(Toronto|Vancouver|Montreal|Calgary)').hasMatch(l)) {
      return ',CA'; //',Canada';
    }

    return l; // ❗ 無法判斷 → 不加國家
  }

  static String? _apiKey;
  static Future<String> getKey() async {
    _apiKey ??= await ServiceEvent().getKey(keyName: "OPEN_WEATHER_API_KEY");
    return _apiKey!;
  }

  static Future<Map<String, double>> getLatLngFromAddressCommon(
      String tmpLocation) async {
    try {
      String currentCountry = detectCountryHint(tmpLocation);
      final address = Uri.encodeComponent(tmpLocation);
      await getKey();
      final geoUrl = Uri.parse(
        'https://api.openweathermap.org/geo/1.0/direct?q=$address$currentCountry&limit=1&appid=$_apiKey',
      );

      final geoRes = await http.get(geoUrl);
      if (geoRes.statusCode == 200) {
        final geoData = json.decode(geoRes.body);
        if (geoData is List && geoData.isNotEmpty) {
          final loc = geoData[0];
          return {"lat": loc['lat'], "lng": loc['lon']};
        }
      }
      return {};
    } catch (e) {
      logger.e(e);
      return {};
    }
  }

  static Future<EventViewModel> getLatLngFromAddressView(
      EventViewModel event) async {
    if (event.lat != null && event.lng != null) {
      return event;
    }
    Map tmpMap =
        await ClusterItem.getLatLngFromAddressCommon(event.locationDisplay.split("．")[0]); //.split("．")[0]
    event.lat = tmpMap["lat"];
    event.lng = tmpMap["lng"];
    return event;
  }

  static Future<EventItem> getLatLngFromAddressItem(EventItem event) async {
    if (event.lat != null && event.lng != null) {
      return event;
    }
    Map tmpMap =
        await ClusterItem.getLatLngFromAddressCommon(event.city); // ${event.location}
    event.lat = tmpMap["lat"];
    event.lng = tmpMap["lng"];
    return event;
  }

  static List<ClusterItem> buildClusters(
    List<EventItem> events,
    double zoom,
  ) {
    // zoom 越大 grid 越細
    final double gridSize = (360 / (1 << zoom.toInt())).clamp(0.01, 5);

    final Map<String, List<EventItem>> buckets = {};

    for (final e in events) {
      if (e.lat == null || e.lng == null) continue;

      final gx = (e.lat! / gridSize).floor();
      final gy = (e.lng! / gridSize).floor();
      final key = '$gx-$gy';

      buckets.putIfAbsent(key, () => []);
      buckets[key]!.add(e);
    }

    final clusters = <ClusterItem>[];

    buckets.forEach((key, items) {
      final avgLat =
          items.map((e) => e.lat!).reduce((a, b) => a + b) / items.length;
      final avgLng =
          items.map((e) => e.lng!).reduce((a, b) => a + b) / items.length;

      clusters.add(
        ClusterItem(
          id: key,
          position: LatLng(avgLat, avgLng),
          events: items,
        ),
      );
    });

    return clusters;
  }
}
