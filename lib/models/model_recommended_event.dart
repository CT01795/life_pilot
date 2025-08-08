import 'package:flutter/material.dart';
import 'package:life_pilot/utils/utils_common_function.dart';
import 'package:uuid/uuid.dart';

final _uuid = const Uuid(); 

DateTime? fromIso8601StringOrNull(String? date) =>
    date != null ? DateTime.parse(date) : null;

TimeOfDay? parseTimeOfDay(String? time) => time?.parseToTimeOfDay();

class RecommendedEvent {
  String id;
  String? masterGraphUrl; 
  String? masterUrl;
  DateTime? startDate;
  DateTime? endDate;
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  String city;
  String location;
  String name;
  String type;
  String description;
  String fee;
  String unit;
  List<SubRecommendedEventItem> subRecommendedEvents;
  List<SubGraph> subGraphs;
  String? account;

  RecommendedEvent({
    String? id,
    this.masterGraphUrl,
    this.masterUrl,
    this.startDate,
    this.endDate,
    this.startTime,
    this.endTime,
    this.city = '',
    this.location = '',
    this.name = '',
    this.type = '',
    this.description = '',
    this.fee = '',
    this.unit = '',
    List<SubRecommendedEventItem>? subRecommendedEvents,
    List<SubGraph>? subGraphs,
    this.account = '',
  })  : id = id ?? _uuid.v4(),
        subRecommendedEvents = subRecommendedEvents ?? [],
        subGraphs = subGraphs ?? [];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'master_graph_url': masterGraphUrl,
      'master_url': masterUrl,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'start_time': startTime?.formatTimeString(),
      'end_time': endTime?.formatTimeString(),
      'city': city,
      'location': location,
      'name': name,
      'type': type,
      'description': description,
      'fee': fee,
      'unit': unit,
      'sub_recommended_events':
          subRecommendedEvents.map((e) => e.toJson()).toList(),
      'sub_graphs': subGraphs.map((e) => e.toJson()).toList(),
      'account': account,
    };
  }

  factory RecommendedEvent.fromJson(Map<String, dynamic> json) {
    return RecommendedEvent(
      id: json['id'],
      masterGraphUrl: json['master_graph_url'],
      masterUrl: json['master_url'],
      startDate: fromIso8601StringOrNull(json['start_date']),
      endDate: fromIso8601StringOrNull(json['end_date']),
      startTime: parseTimeOfDay(json['start_time']),
      endTime: parseTimeOfDay(json['end_time']),
      city: json['city'] ?? '',
      location: json['location'] ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? '',
      description: json['description'] ?? '',
      fee: json['fee'] ?? '',
      unit: json['unit'] ?? '',
      subRecommendedEvents: (json['sub_recommended_events'] as List<dynamic>?)
              ?.map((e) => SubRecommendedEventItem.fromJson(e))
              .toList() ??
          [],
      subGraphs: (json['sub_graphs'] as List<dynamic>?)
              ?.map((e) => SubGraph.fromJson(e))
              .toList() ??
          [],
      account: json['account'] ?? '',
    );
  }
}

class SubRecommendedEventItem {
  final String id;
  String? subUrl;
  DateTime? startDate;
  DateTime? endDate;
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  String city;
  String location;
  String name;
  String type;
  String description;
  String fee;
  String unit;

  SubRecommendedEventItem({
    String? id,
    this.subUrl,
    this.startDate,
    this.endDate,
    this.startTime,
    this.endTime,
    this.city = '',
    this.location = '',
    this.name = '',
    this.type = '',
    this.description = '',
    this.fee = '',
    this.unit = '',
  }) : id = id ?? _uuid.v4();

  SubRecommendedEventItem copyWith({
    String? id,
    String? subUrl,
    DateTime? startDate,
    DateTime? endDate,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    String? city,
    String? location,
    String? name,
    String? type,
    String? description,
    String? fee,
    String? unit,
  }) {
    return SubRecommendedEventItem(
      id: id ?? this.id,
      subUrl: subUrl ?? this.subUrl,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      city: city ?? this.city,
      location: location ?? this.location,
      name: name ?? this.name,
      type: type ?? this.type,
      description: description ?? this.description,
      fee: fee ?? this.fee,
      unit: unit ?? this.unit,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sub_url': subUrl,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'start_time': startTime?.formatTimeString(),
      'end_time': endTime?.formatTimeString(),
      'city': city,
      'location': location,
      'name': name,
      'type': type,
      'description': description,
      'fee': fee,
      'unit': unit,
    };
  }

  factory SubRecommendedEventItem.fromJson(Map<String, dynamic> json) {
    return SubRecommendedEventItem(
      id: json['id'],
      subUrl: json['sub_url'],
      startDate: fromIso8601StringOrNull(json['start_date']),
      endDate: fromIso8601StringOrNull(json['end_date']),
      startTime: parseTimeOfDay(json['start_time']),
      endTime: parseTimeOfDay(json['end_time']),
      city: json['city'] ?? '',
      location: json['location'] ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? '',
      description: json['description'] ?? '',
      fee: json['fee'] ?? '',
      unit: json['unit'] ?? '',
    );
  }
}

class SubGraph {
  final String url;

  SubGraph({required this.url});

  factory SubGraph.fromJson(Map<String, dynamic> json) =>
      SubGraph(url: json['url']);

  Map<String, dynamic> toJson() => {'url': url};
}
