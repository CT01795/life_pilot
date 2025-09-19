import 'package:flutter/material.dart' hide DateUtils;
import 'package:intl/intl.dart';
import 'package:life_pilot/controllers/controller_auth.dart';
import 'package:life_pilot/controllers/controller_calendar.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/models/model_event.dart';
import 'package:life_pilot/notification/notification_common.dart';
import 'package:life_pilot/pages/page_recommended_event_add.dart';
import 'package:life_pilot/providers/provider_locale.dart';
import 'package:life_pilot/utils/utils_common_function.dart';
import 'package:life_pilot/utils/utils_const.dart';
import 'package:life_pilot/utils/utils_date_time.dart';
import 'package:life_pilot/utils/utils_enum.dart';
import 'package:life_pilot/utils/utils_event_card.dart';
import 'package:life_pilot/utils/utils_mobile.dart';
import 'package:provider/provider.dart';

import '../notification/notification.dart';

// 通用的確認 Dialog
Future<bool> showConfirmationDialog({
  required BuildContext context,
  required String content,
  required String confirmText,
  required String cancelText,
}) async {
  return await showDialog<bool>(
    context: context,
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

Future<bool> showCalendarEventsDialog(
    BuildContext context, ControllerCalendar controller, DateTime date) async {
  ControllerAuth auth = Provider.of<ControllerAuth>(context,listen:false);
  ProviderLocale providerLocale = Provider.of<ProviderLocale>(context, listen: false);
  final loc = AppLocalizations.of(context)!;
  final dateOnly = DateUtils.dateOnly(date);
  // 篩選包含該日期的事件
  final eventsOfDay = controller.getEventsOfDay(dateOnly);

  // ✅ 如果沒有事件，直接跳轉新增事件頁
  if (eventsOfDay.isEmpty) {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PageRecommendedEventAdd(
          existingRecommendedEvent: null,
          tableName: controller.tableName,
          initialDate: date,
        ),
      ),
    );
    if (result != null && result is Event) {
      controller.goToMonth(DateUtils.monthOnly(result.startDate!), auth.currentAccount, providerLocale.locale);
      return true;
    }
    return false;
  }

  // ✅ 有事件時，顯示 Dialog
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (context) {
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
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(
                        DateFormat(constDateFormatMMdd).format(date),
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      IconButton(
                        icon:
                            Icon(Icons.add, size: IconTheme.of(context).size!),
                        tooltip: loc.add,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => PageRecommendedEventAdd(
                                      existingRecommendedEvent: null,
                                      tableName: controller.tableName,
                                      initialDate: date,
                                    )),
                          ).then((value) {
                            if (value != null && value is Event) {
                              controller.goToMonth(
                                  DateUtils.monthOnly(value.startDate!), auth.currentAccount, providerLocale.locale);
                              Navigator.pop(context, true); // ✅ 回傳 true 給外層
                            }
                          });
                        },
                      ),
                    ]),

                    // 如果當日有事件，顯示事件列表，沒有的話顯示提示文字
                    ...eventsOfDay.map((event) => EventCalendarCard(
                          event: event,
                          index: 0,
                          onTap: () => Navigator.pop(context),
                          trailing: Wrap(
                            spacing: 4,
                            children: [
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
                                    color: event.reminderOptions.isNotEmpty
                                        ? Colors.blue
                                        : Colors.black,
                                  ),
                                  tooltip: loc.set_alarm,
                                  onPressed: () async {
                                    final updated =
                                        await showAlarmSettingsDialog(
                                            context, event, controller);

                                    if (updated) {
                                      // 有更新鬧鐘設定，重新載入事件並刷新 UI
                                      await controller.loadEvents(auth.currentAccount, providerLocale.locale);
                                      // 呼叫 setState 讓 Dialog 內容重新渲染（Dialog 內部 StatefulBuilder）
                                      // 這裡簡單用 Navigator.pop 讓 Dialog 關閉，然後重新開啟，或用 setState 刷新列表
                                      await MyCustomNotification
                                          .cancelEventReminders(event); // 取消舊通知
                                      await checkExactAlarmPermission(context);
                                      await MyCustomNotification
                                          .scheduleEventReminders(loc, event,
                                              controller.tableName, auth.currentAccount); // 安排新通知
                                      Navigator.pop(
                                          context); // 關閉事件 Dialog，回到上一頁
                                    }
                                  },
                                ),
                              if (!event.isHoliday)
                                // ✏️ 編輯
                                IconButton(
                                  icon: Icon(Icons.edit,
                                      size: IconTheme.of(context).size!),
                                  tooltip: loc.edit,
                                  onPressed: () async {
                                    final updated = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            PageRecommendedEventAdd(
                                          existingRecommendedEvent: event,
                                          tableName: controller.tableName,
                                        ),
                                      ),
                                    );
                                    if (updated != null && updated is Event) {
                                      controller.updateCachedEvent(
                                          event, updated); // 🛠 更新快取
                                      await controller
                                          .loadEvents(auth.currentAccount, providerLocale.locale); // 重新載入資料，確保資料最新
                                      await controller
                                          .checkAndGenerateNextEvents(
                                              context); // 使用最新資料
                                      controller.goToMonth(DateUtils.monthOnly(
                                          updated.startDate!), auth.currentAccount, providerLocale.locale);
                                      Navigator.pop(context,
                                          true); // ✅ 回傳 true 讓外層 refresh
                                    }
                                  },
                                ),
                              if (!event.isHoliday)
                                // 🗑️ 刪除
                                IconButton(
                                  icon: Icon(Icons.delete,
                                      size: IconTheme.of(context).size!),
                                  tooltip: loc.delete,
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) {
                                        return AlertDialog(
                                          title: Text(loc.confirm_delete),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, true),
                                              child: Text(loc.delete,
                                                  style: TextStyle(
                                                      color: Colors.red)),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, false),
                                              child: Text(loc.cancel,
                                                  style: TextStyle(
                                                      color: Colors.black)),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                    if (confirm == true) {
                                      await controller.service
                                          .deleteRecommendedEvent(
                                              event, controller.tableName);
                                      await controller.loadEvents(auth.currentAccount, providerLocale.locale); // ✅ 等待載入完成
                                      Navigator.pop(context, true); // ✅ 回傳 true
                                    }
                                  },
                                ),
                            ],
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
    },
  );
  return result == true; // 預設 null 或 false 都視為沒變更
}

Future<bool> showAlarmSettingsDialog(
    BuildContext context, Event event, ControllerCalendar controller) async {
  ControllerAuth auth = Provider.of<ControllerAuth>(context, listen: false); 
  ProviderLocale providerLocale = Provider.of<ProviderLocale>(context, listen: false);    
  final loc = AppLocalizations.of(context)!;

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
    context: context,
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
  final reminderKeys = (result['reminders'] as List)
    .whereType<String>()
    .toList();
  final reminders = reminderKeys
    .map((key) => ReminderOptionExtension.fromKey(key))
    .whereType<ReminderOption>()
    .toList();

  Event updatedEvent =
      event.copyWith(newReminderOptions: reminders, newRepeatOptions: repeat);

  // 更新事件提醒設定
  await controller.service
      .saveRecommendedEvent(context, updatedEvent, false, controller.tableName);
  await controller.loadEvents(auth.currentAccount, providerLocale.locale);

  if (repeat.key().startsWith('every')) {
    await controller.checkAndGenerateNextEvents(context);
  }

  showSnackBar(
    context,
    reminders.isNotEmpty
      ? '${loc.set_alarm} '
          '${reminders.map((key) => reminderOptionLabels[key] ?? key).join(", ")}'
      : loc.cancel_alarm);

  return true; // 表示有更新
}