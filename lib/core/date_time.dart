import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:life_pilot/core/const.dart';

// -------------------- DateTime Compare --------------------
class DateTimeCompare {
  // 是否同一天且給定時間在另一時間之後
  static bool isSameDayFutureTime(DateTime? a, TimeOfDay? time, DateTime? b) {
    if (a == null || b == null) return false;
    if (a.year != b.year || a.month != b.month || a.day != b.day) return false;
    if (time == null) return true;
    return time.hour > b.hour || (time.hour == b.hour && time.minute >= b.minute - 5); // 提前 5 分鐘視為相同
  }

  static bool isSameTime(TimeOfDay? a, TimeOfDay? b) {
    if (a == null || b == null) return true;
    return a.hour == b.hour && a.minute == b.minute;
  }

  static bool isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return true;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static bool isSameYear(DateTime? a, DateTime? b) {
    if (a == null || b == null) return true;
    return a.year == b.year;
  }

  static int compareTimeOfDay(TimeOfDay? a, TimeOfDay? b) {
    if (a == null || b == null) return 0;
    return (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute);
  }

  static bool isCurrentMonth(DateTime currentMonth) {
    final now = DateTime.now();
    return currentMonth.year == now.year && currentMonth.month == now.month;
  }
}

// -------------------- DateTime Formatter --------------------
class DateTimeFormatter {
  static String formatEventDateTime(dynamic event, String type) {
    final bool isStart = type == CalendarMisc.startToS;
    if (!isStart) {
      // End 處理：檢查與 start 是否同日
      return _formatEnd(event);
    }

    bool hasTime = event.startTime != null;
    bool sameYear = DateTimeCompare.isSameYear(event.startDate, DateTime.now());
    final format = hasTime
        ? (sameYear ? DateFormats.mmddHHmm : DateFormats.yyyyMMddHHmm)
        : (sameYear ? DateFormats.mmdd : DateFormats.yyyyMMdd);
    final dateTime = DateUtils.getDateTime(event.startDate, event.startTime);
    return DateFormat(format).format(dateTime);
  }

  // -------------------- END --------------------
  static String _formatEnd(dynamic event) {
    final startDate = event.startDate;
    final endDate = event.endDate;
    final startTime = event.startTime;
    final endTime = event.endTime;

    // 同一天 & 同時間 → 無需顯示
    if (DateTimeCompare.isSameDay(startDate, endDate) &&
        DateTimeCompare.isSameTime(startTime, endTime)) {
      return constEmpty;
    }

    // 若 endTime 存在 → 加上時間，否則只顯示日期
    String format;
    if (DateTimeCompare.isSameDay(startDate, endDate)) {
      // 同一天
      format = endTime == null ? constEmpty : DateFormats.hhmm;
    } else if (DateTimeCompare.isSameYear(startDate, endDate)) {
      // 同一年
      format = endTime == null ? DateFormats.mmdd : DateFormats.mmddHHmm;
    } else {
      // 不同年
      format =
          endTime == null ? DateFormats.yyyyMMdd : DateFormats.yyyyMMddHHmm;
    }

    if (format.isEmpty) return constEmpty;

    final dateTime = DateUtils.getDateTime(endDate, endTime);
    return ' - ${DateFormat(format).format(dateTime)}';
  }

  static String formatTime(DateTime time) {
    final now = DateTime.now();
    return time.year == now.year
        ? time.month == now.month && time.day == now.day
            ? DateFormat('HH:mm').format(time)
            : DateFormat('M/d HH:mm').format(time)
        : DateFormat('yyyy/M/d HH:mm').format(time);
  }
}

// -------------------- Date Utils --------------------
class DateUtils {
  static DateTime dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static DateTime monthOnly(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }

  static DateTime getDateTime(DateTime? dt, TimeOfDay? td) {
    final now = DateTime.now();
    if (dt == null && td == null) {
      return now;
    } else if (dt != null && td == null) {
      return dt;
    } else if (dt == null && td != null) {
      return DateTime(
        now.year,
        now.month,
        now.day,
        td.hour,
        td.minute,
      );
    } else {
      return DateTime(
        dt!.year,
        dt.month,
        dt.day,
        td!.hour,
        td.minute,
      );
    }
  }
}

// -------------------- DateTime Extensions --------------------
extension DateTimeExtension on DateTime {
  String formatDateString({bool passYear = false, bool formatShow = false}) {
    if (passYear) {
      return '${month.toString().padLeft(2, CalendarMisc.zero)}${formatShow ? '/' : '-'}${day.toString().padLeft(2, CalendarMisc.zero)}';
    }
    return '${year.toString()}${formatShow ? '/' : '-'}${month.toString().padLeft(2, CalendarMisc.zero)}${formatShow ? '/' : '-'}${day.toString().padLeft(2, CalendarMisc.zero)}';
  }
}

extension TimeOfDayExtension on TimeOfDay {
  String formatTimeString() {
    return '${hour.toString().padLeft(2, CalendarMisc.zero)}:${minute.toString().padLeft(2, CalendarMisc.zero)}';
  }
}

extension StringTimeOfDay on String {
  TimeOfDay? parseToTimeOfDay() {
    final parts = split(':');
    if (parts.length < 2 ||
        int.tryParse(parts[0]) == null ||
        int.tryParse(parts[1]) == null) {
      return null;
    }
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }
}

Future<void> showMonthYearPicker({
  required BuildContext context,
  required DateTime initialDate,
  required void Function(DateTime) onChanged,
}) async {
  int selectedYear = initialDate.year;
  int selectedMonth = initialDate.month;
  final years = List.generate(20, (i) => DateTime.now().year - 4 + i);
  await showDialog(
    context: context,
    barrierDismissible: true,
    builder: (context) {
      return AlertDialog(
        backgroundColor: Colors.white,
        content: StatefulBuilder(
          builder: (context, setState) {
            return Row(
                children: [
                  // 年份選擇
                  Expanded(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: selectedYear,
                      items: years.map((y) => DropdownMenuItem(value: y, child: Center(child: Text('$y')))).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            selectedYear = value;
                          });
                          //onChanged(DateTime(selectedYear, selectedMonth));
                        }
                      },
                    ),
                  ),
                  Gaps.w8,
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
                          //onChanged(DateTime(selectedYear, selectedMonth));
                        }
                      },
                    ),
                  ),
                ],
              );
          },
        ),
        actions: [
          TextButton(
              onPressed: () {
                onChanged(DateTime(selectedYear, selectedMonth));
                Navigator.pop(context);
              },
              child: const Text('Go！👆'))
        ],
      );
    },
  );
}
