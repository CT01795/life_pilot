import 'package:flutter/material.dart';
import 'package:life_pilot/accounting/controller_accounting_list.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/event/controller_event_ui.dart';
import 'package:life_pilot/event/controller_event.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/memory_trace/widgets_memory_card.dart';
import 'package:life_pilot/memory_trace/widgets_memory_dialog.dart';
import 'package:life_pilot/memory_trace/widgets_memory_trailing.dart';
import 'package:provider/provider.dart';

class WidgetsMemoryList extends StatelessWidget {
  final ControllerAuth auth;
  final List<EventItem> filteredEvents;
  final ScrollController scrollController;
  final ControllerEvent controllerEvent;

  const WidgetsMemoryList({
    super.key,
    required this.auth,
    required this.filteredEvents,
    required this.scrollController,
    required this.controllerEvent,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final viewModels =
        controllerEvent.buildViewModels(events: filteredEvents, loc: loc);

    return ListView.builder(
      key: PageStorageKey(controllerEvent.fromTableName),
      controller: scrollController,
      itemCount: viewModels.length,
      itemBuilder: (context, index) {
        EventViewModel eventViewModel = viewModels[index];

        return WidgetsMemoryCard(
          key: ValueKey(eventViewModel.id),
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
          onAccounting: () =>
              context.read<ControllerAccountingList>().handleAccounting(
                    context: context,
                    eventId: eventViewModel.id,
                  ),
          onOpenLink: () => controllerEvent.onOpenLink(eventViewModel),
          onOpenMap: () => controllerEvent.onOpenMap(eventViewModel),
          trailing: widgetsMemoryTrailing(
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
      builder: (_) => WidgetsMemoryDialog(
        controllerEvent: controllerEvent,
        eventViewModel: eventViewModel,
        tableName: tableName,
      ),
    );
  }
}
