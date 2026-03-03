import 'package:flutter/material.dart';
import 'package:life_pilot/calendar/controller_calendar.dart';
import 'package:life_pilot/calendar/page_calendar_add.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/event/service_event.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/app_navigator.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/enum.dart';
import 'package:life_pilot/utils/extension.dart';
import 'package:life_pilot/utils/widgets/widgets_confirmation_dialog.dart';

Future<void> onAddEventPressed({
  required BuildContext context,
  required ControllerCalendar controller,
  required DateTime date,
  required ServiceEvent serviceEvent,
}) async {
  final newEvent = await Navigator.push<EventItem?>(
    context,
    MaterialPageRoute(
      builder: (_) => PageCalendarAdd(
        auth: controller.auth!,
        serviceEvent: serviceEvent,
        controllerCalendar: controller,
        existingEvent: null,
        tableName: controller.tableName,
        initialDate: date,
      ),
    ),
  );

  if (newEvent != null) {
    await controller.handleCrossMonthTap(tappedDate: newEvent.startDate!);
    Navigator.pop(context, true); // 回傳 true 給外層
  }
}

Future<void> onEditPressed({
  required BuildContext context,
  required ControllerCalendar controller,
  required EventItem event,
  required ServiceEvent serviceEvent,
}) async {
  final updatedEvent = await Navigator.push<EventItem?>(
    context,
    MaterialPageRoute(
      builder: (_) => PageCalendarAdd(
        auth: controller.auth!,
        serviceEvent: serviceEvent,
        controllerCalendar: controller,
        tableName: controller.tableName,
        existingEvent: event.copyWith(),
      ),
    ),
  );

  await controller.onEditEvent(event: event, updatedEvent: updatedEvent);

  if (Navigator.of(context).canPop()) {
    Navigator.of(context).pop(); // 只有確定更新才關閉外層 dialog
  }
}

Future<void> onDeletePressed({
  required BuildContext context,
  required ControllerCalendar controller,
  required EventItem event,
  required AppLocalizations loc,
}) async {
  final shouldDelete = await showConfirmationDialog(
    content: '${loc.eventDelete}「${event.name}」？',
    confirmText: loc.delete,
    cancelText: loc.cancel,
  );

  if (shouldDelete != true) return;

  try {
    await controller.deleteEvent(event);
    AppNavigator.showSnackBar(loc.deleteOk);
  } catch (e) {
    AppNavigator.showErrorBar('${loc.deleteError}: $e');
  }

  if (Navigator.of(context).canPop()) {
    Navigator.of(context).pop(true);
  }
}

Future<void> onMemoryCheckboxChanged({
  required BuildContext context,
  required ControllerCalendar controller,
  required bool? value,
  required EventItem event,
  required String toTableName,
  required AppLocalizations loc,
}) async {
  final tmpValue = value ?? false;

  // 取消選擇直接 toggle
  if (!tmpValue) {
    controller.toggleEventSelection(event.id, false);
    return;
  }

  // 判斷是否已經存在
  final isAlreadyAdded = await controller.handleEventCheckboxIsAlreadyAdd(
      event, tmpValue, toTableName);

  // 顯示確認對話框
  final shouldTransfer = await confirmEventTransfer(
    context: context,
    event: event,
    controller: controller,
    fromTableName: controller.tableName,
    toTableName: toTableName,
    loc: loc,
    isAlreadyAdded: isAlreadyAdded,
  );

  if (shouldTransfer ?? false) {
    await controller.handleEventCheckboxTransfer(
        tmpValue, isAlreadyAdded, event, toTableName);
    AppNavigator.showSnackBar(loc.memoryAddOk);
  } else {
    controller.toggleEventSelection(event.id, false);
  }
}

Future<void> onAlarmPressed({
  required BuildContext context,
  required ControllerCalendar controller,
  required EventItem event,
  required ServiceEvent serviceEvent,
  required AppLocalizations loc,
}) async {
  final result = await showAlarmSettingsDialog(
    context,
    controller,
    serviceEvent,
    event,
    loc,
  );

  if (result == null) return;

  final msg = await controller.updateAlarmSettings(
    event: event,
    repeat: result["repeat"],
    reminders: result["reminders"],
    loc: loc,
  );
  AppNavigator.showSnackBar(msg["msg"] ?? msg["error"]!);
  if (Navigator.of(context).canPop()) {
    Navigator.of(context).pop();
  }
}

Future<Map<String, dynamic>?> showAlarmSettingsDialog(
      BuildContext context,
      ControllerCalendar controllerCalendar,
      ServiceEvent serviceEvent,
      EventItem event,
      AppLocalizations loc) async {
    final repeatOptions = CalendarRepeatRule.values;
    final reminderOptions = CalendarReminderOption.values;

    CalendarRepeatRule selectedRepeat = event.repeatOptions;
    Set<CalendarReminderOption> selectedReminders = {...event.reminderOptions};

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      barrierDismissible: true,
      builder: (_) {
        return AlertDialog(
          //title: Text(loc.set_alarm),
          backgroundColor: Colors.white,
          content: StatefulBuilder(
            builder: (context, setState) {
              return SizedBox(
                width: MediaQuery.of(context).size.width,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, // ⬅️ 靠左對齊
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(// 重複頻率單選
                          children: [
                        Text(loc.repeatOptions,
                            style:
                                TextStyle(color: Colors.black54)), // 你可以加翻譯關鍵字
                        Gaps.w16,
                        Expanded(
                          child: DropdownButton<CalendarRepeatRule>(
                            value: selectedRepeat,
                            isExpanded: true,
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  selectedRepeat = value;
                                });
                              }
                            },
                            items: repeatOptions
                                .map((r) => DropdownMenuItem(
                                      value: r,
                                      child: Text(r.label(loc)),
                                    ))
                                .toList(),
                          ),
                        ),
                      ]),
                      Gaps.h4,
                      // 提醒時間多選
                      Text(loc.reminderOptions,
                          style: TextStyle(color: Colors.black54)), // 你可以加翻譯關鍵字
                      ...reminderOptions.map((option) {
                        final checked = selectedReminders.contains(option);
                        return Row(
                          children: [
                            Checkbox(
                              value: checked,
                              onChanged: (checked) {
                                setState(() {
                                  if (checked == true) {
                                    selectedReminders.add(option);
                                  } else {
                                    selectedReminders.remove(option);
                                  }
                                });
                              },
                            ),
                            Expanded(
                                child: Text(option.label(loc))), // ⬅️ 保證文字不擠
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(context, {
                  "repeat": selectedRepeat,
                  "reminders": selectedReminders.toList(),
                });
              },
              child: Text(loc.confirm, style: TextStyle(color: Colors.red)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: Text(loc.cancel, style: TextStyle(color: Colors.black)),
            ),
          ],
        );
      },
    );
    return result;
  }