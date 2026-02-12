import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/accounting/controller_accounting_account.dart';
import 'package:life_pilot/controllers/auth/controller_auth.dart';
import 'package:life_pilot/controllers/calendar/controller_calendar.dart';
import 'package:life_pilot/models/event/model_event_calendar.dart';
import 'package:life_pilot/controllers/event/controller_event.dart';
import 'package:life_pilot/core/app_navigator.dart';
import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/models/event/model_event_item.dart';
import 'package:life_pilot/services/event/service_event.dart';
import 'package:life_pilot/views/widgets/event/widgets_confirmation_dialog.dart';
import 'package:life_pilot/views/widgets/event/widgets_event_card.dart';
import 'package:life_pilot/views/widgets/event/widgets_event_dialog.dart';
import 'package:life_pilot/views/widgets/event/widgets_event_trailing.dart';
import 'package:provider/provider.dart';

class WidgetsEventList extends StatelessWidget {
  final ControllerAuth auth;
  final ServiceEvent serviceEvent;
  final List<EventItem> filteredEvents;
  final ScrollController scrollController;
  final String tableName;
  final String toTableName;
  final ControllerEvent controllerEvent;
  final ModelEventCalendar modelEventCalendar;
  final ControllerCalendar controllerCalendar;

  const WidgetsEventList({
    super.key,
    required this.auth,
    required this.controllerCalendar,
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
            EventViewModel eventViewModel = controllerEvent.buildEventViewModel(
                event: event,
                parentLocation: constEmpty,
                canDelete: controllerEvent.canDelete(
                    account: event.account ?? constEmpty),
                showSubEvents: true,
                loc: loc);

            return WidgetsEventCard(
              eventViewModel: eventViewModel,
              tableName: tableName,
              onTap: () => _showEventDialog(
                  context: context,
                  eventViewModel: eventViewModel,
                  tableName: tableName),
              onDelete: controllerEvent.canDelete(
                      account: event.account ?? constEmpty)
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
              onLike: tableName == TableNames.recommendedEvents
                  ? () async {
                      await controllerEvent.likeEvent(
                          event: event,
                          account: auth.currentAccount ?? AuthConstants.guest);
                    }
                  : null,
              onDislike: tableName == TableNames.recommendedEvents
                  ? () async {
                      await controllerEvent.dislikeEvent(
                          event: event,
                          account: auth.currentAccount ?? AuthConstants.guest);
                    }
                  : null,
              onAccounting: tableName == TableNames.calendarEvents ||
                      tableName == TableNames.memoryTrace
                  ? () async {
                      final controller =
                          context.read<ControllerAccountingAccount>();

                      controller.handleAccounting(
                        context: context,
                        eventId: event.id,
                      );
                    }
                  : null,
              trailing: widgetsEventTrailing(
                context: context,
                auth: auth,
                serviceEvent: serviceEvent,
                controllerCalendar: controllerCalendar,
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
        eventViewModel: eventViewModel,
        tableName: tableName,
      ),
    );
  }
}
