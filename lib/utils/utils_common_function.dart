import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:life_pilot/controllers/controller_calendar.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/models/model_event.dart';
import 'package:life_pilot/pages/page_recommended_event_add.dart';
import 'package:life_pilot/providers/provider_locale.dart';
import 'package:life_pilot/notification/notification.dart';
import 'package:life_pilot/notification/notification_common.dart';
import 'package:life_pilot/services/service_storage.dart';
import 'package:life_pilot/utils/utils_class_event_card.dart';
import 'package:life_pilot/utils/utils_const.dart';
import 'package:life_pilot/utils/utils_enum.dart';
import 'package:logger/logger.dart';

final Logger logger = Logger(); // 只建立一次，全域可用

void toggleLocale(ProviderLocale providerLocale) {
  final supportedLocales = [Locale(constLocaleEn), Locale(constLocaleZh)];
  final currentIndex = supportedLocales
      .indexWhere((l) => l.languageCode == providerLocale.locale.languageCode);
  final nextIndex = (currentIndex + 1) % supportedLocales.length;
  providerLocale.setLocale(supportedLocales[nextIndex]);
}

void showSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

extension DateTimeExtension on DateTime {
  String formatDateString({bool passYear = false, bool formatShow = false}) {
    if (passYear) {
      return '${month.toString().padLeft(2, constZero)}${formatShow ? '/' : '-'}${day.toString().padLeft(2, constZero)}';
    }
    return '${year.toString()}${formatShow ? '/' : '-'}${month.toString().padLeft(2, constZero)}${formatShow ? '/' : '-'}${day.toString().padLeft(2, constZero)}';
  }
}

extension TimeOfDayExtension on TimeOfDay {
  String formatTimeString() {
    return '${hour.toString().padLeft(2, constZero)}:${minute.toString().padLeft(2, constZero)}';
  }
}

extension StringTimeOfDay on String {
  TimeOfDay parseToTimeOfDay() {
    final parts = split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }
}

Future<void> handleCheckboxChanged({
  required BuildContext context,
  required ServiceStorage serviceStorage,
  required bool? value,
  required Event event,
  required Set<String> selectedEventIds,
  required void Function(void Function()) setState,
  required String addedMessage,
  required String tableName,
  required String toTableNamme,
}) async {
  final now = DateUtils.dateOnly(DateTime.now());
  final loc = AppLocalizations.of(context)!;
  if (value == true) {
    final existingEvents = await serviceStorage.getRecommendedEvents(
        tableName: toTableNamme, id: event.id);

    final isAlreadyAdded = existingEvents!.any((e) => e.id == event.id);

    final shouldAdd = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(
            '${isAlreadyAdded ? loc.event_add_tp_plan_error : "${loc.event_add}「${event.name}」"}？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(loc.add, style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(loc.cancel, style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );

    if (shouldAdd != true) {
      return;
    }
    
    setState(() {
      selectedEventIds.add(event.id);
    });

    if (isAlreadyAdded) {
      List<SubEventItem> sortedSubEvents = List.from(event.subEvents);

      sortedSubEvents.sort((a, b) => a.startDate!.compareTo(b.startDate!));

      sortedSubEvents.removeWhere((subEvent) =>
          subEvent.startDate != null &&
          !subEvent.startDate!.isAfter(event.startDate!));
      if (sortedSubEvents.isNotEmpty) {
        for (var tmpEvent in sortedSubEvents) {
          Event subEvent = tmpEvent.toEvent();
          subEvent.masterGraphUrl =
              tmpEvent.masterGraphUrl ?? event.masterGraphUrl;
          subEvent.masterUrl = tmpEvent.masterUrl ?? event.masterUrl;
          subEvent.city = tmpEvent.city.isEmpty ? event.city : tmpEvent.city;
          subEvent.location =
              tmpEvent.location.isEmpty ? event.location : tmpEvent.location;
          subEvent.unit = tmpEvent.unit.isEmpty ? event.unit : tmpEvent.unit;
          subEvent.account =
              tmpEvent.account!.isEmpty ? event.account : tmpEvent.account;
          Event updatedEvent = subEvent.copyWith(
              newStartDate: subEvent.startDate != null &&
                      !subEvent.startDate!.isAfter(now)
                  ? now
                  : subEvent.startDate,
              newEndDate:
                  subEvent.endDate != null && !subEvent.endDate!.isAfter(now)
                      ? now
                      : subEvent.endDate);
          await serviceStorage.deleteRecommendedEvent(
              updatedEvent, toTableNamme);
          await serviceStorage.saveRecommendedEvent(
              context, updatedEvent, true, toTableNamme);
        }
      } else {
        event.subEvents = sortedSubEvents;
        Event updatedEvent = event.copyWith(
            newStartDate:
                event.startDate != null && !event.startDate!.isAfter(now)
                    ? now
                    : event.startDate,
            newEndDate: event.endDate != null && !event.endDate!.isAfter(now)
                ? now
                : event.endDate);
        await serviceStorage.deleteRecommendedEvent(updatedEvent, toTableNamme);
        await serviceStorage.saveRecommendedEvent(
            context, updatedEvent, true, toTableNamme);
      }
      showSnackBar(context, addedMessage);
      return;
    }

    if (event.startDate != null && !event.startDate!.isAfter(now)) {
      event.startDate = now;
    }
    await serviceStorage.saveRecommendedEvent(
        context, event, true, toTableNamme);
    showSnackBar(context, addedMessage);
  } else {
    setState(() {
      selectedEventIds.remove(event.id);
    });
  }
}

Future<void> handleRemoveEvent({
  required BuildContext context,
  required Event event,
  required Future<void> Function() onDelete,
  required VoidCallback onSuccessSetState,
}) async {
  final loc = AppLocalizations.of(context)!;
  final shouldDelete = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      content: Text('${loc.event_delete}「${event.name}」？'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(loc.delete, style: TextStyle(color: Colors.red)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(loc.cancel, style: TextStyle(color: Colors.black)),
        ),
      ],
    ),
  );

  if (shouldDelete == true) {
    try {
      await onDelete();
      onSuccessSetState();
      showSnackBar(context, loc.delete_ok);
    } catch (e) {
      showSnackBar(context, '${loc.delete_error}: $e');
    }
  }
}

List<Event> filterValidEvents(List<Event> events) {
  final day = DateUtils.dateOnly(DateTime.now()).add(Duration(days: -1));

  return events.where((event) {
    if (event.endDate != null) {
      return !event.endDate!.isBefore(day);
    } else if (event.startDate != null) {
      return !event.startDate!.isBefore(day);
    } else {
      return false;
    }
  }).toList();
}

List<SubEventItem> sortSubEvents(List<SubEventItem> list) {
  list.sort((a, b) {
    final aStart = a.startDate ?? DateTime(9999);
    final bStart = b.startDate ?? DateTime(9999);
    final cmpStartDate = aStart.compareTo(bStart);
    if (cmpStartDate != 0) return cmpStartDate;

    final aStartTime = a.startTime ?? const TimeOfDay(hour: 23, minute: 59);
    final bStartTime = b.startTime ?? const TimeOfDay(hour: 23, minute: 59);
    final cmpStartTime = compareTimeOfDay(aStartTime, bStartTime);
    if (cmpStartTime != 0) return cmpStartTime;

    final aEnd = a.endDate ?? DateTime(9999);
    final bEnd = b.endDate ?? DateTime(9999);
    final cmpEndDate = aEnd.compareTo(bEnd);
    if (cmpEndDate != 0) return cmpEndDate;

    final aEndTime = a.endTime ?? const TimeOfDay(hour: 23, minute: 59);
    final bEndTime = b.endTime ?? const TimeOfDay(hour: 23, minute: 59);
    return compareTimeOfDay(aEndTime, bEndTime);
  });
  return list;
}

String formatEventDateTime(dynamic event, String type) {
  final bool isStart = type == constStartToS;
  if(!isStart){
    // End 處理：檢查與 start 是否同日
    if (isSameDay(event.startDate, event.endDate)) {
      if (isSameTime(event.startTime, event.endTime)) {
        return constEmpty;
      }
      return event.endTime == null ? constEmpty : ' - ${DateFormat(constDateFormatHHmm).format(event.endTime)}';
    } else if (isSameYear(event.startDate, event.endDate)) {
      return event.endTime == null ? ' - ${DateFormat(constDateFormatMMdd).format(DateUtils.getDateTime(event.endDate, event.endTime))}' : ' - ${DateFormat(constDateFormatMMddHHmm).format(DateUtils.getDateTime(event.endDate, event.endTime))}';
    }else{
      return event.endTime == null ? ' - ${DateFormat(constDateFormatyyyyMMdd).format(DateUtils.getDateTime(event.endDate, event.endTime))}' : ' - ${DateFormat(constDateFormatyyyyMMddHHmm).format(DateUtils.getDateTime(event.endDate, event.endTime))}';
    }
  }

  bool isNotMidnight(TimeOfDay? time) =>
      time != null;
  if (isSameYear(event.startDate, DateTime.now())) {
    if (isNotMidnight(event.startTime)) {
      return DateFormat(constDateFormatMMddHHmm).format(DateUtils.getDateTime(event.startDate, event.startTime));
    } else {
      return DateFormat(constDateFormatMMdd).format(event.startDate!);
    }
  } else {
    if (isNotMidnight(event.startTime)) {
      return DateFormat(constDateFormatyyyyMMddHHmm).format(DateUtils.getDateTime(event.startDate,event.startTime));
    } else {
      return DateFormat(constDateFormatyyyyMMdd).format(event.startDate);
    }
  }
}

bool isSameDayFutureTime(DateTime? a, TimeOfDay? time, DateTime? b) {
  if (a == null || b == null) return false;
  return a.year == b.year &&
      a.month == b.month &&
      a.day == b.day &&
      (time == null ||
          time.hour > b.hour ||
          (time.hour == b.hour && time.minute >= b.minute - 5));
}

bool isSameTime(TimeOfDay? a, TimeOfDay? b) {
  if (a == null || b == null) return true;
  return a.hour == b.hour && a.minute == b.minute;
}

bool isSameDay(DateTime? a, DateTime? b) {
  if (a == null || b == null) return true;
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

bool isSameYear(DateTime? a, DateTime? b) {
  if (a == null || b == null) return true;
  return a.year == b.year;
}

int compareTimeOfDay(TimeOfDay a, TimeOfDay b) {
  final aMinutes = a.hour * 60 + a.minute;
  final bMinutes = b.hour * 60 + b.minute;
  return aMinutes.compareTo(bMinutes);
}

Future<void> showMonthYearPicker({
  required BuildContext context,
  required DateTime initialDate,
  required void Function(DateTime) onChanged,
}) async {
  int selectedYear = initialDate.year;
  int selectedMonth = initialDate.month;

  await showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: Colors.white,
        content: StatefulBuilder(
          builder: (context, setState) {
            return SizedBox(
              child: Row(
                children: [
                  // 年份選擇
                  Expanded(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: selectedYear,
                      items: List.generate(20, (index) {
                        final year = DateTime.now().year - 4 + index;
                        return DropdownMenuItem(
                          value: year,
                          child: Center(child: Text('$year')),
                        );
                      }),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            selectedYear = value;
                          });
                          onChanged(DateTime(selectedYear, selectedMonth));
                        }
                      },
                    ),
                  ),
                  kGapW8(),
                  // 月份選擇
                  Expanded(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: selectedMonth,
                      items: List.generate(12, (index) {
                        return DropdownMenuItem(
                          value: index + 1,
                          child: Center(child: Text((index + 1).toString())),
                        );
                      }),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            selectedMonth = value;
                          });
                          onChanged(DateTime(selectedYear, selectedMonth));
                        }
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    },
  );
}

Future<bool> showCalendarEventsDialog(
    BuildContext context, ControllerCalendar controller, DateTime date) async {
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
      controller.goToMonth(DateUtils.monthOnly(result.startDate!));
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
                                  DateUtils.monthOnly(value.startDate!));
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
                              if(!event.isHoliday)
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
                                    final updated = await showAlarmSettingsDialog(
                                        context, event, controller);

                                    if (updated) {
                                      // 有更新鬧鐘設定，重新載入事件並刷新 UI
                                      await controller.loadEvents();
                                      // 呼叫 setState 讓 Dialog 內容重新渲染（Dialog 內部 StatefulBuilder）
                                      // 這裡簡單用 Navigator.pop 讓 Dialog 關閉，然後重新開啟，或用 setState 刷新列表
                                      await MyCustomNotification
                                          .cancelEventReminders(event); // 取消舊通知
                                      await checkExactAlarmPermission(context);
                                      await MyCustomNotification
                                          .scheduleEventReminders(loc, event,
                                              controller.tableName); // 安排新通知
                                      Navigator.pop(context); // 關閉事件 Dialog，回到上一頁
                                    }
                                  },
                                ),
                              if(!event.isHoliday)
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
                                          .loadEvents(); // 重新載入資料，確保資料最新
                                      await controller.checkAndGenerateNextEvents(
                                          context); // 使用最新資料
                                      controller.goToMonth(DateUtils.monthOnly(
                                          updated.startDate!));
                                      Navigator.pop(
                                          context, true); // ✅ 回傳 true 讓外層 refresh
                                    }
                                  },
                                ),
                              if(!event.isHoliday)
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
                                      await controller.loadEvents(); // ✅ 等待載入完成
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
                'repeat': selectedRepeat,
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
  final reminders = (result['reminders'] as List<String>)
      .map((e) => ReminderOptionExtension.fromKey(e))
      .whereType<ReminderOption>()
      .toList();

  // 把 reminders 存進事件，比如 event.reminderOptions = reminders;
  // 這邊假設 event 有 reminderOptions 屬性是 List<String>
  Event updatedEvent =
      event.copyWith(newReminderOptions: reminders, newRepeatOptions: repeat);

  // 更新事件提醒設定
  await controller.service
      .saveRecommendedEvent(context, updatedEvent, false, controller.tableName);
  await controller.loadEvents();

  if (repeat.key().startsWith('every')) {
    await controller.checkAndGenerateNextEvents(context);
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        reminders.isNotEmpty
            ? '${loc.set_alarm} '
                '${reminders.map((key) => reminderOptionLabels[key] ?? key).join(", ")}'
            : loc.cancel_alarm,
      ),
    ),
  );
  return true; // 表示有更新
}

class DateUtils {
  static DateTime dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static DateTime monthOnly(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }

  static DateTime getDateTime(DateTime? dt, TimeOfDay? td) {
    if (dt == null) {
      return DateTime.now();
    }
    if (td == null) {
      return dt;
    }
    return DateTime(
      dt.year,
      dt.month,
      dt.day,
      td.hour,
      td.minute,
    );
  }
}

Future<bool> checkExactAlarmPermission(BuildContext context) async {
  if (Platform.isAndroid) {
    const platform = MethodChannel('com.example.life_pilot/exact_alarm');
    try {
      final bool isGranted =
          await platform.invokeMethod('checkExactAlarmPermission');
      if (!isGranted) {
        try {
          await platform.invokeMethod('openExactAlarmSettings');
        } on PlatformException catch (e, stacktrace) {
          logger.e('Failed to open exact alarm settings:', error: e, stackTrace: stacktrace);
        }
      }
    } on PlatformException catch (e, stacktrace) {
      logger.e('Failed to open exact alarm settings:', error: e, stackTrace: stacktrace);
    }
  }
  return true;
}

Future<int?> getAndroidVersion() async {
  if (kIsWeb || !Platform.isAndroid) return null;

  final deviceInfo = DeviceInfoPlugin();
  final androidInfo = await deviceInfo.androidInfo;
  return androidInfo.version.sdkInt; // 回傳Android SDK版本號 (int)
}

void showLoginError(BuildContext context, String result, AppLocalizations loc) {
  String errorMessage;
  switch (result) {
    case ErrorFields.wrongUserPassword:
      errorMessage = loc.wrongUserPassword;
      break;
    case ErrorFields.tooManyRequestsError:
      errorMessage = loc.tooManyRequests;
      break;
    case ErrorFields.networkRequestFailedError:
      errorMessage = loc.networkError;
      break;
    case ErrorFields.invalidEmailError:
      errorMessage = loc.invalidEmail;
      break;
    case ErrorFields.noEmailError:
      errorMessage = loc.noEmailError;
      break;
    case ErrorFields.noPasswordError:
      errorMessage = loc.noPasswordError;
      break;
    case ErrorFields.loginError:
      errorMessage = loc.loginError;
      break;
    case ErrorFields.resetPasswordEmailNotFoundError:
      errorMessage = loc.resetPasswordEmailNotFound;
      break;
    case ErrorFields.emailAlreadyInUseError:
      errorMessage = loc.emailAlreadyInUse;
      break;
    case ErrorFields.weakPasswordError:
      errorMessage = loc.weakPassword;
      break;
    case ErrorFields.registerError:
      errorMessage = loc.registerError;
      break;
    case ErrorFields.logoutError:
      errorMessage = loc.logoutError;
      break;
    default:
      errorMessage = loc.unknownError;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(errorMessage)),
  );
}

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}
