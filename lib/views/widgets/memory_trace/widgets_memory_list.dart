import 'package:flutter/material.dart';
import 'package:life_pilot/accounting/controller_accounting_list.dart';
import 'package:life_pilot/controllers/auth/controller_auth.dart';
import 'package:life_pilot/models/event/model_event_calendar.dart';
import 'package:life_pilot/controllers/event/controller_event.dart';
import 'package:life_pilot/core/app_navigator.dart';
import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/models/event/model_event_item.dart';
import 'package:life_pilot/models/event/model_event_view.dart';
import 'package:life_pilot/services/event/service_event.dart';
import 'package:life_pilot/views/widgets/core/widgets_confirmation_dialog.dart';
import 'package:life_pilot/views/widgets/memory_trace/widgets_memory_card.dart';
import 'package:life_pilot/views/widgets/memory_trace/widgets_memory_dialog.dart';
import 'package:life_pilot/views/widgets/memory_trace/widgets_memory_trailing.dart';
import 'package:provider/provider.dart';

class WidgetsMemoryList extends StatelessWidget {
  final ControllerAuth auth;
  final ServiceEvent serviceEvent;
  final List<EventItem> filteredEvents;
  final ScrollController scrollController;
  final String tableName;
  final String toTableName;
  final ControllerEvent controllerEvent;
  final ModelEventCalendar modelEventCalendar;

  const WidgetsMemoryList({
    super.key,
    required this.auth,
    required this.serviceEvent,
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
            EventViewModel eventViewModel = EventViewModel.buildEventViewModel(
                event: event,
                parentLocation: constEmpty,
                canDelete: ControllerEvent.canDelete(
                    account: event.account ?? constEmpty, auth: auth, tableName: tableName),
                showSubEvents: true,
                loc: loc, 
                tableName: tableName);

            return WidgetsMemoryCard(
              eventViewModel: eventViewModel,
              tableName: tableName,
              onTap: () => _showEventDialog(
                  context: context,
                  eventViewModel: eventViewModel,
                  tableName: tableName),
              onDelete: ControllerEvent.canDelete(
                      account: event.account ?? constEmpty, auth: auth, tableName: tableName)
                  ? () async {
                      final confirmed = await showConfirmationDialog(
                        content: '${loc.eventDelete}「${event.name}」？',
                        confirmText: loc.delete,
                        cancelText: loc.cancel,
                      );

                      if (confirmed == true) {
                        try {
                          await controllerEvent.deleteEvent(event);
                          AppNavigator.showSnackBar(loc.deleteOk);
                        } catch (e) {
                          AppNavigator.showErrorBar('${loc.deleteError}: $e');
                        }
                      }
                    }
                  : null,
              onAccounting: () => context.read<ControllerAccountingList>().handleAccounting(
                context: context,
                eventId: event.id,
              ),
              trailing: widgetsMemoryTrailing(
                context: context,
                auth: auth,
                serviceEvent: serviceEvent,
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
      builder: (_) => WidgetsMemoryDialog(
        eventViewModel: eventViewModel,
        tableName: tableName,
      ),
    );
  }
}
