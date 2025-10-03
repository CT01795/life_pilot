import 'dart:convert';
import 'package:life_pilot/models/model_event_base.dart';
import 'package:life_pilot/models/model_event_fields.dart';
import 'package:life_pilot/models/model_event_sub_item.dart';
import 'package:life_pilot/notification/core/reminder_option.dart';
import 'package:life_pilot/utils/core/utils_enum.dart';

class Event with EventBase {
  List<EventSubItem> subEvents;

  Event({
    String? id,
    List<EventSubItem>? subEvents,
  }) : subEvents = subEvents ?? [], // ✅ 明確初始化
       super() {
    this.id = id ?? this.id;
  }

  Map<String, dynamic> toJson() {
    final base = toJsonBase();
    return {
      ...base,
      EventFields.subEvents: subEvents.map((e) => e.toJson()).toList(),
    };
  }

  factory Event.fromJson(Map<String, dynamic> json) {
    final event = Event();
    event.fromJsonBase(json);
    event.subEvents = (json[EventFields.subEvents] as List<dynamic>?)
            ?.map((e) => EventSubItem.fromJson(e))
            .toList() ??
        [];
    return event;
  }

  Event copyWith({
    String? newId,
    DateTime? newStartDate,
    DateTime? newEndDate,
    RepeatRule? newRepeatOptions,
    List<ReminderOption>? newReminderOptions,
  }) {
    return Event(
      id: newId ?? id,
      subEvents: subEvents,
    )
     ..masterGraphUrl = masterGraphUrl
     ..masterUrl = masterUrl
     ..startDate = newStartDate ?? startDate
     ..endDate = newEndDate ?? endDate
     ..startTime = startTime
     ..endTime = endTime
     ..city = city
     ..location = location
     ..name = name
     ..type = type
     ..description = description
     ..fee = fee
     ..unit = unit
     ..account = account
     ..repeatOptions = newRepeatOptions ?? repeatOptions
     ..reminderOptions = newReminderOptions ?? reminderOptions
     ..isHoliday = isHoliday
     ..isTaiwanHoliday = isTaiwanHoliday
     ..isApproved = isApproved;
  }

  static List<ReminderOption> parseReminderOptions(dynamic jsonValue) {
    if (jsonValue == null) return const [ReminderOption.dayBefore8am];
    if (jsonValue is String) {
      try {
        return (jsonDecode(jsonValue) as List<dynamic>)
            .map((e) => ReminderOptionExtension.fromKey(key: e.toString()))
            .whereType<ReminderOption>()
            .toList();
      } catch (_) {
        return const [ReminderOption.dayBefore8am];
      }
    }
    if (jsonValue is List) {
      return jsonValue
          .map((e) => ReminderOptionExtension.fromKey(key: e.toString()))
          .whereType<ReminderOption>()
          .toList();
    }
    return const [ReminderOption.dayBefore8am];
  }
}
