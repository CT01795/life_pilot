import 'package:flutter/material.dart' hide DateUtils;
import 'package:life_pilot/controllers/calendar/controller_alarm_settings.dart';
import 'package:life_pilot/controllers/auth/controller_auth.dart';
import 'package:life_pilot/controllers/calendar/controller_calendar.dart';
import 'package:life_pilot/core/app_navigator.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/models/event/model_event_item.dart';
import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/core/calendar/utils_calendar.dart';
import 'package:life_pilot/services/event/service_event.dart';

Future<bool> showAlarmSettingsDialog(
    BuildContext context,
    ControllerAuth auth,
    ControllerCalendar controllerCalendar,
    ServiceEvent serviceEvent,
    EventItem event,
    AppLocalizations loc) async {
  final repeatOptions = RepeatRule.values;
  final reminderOptions = ReminderOption.values;

  RepeatRule selectedRepeat = event.repeatOptions;
  Set<ReminderOption> selectedReminders = {...event.reminderOptions};

  // ✅ 直接建立 controllerAlarmSettings
  final controllerAlarm = ControllerAlarmSettings(
    controllerCalendar: controllerCalendar,
    serviceEvent: serviceEvent,
  );

  final result = await showDialog<bool>(
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
                          style: TextStyle(color: Colors.black54)), // 你可以加翻譯關鍵字
                      Gaps.w16,
                      Expanded(
                        child: DropdownButton<RepeatRule>(
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
                          Expanded(child: Text(option.label(loc))), // ⬅️ 保證文字不擠
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
              List<ReminderOption> reminders = selectedReminders.toList();
              final msg = await controllerAlarm.saveSettings(
                auth: auth,
                event: event,
                repeat: selectedRepeat,
                reminders: reminders,
              );
              if (msg.isEmpty) {
                if (reminders.isNotEmpty) {
                  AppNavigator.showSnackBar(
                      '${loc.setAlarm} ${reminders.map((r) => r.label(loc)).join(", ")}');
                } else {
                  AppNavigator.showSnackBar(loc.cancelAlarm);
                }

                Navigator.pop(context, true);
              } else {
                AppNavigator.showErrorBar(msg);
              }
            },
            child: Text(loc.confirm, style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(loc.cancel, style: TextStyle(color: Colors.black)),
          ),
        ],
      );
    },
  );
  return result ?? false;
}
