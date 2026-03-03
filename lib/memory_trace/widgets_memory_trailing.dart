import 'package:flutter/material.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/event/model_event_calendar.dart';
import 'package:life_pilot/event/controller_event.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/event/controller_event_ui.dart';

Widget widgetsMemoryTrailing({
  required BuildContext context,
  required ControllerAuth auth,
  required ControllerEvent controllerEvent,
  required ModelEventCalendar modelEventCalendar,
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
        IconButton(
          icon: const Icon(Icons.edit),
          tooltip: loc.edit,
          onPressed: () => onEditPressed(
                context: context, controller: controllerEvent, event: event),
        ),
      ],
    ),
  );
}
