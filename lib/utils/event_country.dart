import 'package:flutter/widgets.dart';

class EventCountry {
  final String code;
  final String en;
  final String zh;
  final String ja;
  final String ko;

  const EventCountry(this.code, this.en, this.zh, this.ja, this.ko);

  String label(BuildContext context) {
    return switch (Localizations.localeOf(context).languageCode) {
      'zh' => zh,
      'ja' => ja,
      'ko' => ko,
      _ => en,
    };
  }

  static const values = <EventCountry>[
    EventCountry('TW', 'Taiwan', '台灣', '台湾', '대만'),
    EventCountry('JP', 'Japan', '日本', '日本', '일본'),
    EventCountry('KR', 'South Korea', '韓國', '韓国', '대한민국'),
    EventCountry('SG', 'Singapore', '新加坡', 'シンガポール', '싱가포르'),
    EventCountry('US', 'United States', '美國', 'アメリカ', '미국'),
    EventCountry('CA', 'Canada', '加拿大', 'カナダ', '캐나다'),
    EventCountry('CN', 'China', '中國', '中国', '중국'),
    EventCountry('HK', 'Hong Kong', '香港', '香港', '홍콩'),
    EventCountry('MO', 'Macau', '澳門', 'マカオ', '마카오'),
    EventCountry('TH', 'Thailand', '泰國', 'タイ', '태국'),
    EventCountry('VN', 'Vietnam', '越南', 'ベトナム', '베트남'),
    EventCountry('MY', 'Malaysia', '馬來西亞', 'マレーシア', '말레이시아'),
    EventCountry('ID', 'Indonesia', '印尼', 'インドネシア', '인도네시아'),
    EventCountry('PH', 'Philippines', '菲律賓', 'フィリピン', '필리핀'),
    EventCountry('AU', 'Australia', '澳洲', 'オーストラリア', '호주'),
    EventCountry('NZ', 'New Zealand', '紐西蘭', 'ニュージーランド', '뉴질랜드'),
    EventCountry('GB', 'United Kingdom', '英國', 'イギリス', '영국'),
    EventCountry('FR', 'France', '法國', 'フランス', '프랑스'),
    EventCountry('DE', 'Germany', '德國', 'ドイツ', '독일'),
    EventCountry('IT', 'Italy', '義大利', 'イタリア', '이탈리아'),
    EventCountry('ES', 'Spain', '西班牙', 'スペイン', '스페인'),
    EventCountry('NL', 'Netherlands', '荷蘭', 'オランダ', '네덜란드'),
    EventCountry('CH', 'Switzerland', '瑞士', 'スイス', '스위스'),
    EventCountry('IN', 'India', '印度', 'インド', '인도'),
    EventCountry(
        'AE', 'United Arab Emirates', '阿拉伯聯合大公國', 'アラブ首長国連邦', '아랍에미리트'),
  ];

  static String normalize(String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty || normalized.toLowerCase() == 'taiwan') return 'TW';
    final upper = normalized.toUpperCase();
    if (values.any((country) => country.code == upper)) return upper;
    for (final country in values) {
      if ({country.en, country.zh, country.ja, country.ko}
          .any((label) => label.toLowerCase() == normalized.toLowerCase())) {
        return country.code;
      }
    }
    return 'TW';
  }
}
