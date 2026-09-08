import 'package:flutter/foundation.dart';
import 'package:life_pilot/apps/config_app.dart';
import 'package:life_pilot/utils/service/service_timezone.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppInitializer {
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    // ✅ 初始化時區
    final timezoneFuture = ServiceTimezone().setTimezoneFromDevice();
    final supabaseFuture = Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
      debug: kDebugMode,
    );
    final results = await Future.wait<Object?>([
      timezoneFuture,
      supabaseFuture,
    ]);
    CalendarConfig.tzLocation = results.first as String;
    _initialized = true;
  }
}
