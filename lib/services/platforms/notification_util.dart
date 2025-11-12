import 'package:flutter/material.dart';
import 'package:life_pilot/core/date_time.dart';
import 'package:life_pilot/models/event/model_event_item.dart';

List<EventItem> getTodayEventNotificationsList(
    {required List<EventItem> events}) {
  final now = DateTime.now();
  final nowSub1 = now.subtract(Duration(hours: 1));
  // 過濾出尚未發生的事件
  final todayEvents = events.where((e) {
    if (e.startDate == null) return false;
    if (e.id.contains('holiday')) return false;
    if(DateTimeCompare.isSameDayFutureTime(e.startDate, e.startTime, now)) return true;
    if(DateTimeCompare.isSameDayFutureTime(e.endDate, e.endTime, now)) return true;
    if(e.endDate == null && e.endTime != null && DateTimeCompare.isSameDayFutureTime(e.startDate, e.endTime, now)) return true;
    // 將日期跟時間組合成完整 DateTime
    DateTime? eventSDT = getDateTime(date: e.startDate, time: e.startTime);
    DateTime? eventDDT = getDateTime(date: e.endDate, time: e.endTime);
    return eventSDT!.isBefore(now) && e.endDate != null && eventDDT!.isAfter(nowSub1);
    // 只挑出事件開始時間晚於現在的事件
  }).toList();

  return todayEvents;
}

DateTime? getDateTime({
  required DateTime? date,
  required TimeOfDay? time,
}) {
  DateTime? returnDate;
  if (date != null && time != null) {
    returnDate = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  } else if (date != null) {
    returnDate = DateTime(
      date.year,
      date.month,
      date.day,
      23,
      59,
    );
  }
  return returnDate;
}
