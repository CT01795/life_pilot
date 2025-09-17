import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:life_pilot/notification/notification_common.dart';
import 'package:life_pilot/utils/utils_const.dart';
import 'package:life_pilot/utils/utils_date_time.dart';
import 'package:life_pilot/utils/utils_enum.dart';
import 'package:uuid/uuid.dart';

final _uuid = const Uuid();

DateTime? fromStringOrNull(String? date) =>
    date != null ? DateTime.parse(date) : null;

TimeOfDay? parseTimeOfDay(String? time) => time?.parseToTimeOfDay();

class EventFields {
  static const String id = 'id';
  static const String masterGraphUrl = 'master_graph_url';
  static const String masterUrl = 'master_url';
  static const String startDate = 'start_date';
  static const String endDate = 'end_date';
  static const String startTime = 'start_time';
  static const String endTime = 'end_time';
  static const String city = 'city';
  static const String location = 'location';
  static const String name = 'name';
  static const String type = 'type';
  static const String description = 'description';
  static const String fee = 'fee';
  static const String unit = 'unit';
  static const String subEvents = 'sub_events';
  static const String account = 'account';
  static const String repeatOptions = 'repeat_options';
  static const String reminderOptions = 'reminder_options';
  static const String isHoliday = "is_holiday";
  static const String isTaiwanHoliday = "is_taiwan_holiday";
}

class Event {
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
  List<SubEventItem> subEvents;
  String? account;
  RepeatRule repeatOptions;
  List<ReminderOption> reminderOptions;
  bool isHoliday;
  bool isTaiwanHoliday;

  Event({
    String? id,
    this.masterGraphUrl,
    this.masterUrl,
    this.startDate,
    this.endDate,
    this.startTime,
    this.endTime,
    this.city = constEmpty,
    this.location = constEmpty,
    this.name = constEmpty,
    this.type = constEmpty,
    this.description = constEmpty,
    this.fee = constEmpty,
    this.unit = constEmpty,
    List<SubEventItem>? subEvents,
    this.account = constEmpty,
    this.repeatOptions = RepeatRule.once,
    this.reminderOptions = const [ReminderOption.dayBefore8am],
    bool? isHoliday,
    bool? isTaiwanHoliday,
  })  : id = id ?? _uuid.v4(),
        isHoliday = isHoliday ?? false,
        isTaiwanHoliday = isTaiwanHoliday ?? false,
        subEvents = subEvents ?? [];

  Map<String, dynamic> toJson() {
    return {
      EventFields.id: id,
      EventFields.masterGraphUrl: masterGraphUrl,
      EventFields.masterUrl: masterUrl,
      EventFields.startDate: startDate?.formatDateString(),
      EventFields.endDate: endDate?.formatDateString(),
      EventFields.startTime: startTime?.formatTimeString(),
      EventFields.endTime: endTime?.formatTimeString(),
      EventFields.city: city,
      EventFields.location: location,
      EventFields.name: name,
      EventFields.type: type,
      EventFields.description: description,
      EventFields.fee: fee,
      EventFields.unit: unit,
      EventFields.subEvents: subEvents.map((e) => e.toJson()).toList(),
      EventFields.account: account,
      EventFields.repeatOptions: repeatOptions.key(),
      EventFields.reminderOptions:
          reminderOptions.map((e) => e.toKey()).toList(),
      EventFields.isHoliday: isHoliday,
      EventFields.isTaiwanHoliday: isTaiwanHoliday,
    };
  }

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json[EventFields.id] ?? constEmpty,
      masterGraphUrl: json[EventFields.masterGraphUrl],
      masterUrl: json[EventFields.masterUrl],
      startDate: fromStringOrNull(json[EventFields.startDate]),
      endDate: fromStringOrNull(json[EventFields.endDate]),
      startTime: parseTimeOfDay(json[EventFields.startTime]),
      endTime: parseTimeOfDay(json[EventFields.endTime]),
      city: json[EventFields.city] ?? constEmpty,
      location: json[EventFields.location] ?? constEmpty,
      name: json[EventFields.name] ?? constEmpty,
      type: json[EventFields.type] ?? constEmpty,
      description: json[EventFields.description] ?? constEmpty,
      fee: json[EventFields.fee] ?? constEmpty,
      unit: json[EventFields.unit] ?? constEmpty,
      subEvents: (json[EventFields.subEvents] as List<dynamic>?)
              ?.map((e) => SubEventItem.fromJson(e))
              .toList() ??
          [],
      account: json[EventFields.account] ?? constEmpty,
      repeatOptions:
          RepeatRuleExtension.fromKey(json[EventFields.repeatOptions]),
      reminderOptions:
          Event.parseReminderOptions(json[EventFields.reminderOptions]),
      isHoliday: json[EventFields.isHoliday] is bool
          ? json[EventFields.isHoliday] as bool
          : false,
      isTaiwanHoliday: json[EventFields.isTaiwanHoliday] is bool
          ? json[EventFields.isTaiwanHoliday] as bool
          : false,
    );
  }

  // ✅ copyWith 實作
  Event copyWith({
    String? newId,
    DateTime? newStartDate,
    DateTime? newEndDate,
    RepeatRule? newRepeatOptions,
    List<ReminderOption>? newReminderOptions,
  }) {
    return Event(
      id: newId ?? id,
      masterGraphUrl: masterGraphUrl,
      masterUrl: masterUrl,
      startDate: newStartDate ?? startDate,
      endDate: newEndDate ?? endDate,
      startTime: startTime,
      endTime: endTime,
      city: city,
      location: location,
      name: name,
      type: type,
      description: description,
      fee: fee,
      unit: unit,
      subEvents: subEvents,
      account: account,
      repeatOptions: newRepeatOptions ?? repeatOptions,
      reminderOptions: newReminderOptions ?? reminderOptions,
      isHoliday: isHoliday,
      isTaiwanHoliday: isTaiwanHoliday,
    );
  }

  static List<ReminderOption> parseReminderOptions(dynamic jsonValue) {
    if (jsonValue == null) return const [ReminderOption.dayBefore8am];
    if (jsonValue is String) {
      try {
        return (jsonDecode(jsonValue) as List<dynamic>)
            .map((e) => ReminderOptionExtension.fromKey(e.toString()))
            .whereType<ReminderOption>()
            .toList();
      } catch (_) {
        return const [ReminderOption.dayBefore8am];
      }
    }
    if (jsonValue is List) {
      return jsonValue
          .map((e) => ReminderOptionExtension.fromKey(e.toString()))
          .whereType<ReminderOption>()
          .toList();
    }
    return const [ReminderOption.dayBefore8am];
  }
}

class SubEventItem {
  final String id;
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
  String? account;
  RepeatRule repeatOptions;
  List<ReminderOption> reminderOptions;
  bool isHoliday;
  bool isTaiwanHoliday;

  SubEventItem({
    String? id,
    this.masterGraphUrl,
    this.masterUrl,
    this.startDate,
    this.endDate,
    this.startTime,
    this.endTime,
    this.city = constEmpty,
    this.location = constEmpty,
    this.name = constEmpty,
    this.type = constEmpty,
    this.description = constEmpty,
    this.fee = constEmpty,
    this.unit = constEmpty,
    this.account = constEmpty,
    this.repeatOptions = RepeatRule.once,
    this.reminderOptions = const [ReminderOption.dayBefore8am],
    bool? isHoliday,
    bool? isTaiwanHoliday,
  })  : id = id ?? _uuid.v4(),
        isHoliday = isHoliday ?? false,
        isTaiwanHoliday = isTaiwanHoliday ?? false;

  Map<String, dynamic> toJson() {
    return {
      EventFields.id: id,
      EventFields.masterGraphUrl: masterGraphUrl,
      EventFields.masterUrl: masterUrl,
      EventFields.startDate: startDate?.formatDateString(),
      EventFields.endDate: endDate?.formatDateString(),
      EventFields.startTime: startTime?.formatTimeString(),
      EventFields.endTime: endTime?.formatTimeString(),
      EventFields.city: city,
      EventFields.location: location,
      EventFields.name: name,
      EventFields.type: type,
      EventFields.description: description,
      EventFields.fee: fee,
      EventFields.unit: unit,
      EventFields.account: account,
      EventFields.repeatOptions: repeatOptions.key(),
      EventFields.reminderOptions:
          reminderOptions.map((e) => e.toKey()).toList(),
      EventFields.isHoliday: isHoliday,
      EventFields.isTaiwanHoliday: isTaiwanHoliday,
    };
  }

  factory SubEventItem.fromJson(Map<String, dynamic> json) {
    return SubEventItem(
      id: json[EventFields.id] ?? constEmpty,
      masterGraphUrl: json[EventFields.masterGraphUrl],
      masterUrl: json[EventFields.masterUrl],
      startDate: fromStringOrNull(json[EventFields.startDate]),
      endDate: fromStringOrNull(json[EventFields.endDate]),
      startTime: parseTimeOfDay(json[EventFields.startTime]),
      endTime: parseTimeOfDay(json[EventFields.endTime]),
      city: json[EventFields.city] ?? constEmpty,
      location: json[EventFields.location] ?? constEmpty,
      name: json[EventFields.name] ?? constEmpty,
      type: json[EventFields.type] ?? constEmpty,
      description: json[EventFields.description] ?? constEmpty,
      fee: json[EventFields.fee] ?? constEmpty,
      unit: json[EventFields.unit] ?? constEmpty,
      account: json[EventFields.account] ?? constEmpty,
      repeatOptions:
          RepeatRuleExtension.fromKey(json[EventFields.repeatOptions]),
      reminderOptions:
          Event.parseReminderOptions(json[EventFields.reminderOptions]),
      isHoliday: json[EventFields.isHoliday] is bool
          ? json[EventFields.isHoliday] as bool
          : false,
      isTaiwanHoliday: json[EventFields.isTaiwanHoliday] is bool
          ? json[EventFields.isTaiwanHoliday] as bool
          : false,
    );
  }

  SubEventItem copyWith({
    String? newId,
    DateTime? newStartDate,
    DateTime? newEndDate,
    RepeatRule? newRepeatOptions,
    List<ReminderOption>? newReminderOptions,
  }) {
    return SubEventItem(
      id: newId ?? id,
      masterGraphUrl: masterGraphUrl,
      masterUrl: masterUrl,
      startDate: newStartDate ?? startDate,
      endDate: newEndDate ?? endDate,
      startTime: startTime,
      endTime: endTime,
      city: city,
      location: location,
      name: name,
      type: type,
      description: description,
      fee: fee,
      unit: unit,
      account: account,
      repeatOptions: newRepeatOptions ?? repeatOptions,
      reminderOptions: newReminderOptions ?? reminderOptions,
      isHoliday: isHoliday,
      isTaiwanHoliday: isTaiwanHoliday,
    );
  }

  Event toEvent() {
    return Event(
        id: id,
        masterGraphUrl: masterGraphUrl,
        masterUrl: masterUrl,
        startDate: startDate,
        endDate: endDate,
        startTime: startTime,
        endTime: endTime,
        city: city,
        location: location,
        name: name,
        type: type,
        description: description,
        fee: fee,
        unit: unit,
        subEvents: [],
        account: account,
        repeatOptions: repeatOptions,
        reminderOptions: reminderOptions,
        isHoliday: isHoliday,
        isTaiwanHoliday: isTaiwanHoliday);
  }
}
