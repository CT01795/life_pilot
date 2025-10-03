import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/notification/core/reminder_option.dart';

class ReminderUtils {
  // 用 eventId + reminderOption 組合產生 notification ID
  static int generateNotificationId(
          {required String eventId, required String optionKey}) =>
      eventId.hashCode ^ optionKey.hashCode;

  // 將 option 字串轉為時間差
  static Duration getReminderDuration(ReminderOption reminderOption) => reminderOption.duration;

  //顯示用的提醒文字（可客製化）
  static String getReminderLabel(
    {required AppLocalizations loc, required ReminderOption reminderOption}) =>
    reminderOption.getNotificationLabel(loc: loc);
}