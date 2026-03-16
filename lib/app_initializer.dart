import 'package:firebase_core/firebase_core.dart';
import 'package:life_pilot/app/config_app.dart';
import 'package:life_pilot/firebase_options.dart';
import 'package:life_pilot/utils/service/service_timezone.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppInitializer {
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // ✅ 初始化時區
    CalendarConfig.tzLocation =
        await ServiceTimezone().setTimezoneFromDevice(); // ✅ 自動偵測並設定時區

    // ✅ 初始化 Firebase、Supabase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
      debug: true, // 可選，用於除錯
    );

    final supabase = Supabase.instance.client;
    // ✅ 自動匿名登入，如果沒有 session 就登入
    if (supabase.auth.currentSession == null) {
      await supabase.auth.signInAnonymously();
    }
  }
}