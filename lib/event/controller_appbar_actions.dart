import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/event/model_event.dart';
import 'package:life_pilot/event/service_event.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/utils/service/export/service_export_excel.dart';
import 'package:life_pilot/utils/service/export/service_export_platform.dart';
import 'package:file_picker/file_picker.dart';
import 'package:charset/charset.dart';
import 'package:uuid/uuid.dart';
import 'package:excel/excel.dart';

class ControllerAppBarActions extends ChangeNotifier {
  final ControllerAuth auth;
  final ServiceEvent _serviceEvent;
  final ModelEvent _modelEvent;
  final ServiceExportPlatform _exportService;
  final ServiceExportExcel _excelService;
  final String _tableName;

  ControllerAppBarActions({
    required this.auth,
    required ServiceEvent serviceEvent,
    required ModelEvent modelEvent,
    required ServiceExportPlatform exportService,
    required ServiceExportExcel excelService,
    required String tableName,
  })  : _tableName = tableName,
        _serviceEvent = serviceEvent,
        _modelEvent = modelEvent,
        _excelService = excelService,
        _exportService = exportService;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isExporting = false;
  bool get isExporting => _isExporting;

  bool _isUploading = false;
  bool get isUploading => _isUploading;

  Timer? _debounce;

  /// ✅ Debounce 用，減少頻繁通知（例如快速開關搜尋面板）
  void _notifyDebounced() {
    if (_disposed) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), () {
      if (!_disposed) notifyListeners();
    });
  }

  // ✅ 切換搜尋面板顯示/隱藏
  void toggleSearchPanel() {
    _modelEvent.toggleSearchPanel(!_modelEvent.showSearchPanel);
    _notifyDebounced();
  }

  // ✅ 重新整理事件資料
  Future<bool> refreshEvents() async {
    if (_isLoading || _disposed) return false;
    _setState(loading: true);

    try {
      final list = await _serviceEvent.getEvents(
        tableName: _tableName,
        inputUser: auth.currentAccount,
      );
      _modelEvent.setEvents(list ?? []);

      logger.i('✅ Events refreshed successfully');
      return true;
    } catch (e, s) {
      logger.e('❌ refreshEvents error: $e', stackTrace: s);
      return false;
    } finally {
      if (!_disposed) _setState(loading: false);
    }
  }

  // ✅ 使用Excel 上傳事件
  Future<String> uploadEvents(AppLocalizations loc) async {
    if (_isUploading) return loc.exportInProgress;
    _setState(uploading: true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx'],
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return loc.uploadFailed;
      final file = result.files.first;
      var bytes = result.files.first.bytes;
      // 如果 bytes 為 null，嘗試用 path 讀
      if ((bytes == null || bytes.isEmpty) && result.files.first.path != null) {
        bytes = await File(result.files.first.path!).readAsBytes();
      }

      // bytes 還是 null 才回傳失敗
      if (bytes == null || bytes.isEmpty) return loc.uploadFailed;

      final filename = file.name.toLowerCase();
      List<EventItem> events = [];
      if (filename.endsWith('.csv')) {
        String csv;
        try {
          csv = utf8.decode(bytes);
        } catch (e, s) {
          logger.e('❌ utf8 decode error: $e', stackTrace: s);
          csv = Charset.getByName('big5')!.decode(bytes);
        }
        events = _excelService.parseCsv(csv, loc);
      } else if (filename.endsWith('.xlsx')) {
        final excel = Excel.decodeBytes(bytes);
        final sheet = excel.tables.values.first;
        events = _excelService.parseExcel(sheet, loc);
      }

      if (events.isEmpty) {
        return loc.noEventsToUpload;
      }

      // 3. 更新 / 新增
      EventItem? tmpMaster;
      List<EventItem>? eventList;
      for (final event in events) {
        if (!event.name.startsWith("  └")) {
          tmpMaster = event;
          eventList = await _serviceEvent.getEvents(
              tableName: _tableName, id: event.id.isNotEmpty ? event.id : null);
          await _serviceEvent.saveEvent(
              currentAccount: auth.currentAccount ?? '',
              event: event,
              isNew: eventList == null || eventList.isEmpty,
              tableName: _tableName);
        } else {
          event.name = event.name.replaceAll("  └ ", "");
          event.id = event.id.isNotEmpty ? event.id : Uuid().v4();
          tmpMaster!.subEvents.add(event);
          await _serviceEvent.saveEvent(
              currentAccount: auth.currentAccount ?? '',
              event: tmpMaster,
              isNew: false,
              tableName: _tableName);
        }
      }
      await refreshEvents();
      return loc.uploadSuccess;
    } catch (e, s) {
      logger.e('❌ uploadEventsFromExcel error: $e', stackTrace: s);
      return '${loc.uploadFailed}: $e';
    } finally {
      _setState(uploading: false);
    }
  }

  // ✅ 匯出事件為 Excel
  Future<String> exportEvents(AppLocalizations loc) async {
    if (_isExporting) return loc.exportInProgress;
    _setState(exporting: true);
    try {
      final events = await _serviceEvent
          .getEvents(tableName: _tableName, inputUser: auth.currentAccount);
      if (events == null || events.isEmpty) {
        return loc.noEventsToExport;
      }
      final bytes = _excelService.buildExcelBytes(events, loc);
      final filename = 'events_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final filePath = await _exportService.exportFile(filename, bytes);
      // 5️⃣ 根據結果回傳 enum 給 UI 層
      return '${loc.exportSuccess}: $filePath';
    } catch (e, s) {
      logger.e('❌ exportEvents error: $e', stackTrace: s);
      return '${loc.exportFailed}: $e';
    } finally {
      _setState(exporting: false);
    }
  }

  // --- 狀態管理 ---
  void _setState({bool? loading, bool? exporting, bool? uploading}) {
    if (_disposed) return;
    bool changed = false;

    if (loading != null && loading != _isLoading) {
      _isLoading = loading;
      changed = true;
    }
    if (exporting != null && exporting != _isExporting) {
      _isExporting = exporting;
      changed = true;
    }
    if (uploading != null && uploading != _isUploading) {
      _isUploading = uploading;
      changed = true;
    }

    if (changed) notifyListeners();
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    super.dispose();
  }
}
