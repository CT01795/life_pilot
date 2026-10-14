import 'package:flutter/material.dart';
import 'package:life_pilot/event/event_schedule_data.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/event_country.dart';
import 'package:life_pilot/utils/value_parser.dart';

class RecommendedEvent {
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

  RecommendedEvent({
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
  });

  factory RecommendedEvent.fromJson(Map<String, dynamic> json) {
    final schedule = EventScheduleData.fromJson(json);
    return RecommendedEvent(
      id: parseStringValue(json[Fields.id]),
      name: parseStringValue(json['name']),
      startDate: schedule.startDate,
      startTime: schedule.startTime,
      endDate: schedule.endDate,
      endTime: schedule.endTime,
      country: EventCountry.normalize(
        parseStringValue(json[EventFields.country]),
      ),
      city: parseStringValue(json['city']),
      location: parseStringValue(json['location']),
      type: parseStringValue(json['type']),
      isFree: json['is_free'] ?? false,
      description: parseStringValue(json['description']),
      masterUrl: parseStringValue(json['master_url']),
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
    };
  }
}
