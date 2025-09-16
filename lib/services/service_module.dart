import 'package:life_pilot/pages/page_type.dart';

class ServiceModule {
  static final ServiceModule _instance = ServiceModule._internal();
  factory ServiceModule() => _instance;
  ServiceModule._internal();

  final Map<PageType, bool> _moduleStatus = {};

  // ✅ 載入模組啟用狀態（實作可替換為從 Firebase/Supabase 拉）
  Future<void> loadModulesFromServer(String userId) async {
    // ⚠️ TODO: 改為實際從資料庫取得使用者模組啟用資訊
    _moduleStatus.clear();
    _moduleStatus[PageType.personalEvent] = true;
    _moduleStatus[PageType.ai] = false;
  }

  // ✅ 查詢某個模組是否啟用
  bool isModuleEnabled(PageType module) {
    return _moduleStatus[module] ?? false;
  }

  // ✅ 取得所有已啟用模組
  List<PageType> get enabledModules =>
      _moduleStatus.entries.where((e) => e.value).map((e) => e.key).toList();

  // ✅ 更新某個模組狀態（例如 admin 或 debug 用）
  void setModuleStatus(PageType module, bool isEnabled) {
    _moduleStatus[module] = isEnabled;
  }

  // ✅ 清除所有模組狀態（可用於登出或重設）
  void reset() {
    _moduleStatus.clear();
  }
}
