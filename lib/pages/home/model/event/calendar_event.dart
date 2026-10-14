import 'package:flutter/material.dart';
import 'package:life_pilot/event/event_date_time_parser.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/event_country.dart';
import 'package:life_pilot/event/event_schedule_data.dart';
import 'package:life_pilot/utils/value_parser.dart';
import 'package:life_pilot/utils/json_object_list_parser.dart';

class CalendarEvent {
  final String id;
  final String name;

  final DateTime? startDate;
  final TimeOfDay? startTime;
  final DateTime? endDate;
  final TimeOfDay? endTime;
  final String country;
  final String? city;
  final String? location;
  final String? type;
  final bool isFree;

  final String? description;
  final String? masterUrl;
  final List<Map<String, dynamic>> subEvents;

  final bool isCompleted;

  CalendarEvent({
    required this.id,
    required this.name,
    this.startDate,
    this.startTime,
    this.endDate,
    this.endTime,
    this.country = 'TW',
    this.city,
    this.location,
    this.type,
    this.isFree = false,
    this.description,
    this.masterUrl,
    this.subEvents = const [],
    this.isCompleted = false,
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    final schedule = EventScheduleData.fromJson(json);
    return CalendarEvent(
      id: parseStringValue(json[Fields.id]),
      name: parseStringValue(json['name']),
      startDate: schedule.startDate,
      startTime: schedule.startTime,
      endDate: schedule.endDate,
      endTime: schedule.endTime,
      country: EventCountry.normalize(
        parseOptionalStringValue(json[EventFields.country]),
      ),
      city: parseOptionalStringValue(json['city']),
      location: parseOptionalStringValue(json['location']),
      type: parseOptionalStringValue(json['type']),
      isFree: json['is_free'] == true,
      description: parseOptionalStringValue(json['description']),
      masterUrl: parseOptionalStringValue(json['master_url']),
      subEvents: parseJsonObjectList(json[EventFields.subEvents]),
      isCompleted: json['is_completed'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      Fields.id: id,
      'name': name,
      ...EventScheduleData(
        startDate: startDate,
        startTime: startTime,
        endDate: endDate,
        endTime: endTime,
      ).toJson(),
      EventFields.country: country,
      'city': city,
      'location': location,
      'type': type,
      'is_free': isFree,
      'description': description,
      'master_url': masterUrl,
      EventFields.subEvents: subEvents,
      'is_completed': isCompleted,
    };
  }

  List<Map<String, dynamic>> subEventsForDate(DateTime date) {
    final selectedDate = DateUtils.dateOnly(date);
    return subEvents
        .where((subEvent) {
          final start = EventDateTimeParser.parseDate(subEvent['start_date']);
          if (start == null) return false;
          final startDate = DateUtils.dateOnly(start);
          final endDate = DateUtils.dateOnly(
            EventDateTimeParser.parseDate(subEvent['end_date']) ?? start,
          );
          return !selectedDate.isBefore(startDate) &&
              !selectedDate.isAfter(endDate);
        })
        .toList(growable: false);
  }
}
