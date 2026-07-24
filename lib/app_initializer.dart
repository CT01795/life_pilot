
import 'package:life_pilot/apps/config_app.dart';
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

    // ✅ 初始化 Supabase
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
      debug: true, // 可選，用於除錯
    );
  }
}