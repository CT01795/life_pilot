import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:life_pilot/utils/utils_const.dart';

class DateTimeCompare {
  static bool isSameDayFutureTime(DateTime? a, TimeOfDay? time, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year &&
        a.month == b.month &&
        a.day == b.day &&
        (time == null ||
            time.hour > b.hour ||
            (time.hour == b.hour && time.minute >= b.minute - 5));
  }

  static bool isSameTime(TimeOfDay? a, TimeOfDay? b) {
    if (a == null || b == null) return true;
    return a.hour == b.hour && a.minute == b.minute;
  }

  static bool isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) {
      a ??= b;
      b ??= a;
      return true;
    }
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static bool isSameYear(DateTime? a, DateTime? b) {
    if (a == null || b == null) return true;
    return a.year == b.year;
  }

  static int compareTimeOfDay(TimeOfDay a, TimeOfDay b) {
    final aMinutes = a.hour * 60 + a.minute;
    final bMinutes = b.hour * 60 + b.minute;
    return aMinutes.compareTo(bMinutes);
  }

  static bool isCurrentMonth(DateTime currentMonth) {
    return currentMonth.year == DateTime.now().year && currentMonth.month == DateTime.now().month;
  }
}

String formatEventDateTime(dynamic event, String type) {
  final bool isStart = type == constStartToS;
  if (!isStart) {
    // End 處理：檢查與 start 是否同日
    if (DateTimeCompare.isSameDay(event.startDate, event.endDate)) {
      if (DateTimeCompare.isSameTime(event.startTime, event.endTime)) {
        return constEmpty;
      }
      //event.endDate ??= event.startDate;
      return event.endTime == null
          ? constEmpty
          : ' - ${DateFormat(constDateFormatHHmm).format(DateUtils.getDateTime(event.endDate, event.endTime))}';
    } else if (DateTimeCompare.isSameYear(event.startDate, event.endDate)) {
      return event.endTime == null
          ? ' - ${DateFormat(constDateFormatMMdd).format(DateUtils.getDateTime(event.endDate, event.endTime))}'
          : ' - ${DateFormat(constDateFormatMMddHHmm).format(DateUtils.getDateTime(event.endDate, event.endTime))}';
    } else {
      return event.endTime == null
          ? ' - ${DateFormat(constDateFormatyyyyMMdd).format(DateUtils.getDateTime(event.endDate, event.endTime))}'
          : ' - ${DateFormat(constDateFormatyyyyMMddHHmm).format(DateUtils.getDateTime(event.endDate, event.endTime))}';
    }
  }

  bool isNotMidnight(TimeOfDay? time) => time != null;
  if (DateTimeCompare.isSameYear(event.startDate, DateTime.now())) {
    if (isNotMidnight(event.startTime)) {
      return DateFormat(constDateFormatMMddHHmm)
          .format(DateUtils.getDateTime(event.startDate, event.startTime));
    } else {
      return DateFormat(constDateFormatMMdd).format(event.startDate!);
    }
  } else {
    if (isNotMidnight(event.startTime)) {
      return DateFormat(constDateFormatyyyyMMddHHmm)
          .format(DateUtils.getDateTime(event.startDate, event.startTime));
    } else {
      return DateFormat(constDateFormatyyyyMMdd).format(event.startDate);
    }
  }
}

class DateUtils {
  static DateTime dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static DateTime monthOnly(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }

  static DateTime getDateTime(DateTime? dt, TimeOfDay? td) {
    if (dt == null && td == null) {
      return DateTime.now();
    } else if (dt != null && td == null) {
      return dt;
    } else if (dt == null && td != null) {
      var now = DateTime.now();
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

Future<void> showMonthYearPicker({
  required BuildContext context,
  required DateTime initialDate,
  required void Function(DateTime) onChanged,
}) async {
  int selectedYear = initialDate.year;
  int selectedMonth = initialDate.month;

  await showDialog(
    context: context,
    barrierDismissible: true,
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
