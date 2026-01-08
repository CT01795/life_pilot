import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:life_pilot/models/event/model_event_weather.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ServiceWeather {
  final supabase = Supabase.instance.client;
  final String? apiKey;
  ServiceWeather({required this.apiKey});

  Future<List<EventWeather>> get3DayWeather({
    required String locationDisplay,
  }) async {
    String tmpLocation = locationDisplay.split("．")[0];
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day, today.hour);

    /// 1️⃣ 查 DB
    final dbRes = await supabase
        .from('weather_forecast')
        .select()
        .eq('location', tmpLocation)
        .gte('date', today.add(Duration(hours: -3)).toIso8601String())
        .gte('created_at', todayDate.toIso8601String())
        .order('date', ascending: true);

    if (dbRes.isNotEmpty) {
      return dbRes
          .map<EventWeather>((e) => EventWeather.fromJson(e['weather']))
          .toList();
    }

    // 1️⃣ 用 OpenWeather Geocoding API 取得經緯度
    final address = Uri.encodeComponent(detectCountryHint(tmpLocation));
    final geoUrl = Uri.parse(
      'https://api.openweathermap.org/geo/1.0/direct?q=$address&limit=1&appid=$apiKey',
    );

    final geoRes = await http.get(geoUrl);
    if (geoRes.statusCode == 200) {
      final geoData = json.decode(geoRes.body);
      if (geoData is List && geoData.isNotEmpty) {
        final loc = geoData[0];
        final lat = loc['lat'];
        final lon = loc['lon'];
        final country = geoData[0]['country'];
        final name = geoData[0]['name'];

        // 2️⃣ 再呼叫 OpenWeather Weather API
        final url =
            'https://api.openweathermap.org/data/2.5/forecast?lat=$lat&lon=$lon&appid=$apiKey&units=metric';

        final res = await http.get(Uri.parse(url));
        final data = json.decode(res.body);

        final List<EventWeather> days = [];

        for (var item in data['list']) {
          days.add(
            EventWeather(
              date: DateTime.parse(item['dt_txt']).toLocal(),
              main: item['weather'][0]['main'],
              description: item['weather'][0]['description'],
              icon: item['weather'][0]['icon'],
              temp: (item['main']['temp'] as num).toDouble(),
              feelsLike: (item['main']['feels_like'] as num).toDouble(),
              tempMin: (item['main']['temp_min'] as num).toDouble(),
              tempMax: (item['main']['temp_max'] as num).toDouble(),
              pressure: (item['main']['pressure'] as num).toDouble(),
              seaLevel: (item['main']['sea_level'] as num).toDouble(),
              grndLevel: (item['main']['grnd_level'] as num).toDouble(),
            ),
          );
        }

        /// 3️⃣ 寫 DB
        for (final day in days) {
          await supabase.from('weather_forecast').upsert({
            'location': tmpLocation,
            'date': day.date.toIso8601String(),
            'weather': day.toJson(),
            'created_at': todayDate.toIso8601String(),
            'lat':lat,
            'lon':lon,
            'country':country,
            'name':name
          });
        }

        final dbRes = await supabase
            .from('weather_forecast')
            .select()
            .eq('location', tmpLocation)
            .gte('date', today.add(Duration(hours: -3)).toIso8601String())
            .gte('created_at', todayDate.toIso8601String())
            .order('date', ascending: true);

        if (dbRes.isNotEmpty) {
          return dbRes
              .map<EventWeather>((e) => EventWeather.fromJson(e['weather']))
              .toList();
        }
      }
    }
    return [];
  }
}

String detectCountryHint(String location) {
  final l = location.trim();

  /// ======================
  /// 🇯🇵 JAPAN
  /// ======================

  // 日文假名（最準）
  if (RegExp(r'[ぁ-んァ-ン]').hasMatch(l)) {
    return '$l,Japan';
  }

  // 日本熱門城市 / 縣市 / 景點
  if (RegExp(
    r'(東京|大阪|京都|奈良|神戸|横浜|名古屋|札幌|函館|小樽|旭川|'
    r'福岡|博多|北九州|長崎|佐世保|大分|別府|由布院|'
    r'沖縄|那覇|石垣|宮古島|'
    r'広島|宮島|岡山|倉敷|下関|'
    r'金沢|富山|高山|白川郷|'
    r'松本|上高地|軽井沢|草津|'
    r'箱根|熱海|伊豆|鎌倉|江ノ島|'
    r'河口湖|富士吉田|富士山|'
    r'仙台|山形|福島|青森|弘前|'
    r'秋田|盛岡|岩手|'
    r'徳島|高松|松山|今治|'
    r'高知|'
    r'鳥取|米子|出雲|松江|'
    r'熊本|阿蘇|鹿児島|指宿|'
    r'宮崎)'
  ).hasMatch(l)) {
    return '$l,Japan';
  }

  /// ======================
  /// 🇹🇼 TAIWAN（22 縣市）
  /// ======================
  if (RegExp(
    r'(台灣|臺灣|'
    r'台北|臺北|新北|基隆|桃園|新竹|苗栗|'
    r'台中|臺中|彰化|南投|'
    r'雲林|嘉義|'
    r'台南|臺南|高雄|'
    r'屏東|'
    r'宜蘭|花蓮|台東|臺東|'
    r'澎湖|金門|連江|馬祖)'
  ).hasMatch(l)) {
    return '$l,Taiwan';
  }

  /// ======================
  /// 🇨🇳 CHINA（常見城市）
  /// ======================
  if (RegExp(
    r'(北京|上海|广州|深圳|'
    r'杭州|苏州|南京|无锡|'
    r'成都|重庆|西安|武汉|'
    r'天津|青岛|厦门|福州|'
    r'长沙|郑州|合肥|南昌)'
  ).hasMatch(l)) {
    return '$l,China';
  }

  /// ======================
  /// 🇰🇷 SOUTH KOREA
  /// ======================
  if (RegExp(r'[가-힣]').hasMatch(l) ||
      RegExp(
        r'(서울|부산|인천|대구|대전|광주|울산|'
        r'수원|성남|용인|'
        r'제주|서귀포)'
      ).hasMatch(l)) {
    return '$l,South Korea';
  }

  /// ======================
  /// 🇭🇰 HONG KONG
  /// ======================
  if (RegExp(r'(Hong Kong|香港)').hasMatch(l)) {
    return '$l,Hong Kong';
  }

  /// ======================
  /// 🇸🇬 SINGAPORE
  /// ======================
  if (RegExp(r'(新加坡|Singapore)').hasMatch(l)) {
    return '$l,Singapore';
  }

  /// ======================
  /// 🇹🇭 THAILAND
  /// ======================
  if (RegExp(r'(曼谷|清迈|普吉|芭提雅|Bangkok|Chiang\s?Mai|Phuket)').hasMatch(l)) {
    return '$l,Thailand';
  }

  /// ======================
  /// 🇺🇸 USA（常見城市）
  /// ======================
  if (RegExp(
    r'(New\s?York|Los\s?Angeles|San\s?Francisco|'
    r'Seattle|Chicago|Boston|'
    r'CA|NY|TX|WA|IL)'
  ).hasMatch(l)) {
    return '$l,USA';
  }

  /// 🇬🇧 UK
  if (RegExp(r'(London|Manchester|Birmingham|Liverpool|Leeds)').hasMatch(l)) {
    return '$l,UK';
  }

  /// 🇫🇷 France
  if (RegExp(r'(Paris|Lyon|Marseille|Nice)').hasMatch(l)) {
    return '$l,France';
  }

  /// 🇩🇪 Germany
  if (RegExp(r'(Berlin|Munich|München|Frankfurt|Hamburg)').hasMatch(l)) {
    return '$l,Germany';
  }

  /// 🇮🇹 Italy
  if (RegExp(r'(Rome|Roma|Milan|Milano|Venice|Venezia|Florence)').hasMatch(l)) {
    return '$l,Italy';
  }

  /// 🇪🇸 Spain
  if (RegExp(r'(Madrid|Barcelona|Valencia|Seville)').hasMatch(l)) {
    return '$l,Spain';
  }

  /// 🇦🇺 Australia
  if (RegExp(r'(Sydney|Melbourne|Brisbane|Perth)').hasMatch(l)) {
    return '$l,Australia';
  }

  /// 🇨🇦 Canada
  if (RegExp(r'(Toronto|Vancouver|Montreal|Calgary)').hasMatch(l)) {
    return '$l,Canada';
  }

  return l; // ❗ 無法判斷 → 不加國家
}
  /*Future<EventWeather?> fetchCurrentWeather(String city) async {
    final url = Uri.parse(
      'https://api.openweathermap.org/data/2.5/weather?q=$city&appid=$apiKey&units=metric'
    );

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);
      return EventWeather.fromJson(jsonData);
    } else {
      return null;
    }
  }*/