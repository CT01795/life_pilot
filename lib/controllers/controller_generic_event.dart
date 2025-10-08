import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/controller_auth.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/models/model_event.dart';
import 'package:life_pilot/my_app.dart';
import 'package:life_pilot/notification/notification_entry.dart';
import 'package:life_pilot/pages/page_event_add.dart';

import 'package:life_pilot/services/service_storage.dart';
import 'package:life_pilot/utils/core/utils_const.dart';
import 'package:life_pilot/utils/core/utils_locator.dart';
import 'package:life_pilot/utils/utils_common_function.dart';

class ControllerGenericEvent extends ChangeNotifier {
  final String tableName;
  final String? toTableName;
  final List<Event> _events = [];
  final Set<String> selectedEventIds = {};
  final Set<String> removedEventIds = {};

  final TextEditingController searchController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  String searchKeywords = constEmpty;
  DateTime? startDate;
  DateTime? endDate;
  bool showSearchPanel = false;

  ControllerGenericEvent({required this.tableName, this.toTableName});

  List<Event> get filteredEvents {
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

  void setEvents({required List<Event> events}) {
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
    final newEvent = await navigatorKey.currentState!.push<Event?>(
      MaterialPageRoute(
        builder: (_) => PageEventAdd(tableName: tableName),
      ),
    );
    if (newEvent != null) {
      await loadEvents();
    }
  }

  // ✅ 刪除事件，並更新列表與通知 UI
  Future<void> deleteEvent(Event event, AppLocalizations loc) async {
    try {
      final service = getIt<ServiceStorage>();
      await NotificationEntryImpl.cancelEventReminders(event: event);
      await service.deleteEvent(event: event, tableName: tableName);

      // ✅ 從本地事件列表中移除
      _events.removeWhere((e) => e.id == event.id);
      filteredEvents.removeWhere((e) => e.id == event.id);

      notifyListeners(); // ✅ 通知畫面更新
      showSnackBar(message: loc.delete_ok);
    } catch (e, stacktrace) {
      logger.e("deleteEvent error", error: e, stackTrace: stacktrace);
      showSnackBar(message: '${loc.delete_error}: $e');
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    scrollController.dispose();
    super.dispose();
  }
}
