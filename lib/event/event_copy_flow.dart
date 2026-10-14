import 'package:flutter/material.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/calendar/controller_calendar.dart';
import 'package:life_pilot/calendar/page_calendar_add.dart';
import 'package:life_pilot/event/controller_event.dart';
import 'package:life_pilot/event/model_event.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/event/page_event_add.dart';
import 'package:life_pilot/event/service_event.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/memory_trace/page_memory_add.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/service/service_weather.dart';
import 'package:life_pilot/utils/text_normalization.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

enum EventCopyDestination {
  calendar(TableNames.calendarEvents, Icons.calendar_month_outlined),
  memory(TableNames.memoryTrace, Icons.auto_stories_outlined),
  recommendedEvent(TableNames.recommendEvents, Icons.event_outlined),
  recommendedAttraction(TableNames.recommendPlaces, Icons.place_outlined);

  const EventCopyDestination(this.tableName, this.icon);

  final String tableName;
  final IconData icon;

  String label(AppLocalizations loc) => switch (this) {
    calendar => loc.personalEvent,
    memory => loc.memoryTrace,
    recommendedEvent => loc.recommendEvent,
    recommendedAttraction => loc.recommendPlaces,
  };
}

List<EventCopyDestination> availableEventCopyDestinations({
  required String sourceTableName,
  required bool isOwnCalendarEvent,
}) => EventCopyDestination.values
    .where(
      (destination) =>
          destination.tableName != sourceTableName ||
          (destination == EventCopyDestination.calendar && !isOwnCalendarEvent),
    )
    .toList(growable: false);

EventItem buildEventCopyTemplate(
  EventItem source, {
  required String currentAccount,
}) {
  EventItem clone(EventItem item) => EventItem.fromJson(json: item.toJson())
    ..id = const Uuid().v4()
    ..account = currentAccount
    ..isCompleted = false
    ..isHoliday = false
    ..isTaiwanHoliday = false
    ..isApproved = false
    ..isLike = null
    ..isDislike = null
    ..pageViews = 0
    ..cardClicks = 0
    ..saves = 0
    ..registrationClicks = 0
    ..likeCounts = 0
    ..dislikeCounts = 0
    ..subEvents = item.subEvents.map(clone).toList(growable: false);

  return clone(source);
}

Future<EventItem?> copyEventToAnotherPage({
  required BuildContext context,
  required EventItem event,
  required String sourceTableName,
}) async {
  final loc = AppLocalizations.of(context)!;
  final auth = context.read<ControllerAuth>();
  final currentAccount = auth.currentAccount ?? '';
  if (currentAccount.isEmpty) return null;

  final destinations = availableEventCopyDestinations(
    sourceTableName: sourceTableName,
    isOwnCalendarEvent:
        sourceTableName == TableNames.calendarEvents &&
        normalizedTextEquals(event.account, currentAccount),
  );
  final destination = await showModalBottomSheet<EventCopyDestination>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              title: Text(
                loc.copyToPage,
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              subtitle: Text(loc.copyContentHint),
            ),
            for (final item in destinations)
              ListTile(
                leading: Icon(item.icon),
                title: Text(item.label(loc)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pop(sheetContext, item),
              ),
          ],
        ),
      ),
    ),
  );
  if (destination == null || !context.mounted) return null;

  final template = buildEventCopyTemplate(
    event,
    currentAccount: currentAccount,
  );
  EventItem? created;
  if (destination == EventCopyDestination.calendar) {
    created = await Navigator.of(context).push<EventItem?>(
      MaterialPageRoute(
        builder: (_) => PageCalendarAdd(
          controllerCalendar: context.read<ControllerCalendar>(),
          templateEvent: template,
        ),
      ),
    );
  } else {
    final targetController = ControllerEvent(
      auth: auth,
      serviceEvent: context.read<ServiceEvent>(),
      serviceWeather: context.read<ServiceWeather>(),
      modelEvent: ModelEvent(),
      tableName: destination.tableName,
      toTableName: destination == EventCopyDestination.memory
          ? null
          : TableNames.calendarEvents,
    );
    try {
      created = await Navigator.of(context).push<EventItem?>(
        MaterialPageRoute(
          builder: (_) => destination == EventCopyDestination.memory
              ? PageMemoryAdd(
                  controllerEvent: targetController,
                  templateEvent: template,
                )
              : PageEventAdd(
                  controllerEvent: targetController,
                  templateEvent: template,
                ),
        ),
      );
    } finally {
      targetController.dispose();
    }
  }

  if (created != null) {
    await auth.refreshSubscriptionUsage();
  }
  return created;
}
