import 'package:flutter/material.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/calendar/controller_calendar.dart';
import 'package:life_pilot/calendar/model_calendar.dart';
import 'package:life_pilot/calendar/controller_calendar_ui.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/event/model_event_item.dart';

Widget widgetsCalendarTrailing({
  required BuildContext context,
  required ControllerAuth auth,
  required ControllerCalendar controllerCalendar,
  required ModelCalendar modelCalendar,
  required EventItem event,
  required String tableName,
  required String toTableName,
}) {
  AppLocalizations loc = AppLocalizations.of(context)!;
  return Transform.scale(
    scale: 1.2,
    child: Row(
      mainAxisSize: MainAxisSize.min, // 避免 unbounded 爆錯
      children: [
        if (!auth.isAnonymous)
          Flexible(
            fit: FlexFit.loose,
            child: Builder(
              builder: (ctx) {
                // 確保使用正確的 BuildContext 讀取 Provider
                return Checkbox(
                  value: controllerCalendar.modelCalendar.selectedEventIds
                      .contains(event.id),
                  onChanged: (value) => onMemoryCheckboxChanged(
                    context: context, controller: controllerCalendar, value: value, event: event, toTableName: toTableName, loc: loc),
                );
              },
            ),
          ),
        if (!event.isHoliday)
          // ⏰ 鬧鐘
          IconButton(
            icon: Icon(
              event.reminderOptions.isNotEmpty
                  ? Icons.alarm_on_rounded
                  : Icons.alarm_rounded,
              size: event.reminderOptions.isNotEmpty
                  ? IconTheme.of(context).size! * 1.2
                  : IconTheme.of(context).size!,
              color:
                  event.reminderOptions.isNotEmpty ? Colors.blue : Colors.black,
            ),
            tooltip: loc.setAlarm,
            onPressed: () async {
              await onAlarmPressed(
                context: context,
                controller: controllerCalendar,
                event: event,
                loc: loc,
              );
              //Navigator.pop(context); // ✅ 最後關閉 dialog
            },
          ),
        if (auth.currentAccount == event.account)
          IconButton(
              icon: const Icon(Icons.edit),
              tooltip: loc.edit,
              onPressed: () => onEditPressed(
                context: context, controller: controllerCalendar, event: event,),
              ),
      ],
    ),
  );
}
