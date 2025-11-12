import 'package:flutter/material.dart' hide DateUtils;
import 'package:life_pilot/core/calendar/utils_calendar.dart';
import 'package:life_pilot/core/date_time.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/models/event/model_event_item.dart';

class ServiceReminder {
  // 產生唯一通知 ID
  static int generateNotificationId({
    required String eventId,
    required ReminderOption reminderOption,
  }) {
    final optionKey = ReminderMapper.toKey(reminderOption: reminderOption);
    return eventId.hashCode ^ optionKey.hashCode;
  }

  // 取得提醒間隔
  static Duration getReminderDuration(
          {required ReminderOption reminderOption}) =>
      ReminderMapper.getDuration(reminderOption: reminderOption);

  // 顯示用的提醒文字（可客製化）
  static String getReminderLabel(
          {required AppLocalizations loc,
          required ReminderOption reminderOption}) => reminderOption.label(loc);

  static DateTime getReminderTime(
      {required ReminderOption reminderOption, required EventItem event, required DateTime targetTime}) {
    switch (reminderOption) {
      case ReminderOption.sameDay8am:
        return DateUtils.getDateTime(
            event.startDate, TimeOfDay(hour: 8, minute: 0));
      case ReminderOption.dayBefore8am:
        return DateUtils.getDateTime(
            event.startDate!.subtract(Duration(days: 1)),
            TimeOfDay(hour: 8, minute: 0));
      default:
        return targetTime.subtract(
            ServiceReminder.getReminderDuration(reminderOption: reminderOption));
    }
  }
}
