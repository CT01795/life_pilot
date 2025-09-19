import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/controller_auth.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/models/model_event.dart';
import 'package:life_pilot/pages/page_recommended_event_add.dart';
import 'package:life_pilot/services/service_storage.dart';
import 'package:life_pilot/utils/utils_event_card.dart';
import 'package:life_pilot/utils/utils_common_function.dart';
import 'package:life_pilot/utils/utils_const.dart';
import 'package:life_pilot/utils/utils_event_widgets.dart';
import 'package:provider/provider.dart';

import '../export/export.dart';

// --- Build White AppBar ---
AppBar buildWhiteAppBar(
  BuildContext context, {
  required String title,
  bool enableSearchAndExport = false,
  required bool isGridView,
  required AppBarActionsHandler handler,
  required void Function(void Function()) setState,
  required bool isEditable,
  VoidCallback? onAdd,
  required String tableName,
}) {
  return AppBar(
      title: Text(constEmpty),
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 0,
      actions: buildAppBarActions(
        context,
        enableSearchAndExport: enableSearchAndExport,
        isGridView: isGridView,
        handler: handler,
        setState: setState,
        isEditable: isEditable,
        onAdd: onAdd,
        tableName: tableName,
      ));
}

// --- Build AppBar Actions ---
List<Widget> buildAppBarActions(
  BuildContext context, {
  required bool enableSearchAndExport,
  required bool isGridView,
  required AppBarActionsHandler handler,
  required void Function(VoidCallback fn) setState,
  required bool isEditable,
  VoidCallback? onAdd,
  required String tableName,
}) {
  final auth = Provider.of<ControllerAuth>(context,listen:false);
  final loc = AppLocalizations.of(context)!;

  List<Widget> actions = [];

  if (enableSearchAndExport) {
    actions.add(IconButton(
      icon: const Icon(Icons.search),
      tooltip: loc.search,
      onPressed: handler.onSearchToggle,
    ));
  }
  if (auth.currentAccount == constSysAdminEmail) {
    actions.add(IconButton(
      icon: Icon(isGridView ? Icons.view_agenda : Icons.view_list),
      tooltip: loc.toggle_view,
      onPressed: handler.onToggleView,
    ));
  }
  if (enableSearchAndExport) {
    actions.add(IconButton(
      icon: const Icon(Icons.download),
      tooltip: loc.export_excel,
      onPressed: () => handler.onExport(tableName),
    ));
  }
  if (isEditable && onAdd != null) {
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
  final BuildContext context;
  ServiceStorage? serviceStorage;
  final VoidCallback refreshCallback;
  final void Function(void Function()) setState;

  bool Function() isGridViewGetter;
  bool Function() showSearchPanelGetter;

  final void Function(bool) onToggleGridView;
  final void Function(bool) onToggleShowSearch;

  ControllerAuth get _auth => Provider.of<ControllerAuth>(context,listen:false);
  AppLocalizations get loc => AppLocalizations.of(context)!;

  AppBarActionsHandler({
    required this.context,
    this.serviceStorage,
    required this.refreshCallback,
    required this.setState,
    required this.isGridViewGetter,
    required this.showSearchPanelGetter,
    required this.onToggleGridView,
    required this.onToggleShowSearch,
  });

  void onSearchToggle() {
    setState(() {
      onToggleShowSearch(!showSearchPanelGetter());
    });
  }

  Future<void> onExport(String tableName) async {
    try {
      final events =
          await serviceStorage?.getRecommendedEvents(tableName: tableName, inputUser: _auth.currentAccount);
      if (events == null || events.isEmpty) {
        showSnackBar(context, loc.no_events_to_export);
        return;
      }
      await exportRecommendedEventsToExcel(context, events);
    } catch (e) {
      showSnackBar(context, "${loc.export_failed}：$e");
    }
  }

  void onToggleView() {
    setState(() {
      onToggleGridView(!isGridViewGetter());
    });
  }

  Future<Event?> onAddEvent(BuildContext context, String tableName) {
    return Navigator.push<Event?>(
      context,
      MaterialPageRoute(
        builder: (context) => PageRecommendedEventAdd(tableName: tableName),
      ),
    ).then((newEvent) {
      if (newEvent != null) {
        refreshCallback();
      }
      return newEvent;
    });
  }
}

// --- Build Search Panel Widget ---
Widget buildSearchPanel({
  required TextEditingController searchController,
  required String searchKeywords,
  required DateTime? startDate,
  required DateTime? endDate,
  required void Function(String) onSearchKeywordsChanged,
  required void Function(DateTime?) onStartDateChanged,
  required void Function(DateTime?) onEndDateChanged,
  required void Function(void Function()) setState,
  required BuildContext context,
}) {
  final loc = AppLocalizations.of(context)!;
  return Padding(
    padding: kGapEI12,
    child: Column(
      children: [
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
        kGapH8(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: widgetBuildDateButton(
                context: context,
                date: startDate,
                label: loc.start_date,
                icon: Icons.date_range,
                onDateChanged: onStartDateChanged,
              ),
            ),
            kGapW16(),
            Expanded(
              child: widgetBuildDateButton(
                context: context,
                date: endDate,
                label: loc.end_date,
                icon: Icons.date_range,
                onDateChanged: onEndDateChanged,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

// ------------------------------
// ✅ 共用 Trailing Checkbox & Edit 按鈕
// ------------------------------
Widget buildEventTrailing({
  required BuildContext context,
  required Event event,
  required Set<String> selectedEventIds,
  required bool isEditable,
  required void Function(void Function()) setState,
  required VoidCallback refreshCallback,
  required ServiceStorage? serviceStorage,
  required String tableName,
  required String toTableName,
}) {
  final loc = AppLocalizations.of(context)!;
  final auth = Provider.of<ControllerAuth>(context,listen:false);

  return StatefulBuilder(builder: (context, localSetState) {
    final isChecked = selectedEventIds.contains(event.id);
    return Transform.scale(
      scale: 1.2,
      child: Row(
        children: [
          if (!auth.isAnonymous)
            Checkbox(
              value: isChecked,
              onChanged: (value) async {
                await onCheckboxChanged(
                  context: context,
                  serviceStorage: serviceStorage!,
                  value: value,
                  event: event,
                  selectedEventIds: selectedEventIds,
                  setState: (fn) {
                    fn();
                    localSetState(() {});
                  },
                  addedMessage: loc.event_add_ok,
                  tableName: tableName,
                  toTableName: toTableName,
                );
              },
            ),
          if (auth.currentAccount == event.account)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: loc.edit,
              onPressed: isEditable
                  ? () => onEditEvent(
                        context: context,
                        event: event,
                        setState: setState,
                        refreshCallback: refreshCallback,
                        tableName: tableName,
                      )
                  : null,
            ),
          if (!event.isApproved && auth.currentAccount == constSysAdminEmail)
            IconButton(
              icon: const Icon(Icons.task_alt),
              tooltip: loc.review,
              onPressed: () async {
                setState(() {
                  event.isApproved = true;
                });
                await ServiceStorage().approvalRecommendedEvent(
                  context,
                  event,
                  tableName,
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
  final List<Event> events;
  final bool isGridView;
  final Set<String> selectedEventIds;
  final Set<String> removedEventIds;
  final bool isEditable;
  final ServiceStorage? serviceStorage;
  final void Function(void Function()) setState;
  final ScrollController scrollController;
  final VoidCallback refreshCallback;
  final String tableName;
  final String toTableName;

  const EventList({
    super.key,
    required this.events,
    required this.isGridView,
    required this.selectedEventIds,
    required this.removedEventIds,
    required this.isEditable,
    this.serviceStorage,
    required this.setState,
    required this.scrollController,
    required this.refreshCallback,
    required this.tableName,
    required this.toTableName,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      key: PageStorageKey(tableName), //'recommended_event_list'
      controller: scrollController,
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        final trailing = buildEventTrailing(
          context: context,
          event: event,
          selectedEventIds: selectedEventIds,
          isEditable: isEditable,
          setState: setState,
          refreshCallback: refreshCallback,
          serviceStorage: serviceStorage,
          tableName: tableName,
          toTableName: toTableName,
        );

        if (isGridView) {
          return EventCardGraph(
            event: event,
            index: index,
            onTap: () {
              showDialog(
                context: context,
                barrierColor: const Color.fromARGB(102, 255, 255, 255), // 透明白
                builder: (_) => EventImageDialog(event: event),
              );
            },
            onDelete: () => onRemoveEvent(
              context: context,
              event: event,
              serviceStorage: serviceStorage,
              removedEventIds: removedEventIds,
              setState: setState,
              tableName: tableName,
            ),
            trailing: trailing,
          );
        } else {
          return EventCard(
            event: event,
            index: index,
            onTap: isEditable
                ? () => onEditEvent(
                      context: context,
                      event: event,
                      setState: setState,
                      refreshCallback: refreshCallback,
                      tableName: tableName,
                    )
                : null,
            onDelete: isEditable
                ? () => onRemoveEvent(
                      context: context,
                      event: event,
                      serviceStorage: serviceStorage,
                      removedEventIds: removedEventIds,
                      setState: setState,
                      tableName: tableName,
                    )
                : null,
            trailing: trailing,
          );
        }
      },
    );
  }
}

// ------------------------------
// ✅ Utility Functions
// ------------------------------
Future<void> onCheckboxChanged({
  required BuildContext context,
  required ServiceStorage serviceStorage,
  required bool? value,
  required Event event,
  required Set<String> selectedEventIds,
  required void Function(void Function()) setState,
  required String addedMessage,
  required String tableName,
  required String toTableName,
}) async {
  await handleCheckboxChanged(
    context: context,
    serviceStorage: serviceStorage,
    value: value,
    event: event,
    selectedEventIds: selectedEventIds,
    setState: setState,
    addedMessage: addedMessage,
    tableName: tableName,
    toTableName: toTableName,
  );
}

Future<void> onEditEvent({
  required BuildContext context,
  required Event event,
  required void Function(void Function()) setState,
  required VoidCallback refreshCallback,
  required String tableName,
}) async {
  final updatedEvent = await Navigator.push<Event?>(
    context,
    MaterialPageRoute(
      builder: (context) => PageRecommendedEventAdd(
        existingRecommendedEvent: event,
        tableName: tableName,
      ),
    ),
  );

  if (updatedEvent != null) {
    refreshCallback();
  }
}

Future<void> onRemoveEvent({
  required BuildContext context,
  required Event event,
  ServiceStorage? serviceStorage,
  required Set<String> removedEventIds,
  required void Function(void Function()) setState,
  required String tableName,
}) async {
  await handleRemoveEvent(
    context: context,
    event: event,
    onDelete: () async {
      await serviceStorage?.deleteRecommendedEvent(event, tableName);
    },
    onSuccessSetState: () {
      setState(() {
        removedEventIds.add(event.id);
      });
    },
  );
}

List<Event> filterEvents({
  required List<Event> events,
  required Set<String> removedEventIds,
  required String searchKeywords,
  DateTime? startDate,
  DateTime? endDate,
}) {
  final keywords = searchKeywords
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();

  return events.where((e) {
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
        e.endDate!.isBefore(startDate)) {
      matchesDate = false;
    }
    if (endDate != null &&
        e.startDate != null &&
        e.startDate!.isAfter(endDate)) {
      matchesDate = false;
    }

    return matchesKeywords && matchesDate;
  }).toList();
}

void scrollToEventById({
  required List<Event> events,
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
