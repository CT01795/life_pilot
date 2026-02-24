import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/auth/controller_auth.dart';
import 'package:life_pilot/models/event/model_event_calendar.dart';
import 'package:life_pilot/controllers/event/controller_event.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/models/event/model_event_item.dart';
import 'package:life_pilot/pages/event/page_event_add.dart';
import 'package:life_pilot/services/event/service_event.dart';

Widget widgetsMemoryTrailing({
  required BuildContext context,
  required ControllerAuth auth,
  required ServiceEvent serviceEvent,
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
          onPressed: () async {
            final updatedEvent =
                await Navigator.of(context).push<EventItem?>(
              MaterialPageRoute(
                builder: (_) => PageEventAdd(
                  auth: auth,
                  serviceEvent: serviceEvent,
                  controllerEvent:
                      controllerEvent, // ✅ 傳遞目前這個 ControllerEvent 實例
                  tableName: tableName,
                  existingEvent: event,
                ),
              ),
            );

            if (updatedEvent != null) {
              await controllerEvent.onEditEvent(
                event: event,
                updatedEvent: updatedEvent,
              );
            }
            // ✅ 只在確定有更新時再關閉外層對話框
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          }
        ),
      ],
    ),
  );
}
