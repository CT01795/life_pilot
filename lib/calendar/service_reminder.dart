import 'package:flutter/material.dart';
import 'package:life_pilot/utils/date_time.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/utils/enum.dart';
import 'package:life_pilot/utils/extension.dart';
import 'package:life_pilot/utils/mapper.dart';

class ServiceReminder {
  // 產生唯一通知 ID
  static int generateNotificationId({
    required String eventId,
    required CalendarReminderOption reminderOption,
  }) {
    final optionKey = CalendarReminderMapper.toKey(reminderOption: reminderOption);
    return eventId.hashCode ^ optionKey.hashCode;
  }

  // 取得提醒間隔
  static Duration getReminderDuration(
          {required CalendarReminderOption reminderOption}) =>
      CalendarReminderMapper.getDuration(reminderOption: reminderOption);

  // 顯示用的提醒文字（可客製化）
  static String getReminderLabel(
          {required AppLocalizations loc,
          required CalendarReminderOption reminderOption}) => reminderOption.label(loc);

  static DateTime getReminderTime(
      {required CalendarReminderOption reminderOption, required EventItem event, required DateTime targetTime}) {
    switch (reminderOption) {
      case CalendarReminderOption.sameDay8am:
        return DateTimeFormatter.getDateTime(
            event.startDate, TimeOfDay(hour: 8, minute: 0));
      case CalendarReminderOption.dayBefore8am:
        return DateTimeFormatter.getDateTime(
            event.startDate!.subtract(Duration(days: 1)),
            TimeOfDay(hour: 8, minute: 0));
      default:
        return targetTime.subtract(
            ServiceReminder.getReminderDuration(reminderOption: reminderOption));
    }
  }
}
