// 📁 lib/config/app_config.dart

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:life_pilot/l10n/app_localizations.dart';

// 🌍 應用程式主要設定
@immutable
class AppConfig {
  const AppConfig._(); // ✅ 禁止被實例化

  // ─────────────── 基本資訊 ───────────────
  static const String appTitle = 'Life Pilot';

  // ─────────────── 語系設定 ───────────────
  static const List<Locale> supportedLocales = [
    Locale(Locales.en),
    Locale(Locales.zh),
    Locale(Locales.ja),
    Locale(Locales.ko),
  ];

  static const List<LocalizationsDelegate<dynamic>> localizationDelegates = [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  // ─────────────── API Keys ───────────────
  static const String googleApiKey =
    'AIzaSyAMnaz88TnK9p4hJ31hGZuOlu43gxVx8Ik'; // <-- 金鑰
}

// 🔑 Supabase 設定
@immutable
class SupabaseConfig {
  const SupabaseConfig._();
  static const url = 'https://ccktdpycnferbrjrdtkp.supabase.co';
  static const anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNja3RkcHljbmZlcmJyanJkdGtwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTMyNTU0NTIsImV4cCI6MjA2ODgzMTQ1Mn0.jsuY3AvuhRlCwuGKmcq_hyj1ViLRX18kmQs5YYnFwR4';
}

// 📅 時區與節慶設定
@immutable
class CalendarConfig {
  const CalendarConfig._();

  static String tzLocation = 'Asia/Taipei';

  static const List<String> taiwanHolidays = [
    "元旦",
    "春節",
    "除夕",
    "和平紀念日",
    "兒童節",
    "清明節",
    "勞動節",
    "端午節",
    "教師節",
    "中秋節",
    "國慶日",
    "台灣光復節",
    "行憲紀念日",
  ];
}

// 🌐 語系代碼常數
@immutable
class Locales {
  const Locales._();

  static const zh = 'zh';
  static const en = 'en';
  static const ja = 'ja';
  static const ko = 'ko';

  static const defaultLocale = Locale(zh);
}

/*改進重點說明
✅ 使用 @immutable + 私有建構子	const AppConfig._()	保證類別不可被 new，也更語義化（只作為常數容器）
✅ 分層清楚	AppConfig / SupabaseConfig / CalendarConfig / Locales	模組化結構，減少耦合、提高可維護性
✅ 明確命名常數	defaultTimeZone、defaultLocale	可讀性更高，避免 magic string
✅ 移除不必要 runtime 初始化	全部為 const	Flutter 編譯器可進行 compile-time 常量內聯，效能最佳化*/