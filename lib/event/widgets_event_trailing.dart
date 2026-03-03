import 'package:flutter/material.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/event/controller_event.dart';
import 'package:life_pilot/event/controller_event_ui.dart';
import 'package:life_pilot/event/model_event_calendar.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/event/service_event.dart';

Widget widgetsEventTrailing({
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
        if (!auth.isAnonymous && tableName != TableNames.memoryTrace)
          Flexible(
            fit: FlexFit.loose,
            child: Builder(
              builder: (ctx) {
                // 確保使用正確的 BuildContext 讀取 Provider
                return Checkbox(
                  value: controllerEvent.modelEventCalendar.selectedEventIds
                      .contains(event.id),
                  onChanged: (value) => onMemoryCheckboxChanged(
                    context: context, controller: controllerEvent, value: value, event: event, toTableName: toTableName, loc: loc),
                );
              },
            ),
          ),
        if (auth.currentAccount == event.account)
          IconButton(
              icon: const Icon(Icons.edit),
              tooltip: loc.edit,
              onPressed: () => onEditPressed(
                context: context, controller: controllerEvent, event: event,),
              ),
        if (tableName != TableNames.memoryTrace &&
            !event.isApproved &&
            auth.currentAccount == AuthConstants.sysAdminEmail)
          IconButton(
            icon: const Icon(Icons.task_alt),
            tooltip: loc.review,
            onPressed: () async {
              await controllerEvent.approveEvent(event: event);
            },
          ),
        Gaps.w24,
      ],
    ),
  );
}
