import 'package:flutter/material.dart' hide DateUtils;
import 'package:life_pilot/controllers/controller_calendar.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/models/model_event_item.dart';
import 'package:life_pilot/notification/core/notification_helper.dart';
import 'package:life_pilot/pages/page_event_add.dart';
import 'package:life_pilot/utils/core/utils_locator.dart';
import 'package:life_pilot/utils/utils_date_time.dart';

class ControllerCalendarView extends ChangeNotifier {
  final ControllerCalendar _dataController = getIt<ControllerCalendar>();
  late AppLocalizations loc;

  bool _isInitialized = false;
  bool _isDisposed = false;

  @override
  void dispose() {
    _dataController.removeListener(_onDataChanged); // 解除綁定
    _isDisposed = true;
    super.dispose();
  }

  void _onDataChanged() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  ControllerCalendarView() {
    _dataController.addListener(_onDataChanged); // ✅ 將內部 controller 的變化轉發給 UI
  }

  ControllerCalendar get data => _dataController;

  Future<void> init(AppLocalizations localization) async {
    loc = localization;
    if (_isInitialized) return;
    _isInitialized = true;
    await _dataController.loadCalendarEvents(notify: false);
    Future.microtask(() async {
      if (_isDisposed) return; // ✅ 防止異步操作觸發已銷毀物件
      await NotificationHelper.notifyTodayEvents(loc: loc);
      if (_isDisposed) return; // ✅ 防止異步操作觸發已銷毀物件
      await _dataController.checkAndGenerateNextEvents(loc: loc);
    });
  }

  Future<void> goToPreviousMonth() async {
    final current = _dataController.currentMonth;
    await _dataController.goToMonth(
      month: DateTime(current.year, current.month - 1),
    );
  }

  Future<void> goToNextMonth() async {
    final current = _dataController.currentMonth;
    await _dataController.goToMonth(
      month: DateTime(current.year, current.month + 1),
    );
  }

  Future<void> goToToday() async {
    await _dataController.goToMonth(
      month: DateUtils.dateOnly(DateTime.now()),
    );
  }

  Future<void> jumpToMonth(DateTime newMonth) async {
    await _dataController.goToMonth(month: newMonth);
  }

  Future<void> addEvent(BuildContext context) async {
    final currentMonth = _dataController.currentMonth;
    final tableName = _dataController.tableName;

    final newEvent = await Navigator.push<EventItem?>(
      context,
      MaterialPageRoute(
        builder: (_) => PageEventAdd(
          existingEvent: null,
          tableName: tableName,
          initialDate: currentMonth.month == DateTime.now().month
              ? DateTime.now()
              : currentMonth,
        ),
      ),
    );

    if (newEvent != null) {
      _dataController.updateCachedEvent(event: newEvent);
      await _dataController.goToMonth(
        month: DateUtils.monthOnly(newEvent.startDate!),
      );
    }
  }
}
