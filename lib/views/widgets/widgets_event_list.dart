import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/controller_auth.dart';
import 'package:life_pilot/controllers/controller_event.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/models/model_event_item.dart';
import 'package:life_pilot/services/service_storage.dart';
import 'package:life_pilot/utils/core/utils_const.dart';
import 'package:life_pilot/utils/core/utils_locator.dart';
import 'package:life_pilot/utils/dialog/utils_show_dialog.dart';
import 'package:life_pilot/views/widgets/event/widgets_event_card.dart';
import 'package:life_pilot/views/widgets/event/widgets_event_dialog.dart';

import '../build_event_trailing.dart';

class WidgetsEventList extends StatelessWidget {
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

  const WidgetsEventList({
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
    required this.controllerEvent,
  });

  @override
  Widget build(BuildContext context) {
    final auth = getIt<ControllerAuth>();
    final loc = AppLocalizations.of(context)!;

    return ListView.builder(
      key: PageStorageKey(tableName),
      controller: scrollController,
      itemCount: filteredEvents.length,
      itemBuilder: (context, index) {
        final event = filteredEvents[index];

        return WidgetsEventCard(
          eventController: controllerEvent.eventController(event),
          tableName: tableName,
          index: index,
          onTap: () {
            showDialog(
              context: context,
              barrierDismissible: true,
              barrierColor: const Color.fromARGB(200, 128, 128, 128),
              builder: (_) => WidgetsEventDialog(
                tableName: tableName,
                eventController: controllerEvent.eventController(event),
              ),
            );
          },
          onDelete: _canDelete(auth, event)
              ? () async {
                  final confirmed = await showConfirmationDialog(
                    content: '${loc.event_delete}「${event.name}」？',
                    confirmText: loc.delete,
                    cancelText: loc.cancel,
                  );
                  if (confirmed == true) {
                    await controllerEvent.deleteEvent(event, loc);
                  }
                }
              : null,
          trailing: buildEventTrailing(
            event: event,
            setState: setState,
            refreshCallback: refreshCallback,
            tableName: tableName,
            toTableName: toTableName,
            loc: loc,
          ),
          showSubEvents: false,
        );
      },
    );
  }

  bool _canDelete(ControllerAuth auth, EventItem event) {
    return auth.currentAccount == event.account ||
        (auth.currentAccount == constSysAdminEmail &&
            tableName != constTableMemoryTrace);
  }
}
