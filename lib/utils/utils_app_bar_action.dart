import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/controller_auth.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/models/model_recommended_event.dart';
import 'package:life_pilot/pages/page_recommended_event_add.dart';
import 'package:life_pilot/services/service_storage.dart';
import 'package:life_pilot/utils/utils_class_event_card.dart';
import 'package:life_pilot/utils/utils_class_event_card_graph.dart';
import 'package:life_pilot/utils/utils_common_function.dart';
import 'package:life_pilot/utils/utils_gaps.dart';
import 'package:life_pilot/utils/utils_widgets.dart';
import 'package:provider/provider.dart';

import 'utils_export.dart';

AppBar buildWhiteAppBar(
  BuildContext context, {
  required String title,
  bool enableSearchAndExport = false,
  required bool isGridView,
  required AppBarActionsHandler handler,
  required void Function(void Function()) setState,
  required bool isEditable,
  VoidCallback? onAdd,
}) {
  return AppBar(
      title: Text(''),
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
      ));
}

List<Widget> buildAppBarActions(
  BuildContext context, {
  required bool enableSearchAndExport,
  required bool isGridView,
  required AppBarActionsHandler handler,
  required void Function(VoidCallback fn) setState,
  required bool isEditable,
  VoidCallback? onAdd,
}) {
  final auth = Provider.of<ControllerAuth>(context);
  final loc = AppLocalizations.of(context)!;
  List<Widget> tmp = [
    if (enableSearchAndExport)
      IconButton(
        icon: const Icon(Icons.search),
        tooltip: loc.search,
        onPressed: () => handler.onSearchToggle(),
      ),
    if (auth.currentAccount == 'minavi@alumni.nccu.edu.tw')
      IconButton(
        icon: Icon(isGridView ? Icons.view_agenda : Icons.view_list),
        tooltip: loc.toggle_view,
        onPressed: () => handler.onToggleView(),
      ),
    if (enableSearchAndExport)
      IconButton(
        icon: const Icon(Icons.download),
        tooltip: loc.export_excel,
        onPressed: () => handler.onExport(),
      ),
    if (isEditable && onAdd != null)
      IconButton(
        icon: const Icon(Icons.add),
        tooltip: loc.event_add,
        onPressed: onAdd,
      ),
  ];
  return tmp;
}

class AppBarActionsHandler {
  final BuildContext context;
  AppLocalizations get loc => AppLocalizations.of(context)!;
  ServiceStorage? serviceStorage;
  bool isGridView = true;
  bool showSearchPanel = false;
  final VoidCallback refreshCallback;
  final void Function(void Function()) setState;

  bool Function() isGridViewGetter;
  bool Function() showSearchPanelGetter;

  final void Function(bool) onToggleGridView;
  final void Function(bool) onToggleShowSearch;

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

  Future<void> onExport() async {
    try {
      final events = await serviceStorage?.getRecommendedEvents();
      if (events!.isEmpty) {
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

  Future<RecommendedEvent?> onAddEvent(BuildContext context) {
    return Navigator.push<RecommendedEvent?>(
      context,
      MaterialPageRoute(
        builder: (context) => PageRecommendedEventAdd(
          existingRecommendedEvent: null,
        ),
      ),
    ).then((newEvent) {
      if (newEvent != null) {
        refreshCallback();
      }
      return newEvent;
    });
  }
}

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
                    onPressed: () {
                      setState(() {
                        onSearchKeywordsChanged('');
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
        kGapH8,
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
            kGapW16,
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

Future<void> onCheckboxChanged({
  required BuildContext context,
  required ServiceStorage serviceStorage,
  required bool? value,
  required RecommendedEvent event,
  required Set<String> selectedEventIds,
  required void Function(void Function()) setState,
  required String addedMessage,
}) async {
  await handleCheckboxChanged(
    context: context,
    serviceStorage: serviceStorage,
    value: value,
    event: event,
    selectedEventIds: selectedEventIds,
    setState: setState,
    addedMessage: addedMessage,
  );
}

Future<void> onEditEvent({
  required BuildContext context,
  required RecommendedEvent event,
  required void Function(void Function()) setState,
  required VoidCallback refreshCallback,
}) async {
  final updatedEvent = await Navigator.push<RecommendedEvent?>(
    context,
    MaterialPageRoute(
      builder: (context) => PageRecommendedEventAdd(
        existingRecommendedEvent: event,
      ),
    ),
  );

  if (updatedEvent != null) {
    refreshCallback();
  }
}

Future<void> onRemoveEvent({
  required BuildContext context,
  required RecommendedEvent event,
  ServiceStorage? serviceStorage,
  required Set<String> removedEventIds,
  required void Function(void Function()) setState,
}) async {
  await handleRemoveEvent(
    context: context,
    event: event,
    onDelete: () async {
      await serviceStorage?.deleteRecommendedEvent(event);
    },
    onSuccessSetState: () {
      setState(() {
        removedEventIds.add(event.id);
      });
    },
  );
}

List<RecommendedEvent> filterEvents({
  required List<RecommendedEvent> events,
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
          e.subRecommendedEvents.any(
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

class EventList extends StatelessWidget {
  final List<RecommendedEvent> events;
  final bool isGridView;
  final Set<String> selectedEventIds;
  final Set<String> removedEventIds;
  final bool isEditable;
  final ServiceStorage? serviceStorage;
  final void Function(void Function()) setState;
  final ScrollController scrollController;
  final VoidCallback refreshCallback;

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
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final auth = Provider.of<ControllerAuth>(context);
    if (isGridView) {
      return ListView.builder(
        key: PageStorageKey('recommended_event_list'),
        controller: scrollController,
        itemCount: events.length,
        itemBuilder: (context, index) {
          final event = events[index];
          return EventCardGraph(
            event: event,
            index: index,
            onTap: () {
              showDialog(
                context: context,
                // ignore: deprecated_member_use
                barrierColor: Colors.black.withOpacity(0.4),
                builder: (_) => EventImageDialog(event: event),
              );
            },
            onDelete: () async => await onRemoveEvent(
              context: context,
              event: event,
              serviceStorage: serviceStorage,
              removedEventIds: removedEventIds,
              setState: setState,
            ),
            trailing: StatefulBuilder(
              builder: (context, localSetState) {
                final isChecked = selectedEventIds.contains(event.id);
                return Transform.scale(
                  scale: 1.5,
                  child: Row(
                    children: [
                      if (auth.currentAccount == event.account)
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () async {
                            await onEditEvent(
                              context: context,
                              event: event,
                              setState: setState,
                              refreshCallback: refreshCallback,
                            );
                          },
                        ),
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
                                addedMessage: loc.event_add_ok);
                          },
                        ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      );
    } else {
      return ListView.builder(
        key: PageStorageKey('recommended_event_list'),
        itemCount: events.length,
        itemBuilder: (context, index) {
          final event = events[index];
          return EventCard(
            event: event,
            index: index,
            onTap: isEditable
                ? () async => await onEditEvent(
                      context: context,
                      event: event,
                      setState: setState,
                      refreshCallback: refreshCallback,
                    )
                : null,
            onDelete: isEditable
                ? () async => await onRemoveEvent(
                      context: context,
                      event: event,
                      serviceStorage: serviceStorage,
                      removedEventIds: removedEventIds,
                      setState: setState,
                    )
                : null,
            trailing: StatefulBuilder(
              builder: (context, localSetState) {
                final isChecked = selectedEventIds.contains(event.id);
                return Transform.scale(
                  scale: 1.5,
                  child: Row(
                    children: [
                      if (auth.currentAccount == event.account)
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: isEditable
                              ? () async {
                                  await onEditEvent(
                                    context: context,
                                    event: event,
                                    setState: setState,
                                    refreshCallback: refreshCallback,
                                  );
                                }
                              : null,
                        ),
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
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      );
    }
  }
}

void scrollToEventById({
  required List<RecommendedEvent> events,
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
