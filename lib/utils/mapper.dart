import 'package:life_pilot/utils/enum.dart';

// -------------------- Calendar --------------------
class CalendarReminderMapper {
  static const Map<CalendarReminderOption, String> _keyMap = {
    CalendarReminderOption.fifteenMin: '15_min',
    CalendarReminderOption.thirtyMin: '30_min',
    CalendarReminderOption.oneHour: '1_hour',
    CalendarReminderOption.sameDay8am: 'same_day_8am',
    CalendarReminderOption.dayBefore8am: 'day_before_8am',
    CalendarReminderOption.twoDays: '2_days',
    CalendarReminderOption.oneWeek: '1_week',
    CalendarReminderOption.twoWeeks: '2_weeks',
    CalendarReminderOption.oneMonth: '1_month',
  };

  static const Map<CalendarReminderOption, Duration> _durationMap = {
    CalendarReminderOption.fifteenMin: Duration(minutes: 15),
    CalendarReminderOption.thirtyMin: Duration(minutes: 30),
    CalendarReminderOption.oneHour: Duration(hours: 1),
    CalendarReminderOption.sameDay8am: Duration.zero,
    CalendarReminderOption.dayBefore8am: Duration.zero,
    CalendarReminderOption.twoDays: Duration(days: 2),
    CalendarReminderOption.oneWeek: Duration(days: 7),
    CalendarReminderOption.twoWeeks: Duration(days: 14),
    CalendarReminderOption.oneMonth: Duration(days: 30),
  };

  // 取得對應 key
  static String toKey({required CalendarReminderOption reminderOption}) =>
      _keyMap[reminderOption]!;

  // 根據 key 還原
  static CalendarReminderOption fromKey({required String key}) => _keyMap.entries
      .firstWhere((e) => e.value == key,
          orElse: () => const MapEntry(CalendarReminderOption.fifteenMin, '15_min'))
      .key;

  // 取得對應 Duration
  static Duration getDuration({required CalendarReminderOption reminderOption}) =>
      _durationMap[reminderOption]!;
}