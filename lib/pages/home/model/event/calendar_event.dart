import 'package:flutter/material.dart';
import 'package:life_pilot/event/service_event_public.dart';
import 'package:life_pilot/utils/extension.dart';

class CalendarEvent {
  final String id;
  final String name;

  final DateTime? startDate;
  final TimeOfDay? startTime;
  final DateTime? endDate;
  final TimeOfDay? endTime;
  final String? city;
  final String? location;
  final String? type;
  final bool isFree;

  final String? description;
  final String? masterUrl;

  final bool isCompleted;

  CalendarEvent({
    required this.id,
    required this.name,
    this.startDate,
    this.startTime,
    this.endDate,
    this.endTime,
    this.city,
    this.location,
    this.type,
    this.isFree = false,
    this.description,
    this.masterUrl,
    this.isCompleted = false,
  });

  factory CalendarEvent.fromJson(
    Map<String, dynamic> json,
  ) {
    return CalendarEvent(
      id: json['id'] as String,
      name: json['name'] ?? '',
      startDate: DateTimeParser.parseDate(json['start_date']),
      startTime: DateTimeParser.parseTime(json['start_time']),
      endDate: DateTimeParser.parseDate(json['end_date']),
      endTime: DateTimeParser.parseTime(json['end_time']),
      city: json['city'],
      location: json['location'],
      type: json['type'],
      isFree: json['is_free'] ?? false,
      description: json['description'],
      masterUrl: json['master_url'],
      isCompleted: json['is_completed'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'start_date': startDate?.formatDateString(),
      'start_time': startTime?.formatTimeString(),
      'end_date': endDate?.formatDateString(),
      'end_time': endTime?.formatTimeString(),
      'city': city,
      'location': location,
      'type': type,
      'is_free': isFree,
      'description': description,
      'master_url': masterUrl,
      'is_completed': isCompleted,
    };
  }
}
