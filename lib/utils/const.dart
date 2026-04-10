import 'package:flutter/material.dart';

String? weatherApiKey;

final List<String> currencyList = [
  'TWD',
  'USD',
  'JPY',
  'KRW',
  'SGD',
  'MYR',
  'CNY',
  'HKD',
  'GBP',
  'AUD',
  'CAD',
  'CHF',
  'NZD',
  'THB',
  'EUR',
  'VND'
];

// -------------------- Auth --------------------
class AuthConstants {
  static const guest = 'Guest';
  static const sysAdminEmail = 'minavi@alumni.nccu.edu.tw';
  static const email = 'email';
  static const password = 'password';
}

// -------------------- Source --------------------
class Source {
  static const twse = "twse";
  static const tpex = "tpex";
  static const strolltimesWeekend = "strolltimes.com/weekend";
  static const strolltimesEventsData = "strolltimes.com/events-data";
  static const cloudCulture = "cloud.culture.tw";
  static const accupass = "www.accupass.com";
  static const paperwindmill = "www.paperwindmill.com.tw";
  static const mocGov = "event.moc.gov.tw";
  static const taiwanNet = "www.taiwan.net.tw";
  static const ntpc = "ntpc";
  static const taipeiOpenData = "cultureexpress.taipei/OpenData/Event/C000003";
}

// -------------------- Tables --------------------
class TableNames {
  static const calendarEvents = "calendar_events";
  static const stockDailyPrice = "stock_daily_price";
  static const stockDate = "stock_date";
  static const recommendedEvents = "recommended_events";
  static const recommendedEventsDeleted = "recommended_events_deleted";
  static const recommendedEventsFavor = "recommended_events_favor";
  static const recommendedEventUrl = "recommended_event_url";
  static const recommendedAttractions = "recommended_attractions";
  static const memoryTrace = "memory_trace";
  static const gameTranslationSynonyms = "game_translation_synonyms";
}

// -------------------- GameColors --------------------
class GameColors {
  // 主色（金黃，但不要太亮）
  static const primary = Color(0xFFE0B04B);
  static const sky = Color(0xFF8EC5FF);
  static const skyBottom = Color(0xFF5F86A6);
  // 地板（不要用真實棕色 → 改遊戲色）
  static const ground = Color(0xFF4B3A2A);
  // 子彈（偏暖橘）
  static const bullet = Color(0xFFE88A2A);
  // 文字（白灰，不要黑）
  static const textDark = Color(0xFF1F2937);
  static const textItemDark = Color(0xFF1F2937);
  // ⭐ 卡片
  static const card = Color(0xFFEAF2FF);
  // HUD底
  static const hud = Color(0xAA000000);

  static const buttonBase = Color(0xFF1F2A38);
  static const buttonAccent = Color(0xFFE0B04B);
}

// -------------------- Date Formats --------------------
class DateFormats {
  static const hhmm = 'HH:mm';
  static const mmdd = 'MM/dd';
  static const mmddHHmm = 'MM/dd HH:mm';
  static const yyyyMMddHHmm = 'yyyy/MM/dd HH:mm';
  static const yyyyMMdd = 'yyyy/MM/dd';
}

// -------------------- Calendar Misc --------------------
class CalendarMisc {
  static const zero = '0';
  static const granted = 'granted';
  static const startToS = 'S';
  static const endToE = 'E';
  static const androidIcon = '@mipmap/ic_launcher';
}

// -------------------- Event Fields --------------------
class EventFields {
  static const String id = 'id';
  static const String masterGraphUrl = 'master_graph_url';
  static const String masterUrl = 'master_url';
  static const String startDate = 'start_date';
  static const String endDate = 'end_date';
  static const String startTime = 'start_time';
  static const String endTime = 'end_time';
  static const String city = 'city';
  static const String location = 'location';
  static const String name = 'name';
  static const String type = 'type';
  static const String description = 'description';
  //static const String fee = 'fee';
  static const String unit = 'unit';
  static const String subEvents = 'sub_events';
  static const String account = 'account';
  static const String repeatOptions = 'repeat_options';
  static const String reminderOptions = 'reminder_options';
  static const String isHoliday = "is_holiday";
  static const String isTaiwanHoliday = "is_taiwan_holiday";
  static const String isApproved = "is_approved";
  static const String ageMin = "age_min";
  static const String ageMax = "age_max";
  static const String isFree = "is_free";
  static const String priceMin = "price_min";
  static const String priceMax = "price_max";
  static const String isOutdoor = "is_outdoor";
  static const String isLike = "is_like";
  static const String isDislike = "is_dislike";
  static const String pageViews = "page_views";
  static const String cardClicks = "card_clicks";
  static const String saves = "saves";
  static const String registrationClicks = "registration_clicks";
  static const String likeCounts = "like_counts";
  static const String dislikeCounts = "dislike_counts";
  static const String source = "source";
}

// -------------------- Gap --------------------
class Gaps {
  // Width
  static const w8 = SizedBox(width: 8);
  static const w16 = SizedBox(width: 16);
  static const w24 = SizedBox(width: 24);
  static const w36 = SizedBox(width: 36);
  static const w60 = SizedBox(width: 60);

  // Height
  static const h4 = SizedBox(height: 4);
  static const h8 = SizedBox(height: 8);
  static const h16 = SizedBox(height: 16);
  static const h32 = SizedBox(height: 32);
  static const h48 = SizedBox(height: 48);
  static const h80 = SizedBox(height: 80);
}

// -------------------- Padding / EdgeInsets --------------------
class Insets {
  static const e0 = EdgeInsets.zero;
  static const all1 = EdgeInsets.all(1);
  static const all2 = EdgeInsets.all(2);
  static const all3 = EdgeInsets.all(3);
  static const all4 = EdgeInsets.all(4);
  static const all8 = EdgeInsets.all(8);
  static const all12 = EdgeInsets.all(12);
  static const l8 = EdgeInsets.only(left: 8);
  static const v4 = EdgeInsets.symmetric(vertical: 4);
  static const h6 = EdgeInsets.symmetric(horizontal: 6);
  static const h8v4 = EdgeInsets.symmetric(horizontal: 8, vertical: 4);
  static const h8v16 = EdgeInsets.symmetric(horizontal: 8, vertical: 16);
  static const h12v8 = EdgeInsets.symmetric(horizontal: 12, vertical: 8);

  static const directionalL20T6 = EdgeInsetsDirectional.only(start: 20, top: 6);
  static const directionalL4R4T4B8 =
      EdgeInsetsDirectional.only(start: 4, end: 4, top: 4, bottom: 8);
  static const directionalL1R1B1 =
      EdgeInsetsDirectional.only(start: 1, end: 1, top: 0, bottom: 1);
  static const directionalR3 = EdgeInsetsDirectional.only(end: 3);
  static const directionalT6 = EdgeInsets.only(top: 6);
  static const directionalB12 = EdgeInsets.only(bottom: 12);
  static const directionalT24B12 = EdgeInsets.only(bottom: 12, top: 24);
}

// -------------------- Message Enum --------------------
enum MSG {
  success, // 成功
  failed, // "失敗"
  notSupportExport, // "⚠️ 此平台尚未支援匯出"
}

// -------------------- Error Fields --------------------
class ErrorFields {
  static const String loginError = 'loginError';
  static const String registerError = 'registerError';
  static const String logoutError = 'logoutError';
  static const String noEmailError = 'noEmailError';
  static const String noPasswordError = 'noPasswordError';
  static const String unexpectedError = 'Unexpected error';

  // 🔹 Firebase Auth 常見錯誤代碼
  static const String authError = 'Auth Error';
  static const String userNotFoundError = 'user-not-found';
  static const String wrongPasswordError = 'wrong-password';
  static const String invalidCredentialError = 'invalid-credential';
  static const String wrongUserPassword = 'wrongUserPassword';
  static const String tooManyRequestsError = 'too-many-requests';
  static const String networkRequestFailedError = 'network-request-failed';
  static const String invalidEmailError = 'invalid-email';
  static const String emailAlreadyInUseError = 'email-already-in-use';
  static const String weakPasswordError = 'weak-password';
  static const String resetPasswordEmailNotFoundError =
      'resetPasswordEmailNotFound';
}
