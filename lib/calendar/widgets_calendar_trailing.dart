import 'package:flutter/material.dart';
import 'package:life_pilot/calendar/controller_calendar.dart';
import 'package:life_pilot/calendar/controller_calendar_ui.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:provider/provider.dart';

Widget widgetsCalendarTrailing({
  required BuildContext context,
  required ControllerCalendar controllerCalendar,
  required EventItem event,
}) {
  AppLocalizations loc = AppLocalizations.of(context)!;
  return Transform.scale(
    scale: 1.2,
    child: Row(
      mainAxisSize: MainAxisSize.min, // 避免 unbounded 爆錯
      children: [
        if (controllerCalendar.auth !=  null && !controllerCalendar.auth!.isAnonymous)
          Selector<ControllerCalendar, bool>(
            selector: (_, controller) => controller.isEventSelected(event.id),
            builder: (_, isSelected, __) {
              return Tooltip(
                message: loc.memoryAdd,
                child: Checkbox(
                  value: isSelected,
                  onChanged: (value) => onMemoryCheckboxChanged(
                    context: context, controller: controllerCalendar, value: value, event: event, loc: loc),
                ));
            },
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
        if (controllerCalendar.auth !=  null && controllerCalendar.auth!.currentAccount == event.account)
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
