import 'package:flutter/material.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/event/controller_event.dart';
import 'package:life_pilot/event/controller_event_ui.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/event/widgets_event_card.dart';
import 'package:life_pilot/event/widgets_event_dialog.dart';
import 'package:life_pilot/event/widgets_event_trailing.dart';
import 'package:life_pilot/l10n/app_localizations.dart';

class WidgetsEventList extends StatelessWidget {
  final ControllerAuth auth;
  final List<EventItem> filteredEvents;
  final ScrollController scrollController;
  final ControllerEvent controllerEvent;

  const WidgetsEventList({
    super.key,
    required this.auth,
    required this.filteredEvents,
    required this.scrollController,
    required this.controllerEvent,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return ListView.builder(
      key: PageStorageKey(controllerEvent.fromTableName),
      controller: scrollController,
      cacheExtent: 180,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: filteredEvents.length,
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: true,
      addSemanticIndexes: false,
      itemBuilder: (context, index) {
        final eventViewModel = controllerEvent.buildViewModel(
          event: filteredEvents[index],
          loc: loc,
        );
        controllerEvent.preloadWeatherForEvent(eventViewModel);

        return WidgetsEventCard(
          key: ValueKey(eventViewModel.id),
          controllerEvent: controllerEvent,
          eventViewModel: eventViewModel,
          tableName: controllerEvent.fromTableName,
          onTap: () => _showEventDialog(
              context: context,
              eventViewModel: eventViewModel,
              tableName: controllerEvent.fromTableName),
          onDelete: eventViewModel.canDelete
              ? () async {
                  await onDeletePressed(
                    context: context,
                    controller: controllerEvent,
                    event: eventViewModel.event,
                    loc: loc,
                  );
                }
              : null,
          onLike: () async {
            await controllerEvent.likeEvent(eventViewModel.event);
          },
          onDislike: () async {
            await controllerEvent.dislikeEvent(eventViewModel.event);
          },
          onAccounting: null,
          onOpenLink: () => controllerEvent.onOpenLink(eventViewModel),
          onOpenMap: () => controllerEvent.onOpenMap(eventViewModel),
          trailing: widgetsEventTrailing(
            context: context,
            auth: auth,
            controllerEvent: controllerEvent,
            event: eventViewModel.event,
          ),
          showSubEvents: false,
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
