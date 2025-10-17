import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/controller_auth.dart';
import 'package:life_pilot/controllers/controller_calendar.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/models/model_event_item.dart';
import 'package:life_pilot/my_app.dart';
import 'package:life_pilot/pages/page_event_add.dart';
import 'package:life_pilot/services/service_storage.dart';
import 'package:life_pilot/utils/core/utils_const.dart';
import 'package:life_pilot/utils/core/utils_locator.dart';
import 'package:life_pilot/utils/dialog/utils_show_dialog.dart';
import 'package:life_pilot/utils/platform/utils_mobile.dart';
import 'package:life_pilot/utils/utils_common_function.dart';

import '../notification/notification_entry.dart';

Widget buildEventTrailing({
  required EventItem event,
  required void Function(void Function()) setState,
  required VoidCallback refreshCallback,
  required String tableName,
  required String toTableName,
  required AppLocalizations loc,
}) {
  final controller = getIt<ControllerCalendar>();
  final auth = getIt<ControllerAuth>();
  final service = getIt<ServiceStorage>();

  return StatefulBuilder(builder: (context, localSetState) {
    return Row(
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
                loc: loc,
              );
            },
          ),
        if (tableName == constTableCalendarEvents && !event.isHoliday)
          IconButton(
            icon: Icon(
              event.reminderOptions.isNotEmpty
                  ? Icons.alarm_on_rounded
                  : Icons.alarm_rounded,
              size: event.reminderOptions.isNotEmpty ? 28 : 24,
              color: event.reminderOptions.isNotEmpty
                  ? Colors.blue
                  : Colors.black,
            ),
            tooltip: loc.set_alarm,
            onPressed: () async {
              final updated = await showAlarmSettingsDialog(event: event, loc: loc);
              if (updated) {
                await controller.loadCalendarEvents();
                await NotificationEntryImpl.cancelEventReminders(event: event);
                await checkExactAlarmPermission();
                await NotificationEntryImpl.scheduleEventReminders(
                  event: event,
                  tableName: controller.tableName,
                  loc: loc,
                );
                Navigator.pop(context);
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
              await service.approvalEvent(event: event, tableName: tableName);
            },
          ),
        kGapW24(),
      ],
    );
  });
}

//TODO
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
