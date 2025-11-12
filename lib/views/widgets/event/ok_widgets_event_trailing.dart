import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/auth/controller_auth.dart';
import 'package:life_pilot/controllers/calendar/controller_calendar.dart';
import 'package:life_pilot/controllers/calendar/model_event_calendar.dart';
import 'package:life_pilot/controllers/event/controller_event.dart';
import 'package:life_pilot/core/app_navigator.dart';
import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/models/event/model_event_item.dart';
import 'package:life_pilot/pages/event/page_event_add.dart';
import 'package:life_pilot/services/event/service_event.dart';
import 'package:life_pilot/views/widgets/event/ok_widgets_alarm_settings_dialog.dart';
import 'package:life_pilot/views/widgets/event/ok_widgets_confirmation_dialog.dart';

Widget widgetsEventTrailing({
  required BuildContext context,
  required ControllerAuth auth,
  required ServiceEvent serviceEvent,
  required ControllerCalendar controllerCalendar,
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
                  onChanged: (value) async {
                    bool tmpValue = value ?? false;
                    if (!tmpValue) {
                      controllerEvent.toggleEventSelection(event.id, false);
                      return;
                    }

                    bool isAlreadyAdded =
                        await controllerEvent.handleEventCheckboxIsAlreadyAdd(
                            event, tmpValue, toTableName);
                    final shouldTransfer = await confirmEventTransfer(
                        context: context,
                        event: event,
                        controllerEvent: controllerEvent,
                        fromTableName: tableName,
                        toTableName: toTableName,
                        loc: loc,
                        isAlreadyAdded: isAlreadyAdded);
                    if (shouldTransfer ?? false) {
                      await controllerEvent.handleEventCheckboxTransfer(
                        tmpValue,
                        isAlreadyAdded,
                        event,
                        controllerCalendar,
                        toTableName,
                      );
                      AppNavigator.showSnackBar(
                          tableName == TableNames.calendarEvents
                              ? loc.memoryAddOk
                              : loc.eventAddOk);
                    } else {
                      controllerEvent.toggleEventSelection(event.id, false);
                    }
                  },
                );
              },
            ),
          ),
        if (tableName == TableNames.calendarEvents && !event.isHoliday)
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
              final updated = await showAlarmSettingsDialog(
                  context, auth, controllerCalendar, serviceEvent, event, loc);
              if (updated) {
                await controllerEvent.updateAlarmSettings(
                    event: event); // ✅ 先更新資料
                await controllerCalendar.loadCalendarEvents(
                    month: event.startDate!,
                    notify:
                        true); // ✅ 然後刷新畫面                                // ✅ 更新 dialog 畫面（如果還在）
                Navigator.pop(context); // ✅ 最後關閉 dialog
              }
            },
          ),
        if (auth.currentAccount == event.account)
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
                    controllerCalendar: controllerCalendar,
                  );
                }
                // ✅ 只在確定有更新時再關閉外層對話框
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              }),
        if (tableName != TableNames.calendarEvents &&
            tableName != TableNames.memoryTrace &&
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
