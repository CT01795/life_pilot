class ServiceModule {
  static final ServiceModule _instance = ServiceModule._internal();
  factory ServiceModule() => _instance;
  ServiceModule._internal();

  final Map<String, bool> _moduleStatus = {};

  Future<void> loadModulesFromServer(String userId) async {
    // TODO: 從 Firebase/Supabase 取得啟用模組資料
    _moduleStatus['personal_event'] = true;
    _moduleStatus['ai'] = false;
  }

  bool isModuleEnabled(String moduleName) {
    return _moduleStatus[moduleName] ?? false;
  }

  List<String> get enabledModules =>
      _moduleStatus.entries.where((e) => e.value).map((e) => e.key).toList();
}
