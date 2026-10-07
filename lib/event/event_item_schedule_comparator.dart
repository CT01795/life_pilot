import 'package:flutter/material.dart';
import 'package:life_pilot/event/model_event_item.dart';

class EventItemScheduleComparator {
  const EventItemScheduleComparator._();

  static int compare(EventItem first, EventItem second) {
    var result = _compareDate(first.startDate, second.startDate);
    if (result != 0) return result;

    result = _compareTime(first.startTime, second.startTime);
    if (result != 0) return result;

    result = _compareDate(first.endDate, second.endDate);
    if (result != 0) return result;

    return _compareTime(first.endTime, second.endTime);
  }

  static int _compareDate(DateTime? first, DateTime? second) {
    final fallback = DateTime(2100);
    return (first ?? fallback).compareTo(second ?? fallback);
  }

  static int _compareTime(TimeOfDay? first, TimeOfDay? second) {
    if (first == null || second == null) return 0;
    final firstMinutes = first.hour * 60 + first.minute;
    final secondMinutes = second.hour * 60 + second.minute;
    return firstMinutes.compareTo(secondMinutes);
  }
}
