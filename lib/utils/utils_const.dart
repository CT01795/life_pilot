import 'package:flutter/widgets.dart';

//---------------------------------------- main ----------------------------------------
const String constSupabaseUrl = 'https://ccktdpycnferbrjrdtkp.supabase.co';
const String constSupabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNja3RkcHljbmZlcmJyanJkdGtwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTMyNTU0NTIsImV4cCI6MjA2ODgzMTQ1Mn0.jsuY3AvuhRlCwuGKmcq_hyj1ViLRX18kmQs5YYnFwR4';
const String constAppTitle = 'Life Pilot';
String constTzLocation = 'Asia/Taipei';
const List<String> constRealHolidaysTaiwan = [
  "元旦", "春節", "除夕", "和平紀念日", "兒童節", "清明節", "勞動節", "端午節",
  "教師節", "中秋節", "國慶日", "台灣光復節", "行憲紀念日",
];
const String constLocaleZh = 'zh';
const String constLocaleEn = 'en';
const String constEmail = 'email';
const String constPassword = 'password';
const String constEmpty = '';
const String constTableCalendarEvents = "calendar_events";
const String constTableRecommendedEvents = "recommended_events";

//---------------------------------------- auth ----------------------------------------
const String constGuest = 'Guest';

//---------------------------------------- calendar ----------------------------------------
const String constZero = '0';
const String constGranted = 'granted';
const String constStartToS = 'S';
const String constEndToE = 'E';
const String constSysAdminEmail = 'minavi@alumni.nccu.edu.tw';
const String constDateFormatHHmm = 'HH:mm';
const String constDateFormatMMdd = 'MM/dd';
const String constDateFormatMMddHHmm = 'MM/dd HH:mm';
const String constDateFormatyyyyMMddHHmm = 'yyyy/MM/dd HH:mm';
const String constDateFormatyyyyMMdd = 'yyyy/MM/dd';
const String constAndroidIcon = '@mipmap/ic_launcher';

// Width gaps
SizedBox kGapW8() => const SizedBox(width: 8);
SizedBox kGapW16() => const SizedBox(width: 16);
SizedBox kGapW24() => const SizedBox(width: 24);

// Height gaps
SizedBox kGapH4() => const SizedBox(height: 4);
SizedBox kGapH8() => const SizedBox(height: 8);
SizedBox kGapH16() => const SizedBox(height: 16);

// EdgeInsets
const kGapEIT4 = EdgeInsetsDirectional.only(top: 4);
const kGapEI0 = EdgeInsets.zero;
const kGapEI1 = EdgeInsets.all(1);
const kGapEI2 = EdgeInsets.all(2);
const kGapEI3 = EdgeInsets.all(3);
const kGapEI4 = EdgeInsets.all(4);
const kGapEI8 = EdgeInsets.all(8);
const kGapEI12 = EdgeInsets.all(12);
const kGapEIV4 = EdgeInsets.symmetric(vertical: 4.0);
const kGapEIH6 = EdgeInsets.symmetric(horizontal: 6);
const kGapEIH8V4 = EdgeInsets.symmetric(horizontal: 8, vertical: 4);
const kGapEIH8V16 = EdgeInsets.symmetric(horizontal: 8, vertical: 16);
const kGapEIH12V8 = EdgeInsets.symmetric(horizontal: 12, vertical: 8);
const kGapEIL20R0T6B0 = EdgeInsetsDirectional.only(start: 20, top: 6);
const kGapEIL4R4T4B8 = EdgeInsetsDirectional.only(start: 4, end: 4, top: 4, bottom: 8);
const kGapEIL1R1T8B1 = EdgeInsetsDirectional.only(start: 1, end: 1, top: 8, bottom: 1);
const kGapEIR3 = EdgeInsetsDirectional.only(end: 3);
