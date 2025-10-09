import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/controller_auth.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/models/model_event_item.dart';
import 'package:life_pilot/models/model_event_base.dart';
import 'package:life_pilot/my_app.dart';
import 'package:life_pilot/notification/core/reminder_option.dart';
import 'package:life_pilot/notification/notification_entry.dart';
import 'package:life_pilot/pages/page_event_add.dart';

import 'package:life_pilot/services/service_storage.dart';
import 'package:life_pilot/utils/core/utils_const.dart';
import 'package:life_pilot/utils/core/utils_enum.dart';
import 'package:life_pilot/utils/core/utils_locator.dart';
import 'package:life_pilot/utils/utils_common_function.dart';
import 'package:life_pilot/utils/utils_date_time.dart';

// ControllerEvent → 整體事件管理、查詢、刪除、UI通知  
// EventController → 單筆事件顯示的欄位包裝（提供 View 用的 getter）
class ControllerEvent extends ChangeNotifier {
  final String tableName;
  final String? toTableName;
  final List<EventItem> _events = [];
  final Set<String> selectedEventIds = {};
  final Set<String> removedEventIds = {};

  final TextEditingController searchController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  String searchKeywords = constEmpty;
  DateTime? startDate;
  DateTime? endDate;
  bool showSearchPanel = false;

  ControllerEvent({required this.tableName, this.toTableName});

  List<EventItem> get filteredEvents {
    final keywords = searchKeywords
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();

    return _events.where((e) {
      if (removedEventIds.contains(e.id)) return false;

      bool matchesKeywords = keywords.every((word) {
        return e.city.toLowerCase().contains(word) ||
            e.location.toLowerCase().contains(word) ||
            e.name.toLowerCase().contains(word) ||
            e.type.toLowerCase().contains(word) ||
            e.description.toLowerCase().contains(word) ||
            e.fee.toLowerCase().contains(word) ||
            e.unit.toLowerCase().contains(word) ||
            e.subEvents.any(
              (se) =>
                  se.city.toLowerCase().contains(word) ||
                  se.location.toLowerCase().contains(word) ||
                  se.name.toLowerCase().contains(word) ||
                  se.type.toLowerCase().contains(word) ||
                  se.description.toLowerCase().contains(word) ||
                  se.fee.toLowerCase().contains(word) ||
                  se.unit.toLowerCase().contains(word),
            );
      });

      e.endDate = e.endDate ?? e.startDate;
      e.endTime = e.endTime ?? e.startTime;
      bool matchesDate = true;
      if (startDate != null &&
          e.endDate != null &&
          e.endDate!.isBefore(startDate!)) {
        matchesDate = false;
      }
      if (endDate != null &&
          e.startDate != null &&
          e.startDate!.isAfter(endDate!)) {
        matchesDate = false;
      }

      return matchesKeywords && matchesDate;
    }).toList();
  }

  void setEvents({required List<EventItem> events}) {
    _events
      ..clear()
      ..addAll(events);
    notifyListeners();
  }

  Future<void> loadEvents() async {
    final service = getIt<ServiceStorage>();
    final auth = getIt<ControllerAuth>();

    final data = await service.getEvents(
      tableName: tableName,
      inputUser: auth.currentAccount,
    );

    if (data != null) {
      setEvents(events: data);
    }
  }

  void toggleSearchPanel({required bool value}) {
    showSearchPanel = value;
    if (!value) clearSearchFilters();
    notifyListeners();
  }

  void clearSearchFilters() {
    searchKeywords = constEmpty;
    startDate = null;
    endDate = null;
    searchController.clear();
    notifyListeners();
  }

  void updateSearch({required String keywords}) {
    searchKeywords = keywords;
    notifyListeners();
  }

  void updateStartDate({DateTime? date}) {
    startDate = date;
    notifyListeners();
  }

  void updateEndDate({DateTime? date}) {
    endDate = date;
    notifyListeners();
  }

  Future<void> onAddEvent() async {
    final newEvent = await navigatorKey.currentState!.push<EventItem?>(
      MaterialPageRoute(
        builder: (_) => PageEventAdd(tableName: tableName),
      ),
    );
    if (newEvent != null) {
      await loadEvents();
    }
  }

  // ✅ 刪除事件，並更新列表與通知 UI
  Future<void> deleteEvent(EventItem event, AppLocalizations loc) async {
    try {
      final service = getIt<ServiceStorage>();
      await NotificationEntryImpl.cancelEventReminders(event: event);
      await service.deleteEvent(event: event, tableName: tableName);

      // ✅ 從本地事件列表中移除
      _events.removeWhere((e) => e.id == event.id);

      notifyListeners(); // ✅ 通知畫面更新
      showSnackBar(message: loc.delete_ok);
    } catch (e, stacktrace) {
      logger.e("deleteEvent error", error: e, stackTrace: stacktrace);
      showSnackBar(message: '${loc.delete_error}: $e');
    }
  }

  EventController eventController(var event) => EventController(event);

  @override
  void dispose() {
    searchController.dispose();
    scrollController.dispose();
    super.dispose();
  }
}

// EventController → 單筆事件顯示的欄位包裝（提供 View 用的 getter）
class EventController {
  final EventBase event;
  EventController(this.event);

  String get name => event.name;
  String? get masterGraphUrl => event.masterGraphUrl;
  String? get masterUrl => event.masterUrl;
  DateTime? get startDate => event.startDate;
  DateTime? get endDate => event.endDate;
  TimeOfDay? get startTime => event.startTime;
  TimeOfDay? get endTime => event.endTime;
  String get city => event.city;
  String get location => event.location;
  String get type => event.type;
  String get description => event.description;
  String get fee => event.fee;
  String get unit => event.unit;
  String? get account => event.account;
  RepeatRule get repeatOptions => event.repeatOptions;
  List<ReminderOption> get reminderOptions => event.reminderOptions;
  bool get isHoliday => event.isHoliday;
  bool get isTaiwanHoliday => event.isTaiwanHoliday;
  bool get isApproved => event.isApproved;

  bool get hasLocation => event.city.isNotEmpty || event.location.isNotEmpty;
  String get dateRange =>
      '${formatEventDateTime(event, constStartToS)}${formatEventDateTime(event, constEndToE)}';

  List<EventItem> get subEvents => event.subEvents;
}
