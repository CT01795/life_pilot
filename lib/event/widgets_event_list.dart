import 'package:flutter/material.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/event/controller_event_ui.dart';
import 'package:life_pilot/event/model_event_calendar.dart';
import 'package:life_pilot/event/controller_event.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/event/widgets_event_card.dart';
import 'package:life_pilot/event/widgets_event_dialog.dart';
import 'package:life_pilot/event/widgets_event_trailing.dart';
import 'package:provider/provider.dart';

class WidgetsEventList extends StatelessWidget {
  final ControllerAuth auth;
  final List<EventItem> filteredEvents;
  final ScrollController scrollController;
  final String tableName;
  final String toTableName;
  final ControllerEvent controllerEvent;
  final ModelEventCalendar modelEventCalendar;

  const WidgetsEventList({
    super.key,
    required this.auth,
    required this.filteredEvents,
    required this.scrollController,
    required this.tableName,
    required this.toTableName,
    required this.controllerEvent,
    required this.modelEventCalendar,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Consumer<ModelEventCalendar>(
      builder: (_, view, __) {
        return ListView.builder(
          key: PageStorageKey(tableName),
          controller: scrollController,
          itemCount: filteredEvents.length,
          itemBuilder: (context, index) {
            final event = filteredEvents[index];
            EventViewModel eventViewModel = controllerEvent.buildViewModel(
                  event: event,
                  tableName: tableName,
                  loc: loc,
                );

            return WidgetsEventCard(
              eventViewModel: eventViewModel,
              tableName: tableName,
              onTap: () => _showEventDialog(
                  context: context,
                  eventViewModel: eventViewModel,
                  tableName: tableName),
              onDelete: eventViewModel.canDelete
                  ? () async {
                      await onDeletePressed(
                        context: context,
                        controller: controllerEvent,
                        event: event,
                        loc: loc,
                      );
                    }
                  : null,
              onLike: () async {
                await controllerEvent.likeEvent(event);
              },
              onDislike: () async {
                await controllerEvent.dislikeEvent(event);
              },
              onAccounting: null,
              onOpenLink: () => controllerEvent.onOpenLink(eventViewModel),
              onOpenMap: () => controllerEvent.onOpenMap(eventViewModel),
              trailing: widgetsEventTrailing(
                context: context,
                auth: auth,
                serviceEvent: controllerEvent.serviceEvent,
                controllerEvent: controllerEvent,
                modelEventCalendar: modelEventCalendar,
                event: event,
                tableName: tableName,
                toTableName: toTableName,
              ),
              showSubEvents: false,
            );
          },
        );
      },
    );
  }

  void _showEventDialog(
      {required BuildContext context,
      required EventViewModel eventViewModel,
      required String tableName}) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: const Color.fromARGB(200, 128, 128, 128),
      builder: (_) => WidgetsEventDialog(
        controllerEvent: controllerEvent,
        eventViewModel: eventViewModel,
        tableName: tableName,
      ),
    );
  }
}
