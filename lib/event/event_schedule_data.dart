import 'package:flutter/material.dart';
import 'package:life_pilot/event/event_date_time_parser.dart';
import 'package:life_pilot/utils/extension.dart';

/// Shared date/time mapping for dashboard calendar and recommended content.
class EventScheduleData {
  const EventScheduleData({
    this.startDate,
    this.startTime,
    this.endDate,
    this.endTime,
  });

  final DateTime? startDate;
  final TimeOfDay? startTime;
  final DateTime? endDate;
  final TimeOfDay? endTime;

  factory EventScheduleData.fromJson(Map<String, dynamic> json) =>
      EventScheduleData(
        startDate: EventDateTimeParser.parseDate(json['start_date']),
        startTime: EventDateTimeParser.parseTime(json['start_time']),
        endDate: EventDateTimeParser.parseDate(json['end_date']),
        endTime: EventDateTimeParser.parseTime(json['end_time']),
      );

  Map<String, dynamic> toJson() => {
    'start_date': startDate?.formatDateString(),
    'start_time': startTime?.formatTimeString(),
    'end_date': endDate?.formatDateString(),
    'end_time': endTime?.formatTimeString(),
  };
}
