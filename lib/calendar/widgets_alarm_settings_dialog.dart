import 'package:flutter/material.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/calendar/controller_calendar.dart';
import 'package:life_pilot/utils/app_navigator.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/event/service_event.dart';
import 'package:life_pilot/utils/enum.dart';
import 'package:life_pilot/utils/extension.dart';
import 'package:life_pilot/utils/logger.dart';

Future<bool> showAlarmSettingsDialog(
    BuildContext context,
    ControllerAuth auth,
    ControllerCalendar controllerCalendar,
    ServiceEvent serviceEvent,
    EventItem event,
    AppLocalizations loc) async {
  final repeatOptions = CalendarRepeatRule.values;
  final reminderOptions = CalendarReminderOption.values;

  CalendarRepeatRule selectedRepeat = event.repeatOptions;
  Set<CalendarReminderOption> selectedReminders = {...event.reminderOptions};

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
              List<CalendarReminderOption> reminders = selectedReminders.toList();
              try{
                await controllerCalendar.saveSettings(
                  auth: auth,
                  event: event,
                  repeat: selectedRepeat,
                  reminders: reminders,
                );
              
                if (reminders.isNotEmpty) {
                  AppNavigator.showSnackBar(
                      '${loc.setAlarm} ${reminders.map((r) => r.label(loc)).join(", ")}');
                } else {
                  AppNavigator.showSnackBar(loc.cancelAlarm);
                }
                logger.i('✅ Alarm settings saved successfully.'); 
                Navigator.pop(context, true);
              } catch (e, st) {
                logger.e('❌ saveSettings error: $e', stackTrace: st);
                AppNavigator.showErrorBar('❌ error: ${e.toString()}');
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
