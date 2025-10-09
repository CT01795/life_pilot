import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/controller_auth.dart';
import 'package:life_pilot/controllers/controller_calendar.dart';
import 'package:life_pilot/controllers/controller_event.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/core/utils_locator.dart';
import 'package:life_pilot/models/model_event_item.dart';
import 'package:life_pilot/my_app.dart';
import 'package:life_pilot/notification/notification_entry.dart';
import 'package:life_pilot/pages/page_event_add.dart';
import 'package:life_pilot/services/service_storage.dart';
import 'package:life_pilot/utils/utils_common_function.dart';
import 'package:life_pilot/utils/core/utils_const.dart';
import 'package:life_pilot/utils/widget/utils_event_widgets.dart';
import 'package:life_pilot/utils/dialog/utils_show_dialog.dart';
import 'package:life_pilot/views/widgets/event/widgets_event_card.dart';
import 'package:life_pilot/views/widgets/event/widgets_event_dialog.dart';
import '../export/export_entry.dart';
import 'platform/utils_mobile.dart';

// --- Build White AppBar ---
AppBar buildWhiteAppBar({
  required String title,
  bool enableSearchAndExport = false,
  required AppBarActionsHandler handler,
  required void Function(void Function()) setState,
  VoidCallback? onAdd,
  required String tableName,
  required AppLocalizations loc,
}) {
  return AppBar(
      title: Text(constEmpty),
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 0,
      actions: buildAppBarActions(
        enableSearchAndExport: enableSearchAndExport,
        handler: handler,
        setState: setState,
        onAdd: onAdd,
        tableName: tableName,
        loc: loc
      ));
}

// --- Build AppBar Actions ---
List<Widget> buildAppBarActions({
  required bool enableSearchAndExport,
  required AppBarActionsHandler handler,
  required void Function(VoidCallback fn) setState,
  VoidCallback? onAdd,
  required String tableName,
  required AppLocalizations loc,
}) {
  List<Widget> actions = [];

  if (enableSearchAndExport) {
    actions.addAll(
      [IconButton(
        icon: const Icon(Icons.search),
        tooltip: loc.search,
        onPressed: handler.onSearchToggle,
      ),
      IconButton(
        icon: const Icon(Icons.download),
        tooltip: loc.export_excel,
        onPressed: () => handler.onExport(),
      )]
    );
  }
  if (onAdd != null) {
    actions.add(IconButton(
      icon: const Icon(Icons.add),
      tooltip: loc.event_add,
      onPressed: onAdd,
    ));
  }

  return actions;
}

// --- AppBar Actions Handler Class ---
class AppBarActionsHandler {
  final void Function(void Function()) setState;

  bool Function() showSearchPanelGetter;

  final void Function(bool) onToggleShowSearch;

  // ✅ 模組化新增：共用 tableName、_events 狀態
  final String tableName;
  final void Function(List<EventItem>) updateEvents;

  ControllerAuth get _auth => getIt<ControllerAuth>();
  AppLocalizations loc;
  ServiceStorage get service => getIt<ServiceStorage>();
  AppBarActionsHandler({
    required this.setState,
    required this.showSearchPanelGetter,
    required this.onToggleShowSearch,
    required this.tableName,
    required this.updateEvents,
    required this.loc,
  });

  void onSearchToggle() {
    setState(() {
      onToggleShowSearch(!showSearchPanelGetter());
    });
  }

  Future<void> refreshCallback() async {
    try {
      final events = await loadEvents(tableName: tableName);
      // ✅ 更新外部頁面事件狀態
      setState(() {
        updateEvents(events);
      });
    } catch (e) {
      showSnackBar(message: "Failed to load events: $e");
    }
  }

  Future<void> onExport() async {
    try {
      final events = await service.getEvents(
          tableName: tableName, inputUser: _auth.currentAccount);
      if (events == null || events.isEmpty) {
        showSnackBar(message: loc.no_events_to_export);
        return;
      }
      await exportEventsToExcel(events: events, loc: loc);
    } catch (e) {
      showSnackBar(message: "${loc.export_failed}：$e");
    }
  }
}

// --- Build Search Panel Widget ---
Widget buildSearchPanel({
  required TextEditingController searchController,
  required String searchKeywords,
  required void Function(String) onSearchKeywordsChanged,
  required void Function(void Function()) setState,

  // 新增這三個參數為 optional
  DateTime? startDate,
  DateTime? endDate,
  void Function(DateTime?)? onStartDateChanged,
  void Function(DateTime?)? onEndDateChanged,
  required String tableName,
  required AppLocalizations loc,
}) {
  return Padding(
    padding: kGapEI12,
    child: Column(
      children: [
        // 🔍 關鍵字搜尋框
        TextField(
          controller: searchController,
          decoration: InputDecoration(
            hintText: loc.search_keywords,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: searchKeywords.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: loc.clear,
                    onPressed: () {
                      setState(() {
                        onSearchKeywordsChanged(constEmpty);
                        searchController.clear();
                      });
                    },
                  )
                : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onChanged: (value) {
            setState(() {
              onSearchKeywordsChanged(value.trim());
            });
          },
        ),

        // 📅 日期篩選（可選擇性顯示）
        if (tableName != constTableRecommendedAttractions &&
            onStartDateChanged != null &&
            onEndDateChanged != null) ...[
          kGapH8(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: widgetBuildDateButton(
                  date: startDate,
                  label: loc.start_date,
                  icon: Icons.date_range,
                  onDateChanged: onStartDateChanged,
                  loc: loc
                ),
              ),
              kGapW16(),
              Expanded(
                child: widgetBuildDateButton(
                  date: endDate,
                  label: loc.end_date,
                  icon: Icons.date_range,
                  onDateChanged: onEndDateChanged,
                  loc: loc
                ),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}

// ------------------------------
// ✅ 共用 Trailing Checkbox & Edit 按鈕
// ------------------------------
Widget buildEventTrailing({
  required EventItem event,
  required void Function(void Function()) setState,
  required VoidCallback refreshCallback,
  required String tableName,
  required String toTableName,
  required AppLocalizations loc,
}) {
  ControllerCalendar controller = getIt<ControllerCalendar>();
  final auth = getIt<ControllerAuth>();
  final service = getIt<ServiceStorage>();

  return StatefulBuilder(builder: (context, localSetState) {
    return Transform.scale(
      scale: 1.2,
      child: Row(
        children: [
          if (!auth.isAnonymous && tableName != constTableMemoryTrace)
            Checkbox(
              value: false,
              onChanged: (value) async {
                await handleCheckboxChanged(
                  value: value,
                  event: event,
                  setState: (fn) {
                    fn();
                    localSetState(() {});
                  },
                  addedMessage: loc.event_add_ok,
                  tableName: tableName,
                  toTableName: toTableName,
                  loc: loc
                );
              },
            ),
          if (tableName == constTableCalendarEvents && !event.isHoliday)
            // ⏰ 鬧鐘
            IconButton(
              icon: Icon(
                event.reminderOptions.isNotEmpty
                    ? Icons.alarm_on_rounded
                    : Icons.alarm_rounded,
                size: event.reminderOptions.isNotEmpty
                    ? IconTheme.of(context).size! * 1.2
                    : IconTheme.of(context).size!,
                color: event.reminderOptions.isNotEmpty
                    ? Colors.blue
                    : Colors.black,
              ),
              tooltip: loc.set_alarm,
              onPressed: () async {
                final updated =
                    await showAlarmSettingsDialog(event: event, loc: loc);

                if (updated) {
                  // 有更新鬧鐘設定，重新載入事件並刷新 UI
                  await controller.loadCalendarEvents();
                  // 呼叫 setState 讓 Dialog 內容重新渲染（Dialog 內部 StatefulBuilder）
                  // 這裡簡單用 Navigator.pop 讓 Dialog 關閉，然後重新開啟，或用 setState 刷新列表
                  await NotificationEntryImpl.cancelEventReminders(
                      event: event); // 取消舊通知
                  await checkExactAlarmPermission();
                  await NotificationEntryImpl.scheduleEventReminders(
                      event: event, tableName: controller.tableName, loc: loc); // 安排新通知
                  Navigator.pop(context); // 關閉事件 Dialog，回到上一頁
                }
              },
            ),
          if (auth.currentAccount == event.account)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: loc.edit,
              onPressed: () => onEditEvent(
                event: event,
                setState: setState,
                refreshCallback: refreshCallback,
                tableName: tableName,
              ),
            ),
          if (tableName != constTableCalendarEvents &&
              tableName != constTableMemoryTrace &&
              !event.isApproved &&
              auth.currentAccount == constSysAdminEmail)
            IconButton(
              icon: const Icon(Icons.task_alt),
              tooltip: loc.review,
              onPressed: () async {
                setState(() {
                  event.isApproved = true;
                });
                await service.approvalEvent(
                  event: event,
                  tableName: tableName,
                );
              },
            ),
          kGapW24(),
        ],
      ),
    );
  });
}

// ------------------------------
// 📋 Event ListView / GridView
// ------------------------------
class EventList extends StatelessWidget {
  final List<EventItem> filteredEvents;
  final Set<String> selectedEventIds;
  final Set<String> removedEventIds;
  final ServiceStorage? serviceStorage;
  final void Function(void Function()) setState;
  final ScrollController scrollController;
  final VoidCallback refreshCallback;
  final String tableName;
  final String toTableName;
  final ControllerEvent controllerEvent;

  const EventList({
    super.key,
    required this.filteredEvents,
    required this.selectedEventIds,
    required this.removedEventIds,
    this.serviceStorage,
    required this.setState,
    required this.scrollController,
    required this.refreshCallback,
    required this.tableName,
    required this.toTableName,
    required this.controllerEvent
  });

  @override
  Widget build(BuildContext context) {
    final auth = getIt<ControllerAuth>();
    AppLocalizations loc = AppLocalizations.of(context)!;
    return ListView.builder(
      key: PageStorageKey(tableName), //'recommended_event_list'
      controller: scrollController,
      itemCount: filteredEvents.length,
      itemBuilder: (context, index) {
        final event = filteredEvents[index];
        final trailing = buildEventTrailing(
          event: event,
          setState: setState,
          refreshCallback: refreshCallback,
          tableName: tableName,
          toTableName: toTableName,
          loc: loc,
        );

        return WidgetsEventCard(
          eventController: controllerEvent.eventController(event),
          tableName: tableName,
          index: index,
          onTap: () {
            showDialog(
              context: context,
              barrierDismissible: true,
              barrierColor: const Color.fromARGB(200, 128, 128, 128), // 透明灰
              builder: (_) =>
                  WidgetsEventDialog(tableName: tableName, eventController: controllerEvent.eventController(event)),
            );
          },
          onDelete: auth.currentAccount == event.account ||
                  (auth.currentAccount == constSysAdminEmail &&
                      tableName != constTableMemoryTrace)
              ? () async {
                final shouldDelete = await showConfirmationDialog(
                  content: '${loc.event_delete}「${event.name}」？',
                  confirmText: loc.delete,
                  cancelText: loc.cancel,
                );
                if (shouldDelete == true) {
                  await controllerEvent.deleteEvent(event, loc); // ✅ 使用封裝後的刪除邏輯
                }
              }
              : null,
          trailing: trailing,
          showSubEvents: false,
        );
      },
    );
  }
}

// ------------------------------
// ✅ Utility Functions
// ------------------------------
Future<void> onEditEvent({
  required EventItem event,
  required void Function(void Function()) setState,
  required VoidCallback refreshCallback,
  required String tableName,
}) async {
  final updatedEvent = await navigatorKey.currentState!.push<EventItem?>(
    MaterialPageRoute(
      builder: (_) => PageEventAdd(
        existingEvent: event,
        tableName: tableName,
      ),
    ),
  );

  if (updatedEvent != null) {
    refreshCallback();
  }
}

void scrollToEventById({
  required List<EventItem> events,
  required ScrollController scrollController,
  required String eventId,
  double itemHeight = 120.0,
}) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final index = events.indexWhere((e) => e.id == eventId);
    if (index != -1) {
      final position = index * itemHeight;

      if (scrollController.hasClients) {
        scrollController.animateTo(
          position,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  });
}
