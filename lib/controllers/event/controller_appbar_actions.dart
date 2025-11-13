import 'dart:async';

import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/auth/controller_auth.dart';
import 'package:life_pilot/models/event/model_event_calendar.dart';
import 'package:life_pilot/controllers/event/controller_event.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/core/logger.dart';
import 'package:life_pilot/services/event/service_event.dart';
import 'package:life_pilot/services/export/service_export_excel.dart';
import 'package:life_pilot/services/export/service_export_platform.dart';

class ControllerAppBarActions extends ChangeNotifier {
  final ControllerAuth auth;
  final ServiceEvent serviceEvent;
  final ControllerEvent controllerEvent;
  final ModelEventCalendar modelEventCalendar;
  final ServiceExportPlatform exportService;
  final ServiceExportExcel excelService;
  final String tableName;

  ControllerAppBarActions({
    required this.auth,
    required this.serviceEvent,
    required this.controllerEvent,
    required this.modelEventCalendar,
    required this.exportService,
    required this.excelService,
    required this.tableName,
  });

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isExporting = false;
  bool get isExporting => _isExporting;

  Timer? _debounce;

  /// ✅ Debounce 用，減少頻繁通知（例如快速開關搜尋面板）
  void _notifyDebounced() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), () {
      notifyListeners();
    });
  }

  // ✅ 切換搜尋面板顯示/隱藏
  void toggleSearchPanel() {
    modelEventCalendar.toggleSearchPanel(!modelEventCalendar.showSearchPanel);
    _notifyDebounced();
  }

  // ✅ 重新整理事件資料
  Future<bool> refreshEvents() async {
    if (_isLoading) return false;
    _setLoading(true);

    try {
      await controllerEvent.loadEvents();
      logger.i('✅ Events refreshed successfully');
      return true;
    } catch (e, s) {
      logger.e('❌ refreshEvents error: $e', stackTrace: s);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ✅ 匯出事件為 Excel
  Future<String> exportEvents(AppLocalizations loc) async {
    if (_isExporting) return loc.exportInProgress;
    _setExporting(true);
    try {
      final events = await serviceEvent.getEvents(
          tableName: tableName, inputUser: auth.currentAccount);
      if (events == null || events.isEmpty) {
        return loc.noEventsToExport;
      }
      final bytes = excelService.buildExcelBytes(events, loc);
      final filename = 'events_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final filePath = await exportService.exportFile(filename, bytes);
      // 5️⃣ 根據結果回傳 enum 給 UI 層
      return '${loc.exportSuccess}: $filePath';
    } catch (e, s) {
      logger.e('❌ exportEvents error: $e', stackTrace: s);
      return '${loc.exportFailed}: $e';
    } finally {
      _setExporting(false);
    }
  }

  // --- 狀態管理 ---
  void _setLoading(bool value) {
    if (_isLoading == value) return;
    _isLoading = value;
    notifyListeners();
  }

  void _setExporting(bool value) {
    if (_isExporting == value) return;
    _isExporting = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

/*🚀 優化重點總結
✅ Debounce 通知	使用 _notifyDebounced() 減少 UI rebuild（例如快速切換搜尋面板）
✅ 狀態管理	加入 _isLoading、_isExporting 兩個旗標，可讓 UI 顯示「載入中」或「匯出中」
✅ 例外處理更完整	捕捉 stackTrace 並記錄在 logger
✅ 程式結構清晰	_setLoading() / _setExporting() 統一管理狀態更新*/