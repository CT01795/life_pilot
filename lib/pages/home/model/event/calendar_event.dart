import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:life_pilot/event/service_event_public.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/event_country.dart';
import 'package:life_pilot/utils/extension.dart';

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
    return CalendarEvent(
      id: json[Fields.id]?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      startDate: DateTimeParser.parseDate(json['start_date']),
      startTime: DateTimeParser.parseTime(json['start_time']),
      endDate: DateTimeParser.parseDate(json['end_date']),
      endTime: DateTimeParser.parseTime(json['end_time']),
      country: EventCountry.normalize(json[EventFields.country]?.toString()),
      city: json['city']?.toString(),
      location: json['location']?.toString(),
      type: json['type']?.toString(),
      isFree: json['is_free'] == true,
      description: json['description']?.toString(),
      masterUrl: json['master_url']?.toString(),
      subEvents: _parseSubEvents(json[EventFields.subEvents]),
      isCompleted: json['is_completed'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      Fields.id: id,
      'name': name,
      'start_date': startDate?.formatDateString(),
      'start_time': startTime?.formatTimeString(),
      'end_date': endDate?.formatDateString(),
      'end_time': endTime?.formatTimeString(),
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
          final start = DateTimeParser.parseDate(subEvent['start_date']);
          if (start == null) return false;
          final startDate = DateUtils.dateOnly(start);
          final endDate = DateUtils.dateOnly(
            DateTimeParser.parseDate(subEvent['end_date']) ?? start,
          );
          return !selectedDate.isBefore(startDate) &&
              !selectedDate.isAfter(endDate);
        })
        .toList(growable: false);
  }

  static List<Map<String, dynamic>> _parseSubEvents(dynamic value) {
    dynamic parsed = value;
    if (value is String && value.trim().isNotEmpty) {
      try {
        parsed = jsonDecode(value);
      } on FormatException {
        return const [];
      }
    }
    if (parsed is! List) return const [];
    return parsed
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }
}
