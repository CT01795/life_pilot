import 'package:supabase_flutter/supabase_flutter.dart';

class ServiceModule {
  final client = Supabase.instance.client;
  ServiceModule();

  // ✅ 載入模組啟用狀態（實作可替換為從 Firebase/Supabase 拉）
  Future<List<String>> loadModulesFromServer(String account) async {
    final response = await client
      .from('user_module')
      .select('module_key')
      .eq('account', account)
      .or('stop_at.is.null,stop_at.gt.${DateTime.now().toIso8601String()}'); // ✅ 新版 SDK 必須 execute()

      // data 可能為 null
      final data = response as List<dynamic>?;
      if (data == null) return [];

      // 轉成 List<String>
      return data.map((e) => e['module_key'] as String).toList();
  }
}
