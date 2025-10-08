import 'package:flutter/material.dart' hide DateUtils;
import 'package:intl/intl.dart';
import 'package:life_pilot/controllers/controller_calendar.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/core/utils_locator.dart';
import 'package:life_pilot/models/model_event.dart';
import 'package:life_pilot/my_app.dart';
import 'package:life_pilot/notification/core/reminder_option.dart';
import 'package:life_pilot/pages/page_event_add.dart';
import 'package:life_pilot/services/service_storage.dart';
import 'package:life_pilot/utils/widget/utils_calendar_widgets.dart';
import 'package:life_pilot/utils/utils_common_function.dart';
import 'package:life_pilot/utils/core/utils_const.dart';
import 'package:life_pilot/utils/utils_date_time.dart';
import 'package:life_pilot/utils/core/utils_enum.dart';
import 'package:life_pilot/utils/utils_event_app_bar_action.dart';
import 'package:life_pilot/utils/utils_event_card.dart';

// 通用的確認 Dialog
Future<bool> showConfirmationDialog({
  required String content,
  required String confirmText,
  required String cancelText,
}) async {
  final navigator = navigatorKey.currentState;
  if (navigator == null) {
    // 沒有 navigator，直接回傳 false 或 throw
    return false;
  }

  return await showDialog<bool>(
        context: navigator.context,
        barrierDismissible: true,
        builder: (context) => AlertDialog(
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(confirmText, style: TextStyle(color: Colors.red)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(cancelText, style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      ) ??
      false;
}

Future<bool> showCalendarEventsDialog({
  required DateTime date,
  required AppLocalizations loc,
}) async {
  ControllerCalendar controller = getIt<ControllerCalendar>();
  final tableName = constTableCalendarEvents;
  final dateOnly = DateUtils.dateOnly(date);

  //如果點到的是跨月日期，先載入那月資料 ——
  if (date.month != controller.currentMonth.month ||
      date.year != controller.currentMonth.year) {
    // ✅ 若點到的是不同月份，就先載入那個月份的資料
    await handleCrossMonthTap(
      tappedDate: date,
      displayedMonth: controller.currentMonth,
    );
  }

  // 篩選包含該日期的事件
  final eventsOfDay = controller.getEventsOfDay(date: dateOnly);

  // ✅ 如果沒有事件，直接跳轉新增事件頁
  if (eventsOfDay.isEmpty) {
    final result = await navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (_) => PageEventAdd(
          existingEvent: null,
          tableName: controller.tableName,
          initialDate: date,
        ),
      ),
    );
    if (result != null && result is Event) {
      controller.goToMonth(
        month: DateUtils.monthOnly(result.startDate!),
      );
      return true;
    }
    return false;
  }

  // ✅ 有事件時，顯示 Dialog
  final result = await showDialog<bool>(
    context: navigatorKey.currentState!.context,
    barrierDismissible: true,
    builder: (context) {
      return StatefulBuilder(builder: (context, setState) {
        // 每次build時都重新抓當天事件，確保資料最新
        final updatedEventsOfDay = controller.getEventsOfDay(date: dateOnly);

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: kGapEIH6,
          child: Stack(
            children: [
              // 內容區塊
              SingleChildScrollView(
                child: Container(
                  padding: kGapEI0,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              DateFormat(constDateFormatMMdd).format(date),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            IconButton(
                              icon: Icon(Icons.add,
                                  size: IconTheme.of(context).size!),
                              tooltip: loc.add,
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          PageEventAdd(
                                            existingEvent: null,
                                            tableName: controller.tableName,
                                            initialDate: date,
                                          )),
                                ).then((value) {
                                  if (value != null && value is Event) {
                                    controller.goToMonth(
                                      month:
                                          DateUtils.monthOnly(value.startDate!),
                                    );
                                    Navigator.pop(
                                        context, true); // ✅ 回傳 true 給外層
                                  }
                                });
                              },
                            ),
                          ]),
                      if (updatedEventsOfDay.isNotEmpty)
                        // 如果當日有事件，顯示事件列表，沒有的話顯示提示文字
                        ...updatedEventsOfDay.map((event) => EventCalendarCard(
                              tableName: tableName,
                              event: event,
                              index: 0,
                              onTap: () => Navigator.pop(context),
                              onDelete: event.isHoliday
                                  ? null
                                  : () async {
                                    final service = getIt<ServiceStorage>();
                                    await handleRemoveEvent(
                                      event: event,
                                      onDelete: () async {
                                        await service.deleteEvent(event: event, tableName: tableName);
                                      },
                                      loc: loc
                                    );
                                    Navigator.pop(context, true); // ✅ 回傳 true 給外層

                                  },
                              trailing: buildEventTrailing(
                                event: event,
                                setState: (fn) {
                                  fn();
                                },
                                refreshCallback: () async {
                                  await controller.loadCalendarEvents();
                                  controller.goToMonth(
                                    month:
                                        DateUtils.monthOnly(event.startDate!),
                                  );
                                  Navigator.pop(context, true); // ✅ 回傳 true 給外層
                                },
                                tableName: controller.tableName,
                                toTableName:
                                    constTableMemoryTrace, // ✅ 如果有其他目標 table，這裡替換掉
                                loc: loc,
                              ),
                            )),
                    ],
                  ),
                ),
              ),

              // 右上角關閉按鈕
              PositionedDirectional(
                end: kGapEI2.right,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 4,
                        offset: Offset(0, 2),
                        color: Colors.black26,
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: Icon(Icons.close, size: IconTheme.of(context).size!),
                    tooltip: loc.close,
                    onPressed: () =>
                        Navigator.pop(context, false), // ✅ 明確回傳 false
                  ),
                ),
              ),
            ],
          ),
        );
      });
    },
  );
  return result == true; // 預設 null 或 false 都視為沒變更
}

Future<bool> showAlarmSettingsDialog(
    {required Event event, required AppLocalizations loc}) async {
  ControllerCalendar controller = getIt<ControllerCalendar>();
  final service = getIt<ServiceStorage>();
  final Map<RepeatRule, String> repeatOptionsLabels = {
    RepeatRule.once: loc.repeat_options_once,
    RepeatRule.everyDay: loc.repeat_options_every_day,
    RepeatRule.everyWeek: loc.repeat_options_every_week,
    RepeatRule.everyTwoWeeks: loc.repeat_options_every_two_weeks,
    RepeatRule.everyMonth: loc.repeat_options_every_month,
    RepeatRule.everyTwoMonths: loc.repeat_options_every_two_months,
    RepeatRule.everyYear: loc.repeat_options_every_year,
  };

  final Map<ReminderOption, String> reminderOptionLabels = {
    ReminderOption.fifteenMin: loc.reminder_options_15_minutes_before,
    ReminderOption.thirtyMin: loc.reminder_options_30_minutes_before,
    ReminderOption.oneHour: loc.reminder_options_1_hour_before,
    ReminderOption.sameDay8am: loc.reminder_options_default_same_day_8am,
    ReminderOption.dayBefore8am: loc.reminder_options_default_day_before_8am,
    ReminderOption.twoDays: loc.reminder_options_2_days_before,
    ReminderOption.oneWeek: loc.reminder_options_1_week_before,
    ReminderOption.twoWeeks: loc.reminder_options_2_weeks_before,
    ReminderOption.oneMonth: loc.reminder_options_1_month_before,
  };

  RepeatRule selectedRepeat =
      repeatOptionsLabels.containsKey(event.repeatOptions)
          ? event.repeatOptions
          : RepeatRule.once;
  Set<ReminderOption> selectedReminders = {
    ...event.reminderOptions.where((r) => reminderOptionLabels.keys.contains(r))
  };

  final result = await showDialog(
    context: navigatorKey.currentState!.context,
    barrierDismissible: true,
    builder: (context) {
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
                      Text(loc.repeat_options,
                          style: TextStyle(color: Colors.black54)), // 你可以加翻譯關鍵字
                      kGapW16(),
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
                          items: repeatOptionsLabels.entries
                              .map((entry) => DropdownMenuItem(
                                  value: entry.key, child: Text(entry.value)))
                              .toList(),
                        ),
                      ),
                    ]),
                    kGapH4(),
                    // 提醒時間多選
                    Text(loc.reminder_options,
                        style: TextStyle(color: Colors.black54)), // 你可以加翻譯關鍵字
                    ...reminderOptionLabels.entries.map((entry) {
                      final key = entry.key;
                      final label = entry.value;
                      final isChecked = selectedReminders.contains(key);
                      return Row(
                        children: [
                          Checkbox(
                            value: isChecked,
                            onChanged: (checked) {
                              setState(() {
                                if (checked == true) {
                                  selectedReminders.add(key);
                                } else {
                                  selectedReminders.remove(key);
                                }
                              });
                            },
                          ),
                          Expanded(child: Text(label)), // ⬅️ 保證文字不擠
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
            onPressed: () {
              Navigator.pop(context, {
                'repeat': selectedRepeat.key(),
                'reminders': selectedReminders.toList()
              });
            },
            child: Text(loc.confirm, style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(loc.cancel, style: TextStyle(color: Colors.black)),
          ),
        ],
      );
    },
  );
  if (result == null) {
    return false;
  }
  final repeat = RepeatRuleExtension.fromKey(result['repeat'] as String);
  final reminders =
      (result['reminders'] as List).whereType<ReminderOption>().toList();

  Event updatedEvent =
      event.copyWith(newReminderOptions: reminders, newRepeatOptions: repeat);

  // 更新事件提醒設定
  await service.saveEvent(
      event: updatedEvent,
      isNew: false,
      tableName: controller.tableName,
      loc: loc);
  await controller.loadCalendarEvents();

  if (repeat.key().startsWith('every')) {
    await controller.checkAndGenerateNextEvents(loc: loc);
  }

  showSnackBar(
      message: reminders.isNotEmpty
          ? '${loc.set_alarm} '
              '${reminders.map((key) => reminderOptionLabels[key] ?? key).join(", ")}'
          : loc.cancel_alarm);

  return true; // 表示有更新
}
