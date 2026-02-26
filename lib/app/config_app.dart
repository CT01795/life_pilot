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