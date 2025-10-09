import 'dart:convert';
import 'package:life_pilot/models/model_event_base.dart';
import 'package:life_pilot/models/model_event_base_mixin.dart';
import 'package:life_pilot/notification/core/reminder_option.dart';
import 'package:life_pilot/utils/core/utils_enum.dart';

class EventItem with EventBaseMixin implements EventBase {
  // 用私有變數保存 subEvents
  List<EventItem> _subEvents = [];

  EventItem({
    String? id,
    List<EventItem>? subEvents,
  })  : super() {
    this.id = id ?? this.id;
    _subEvents = subEvents ?? [];
  }

  // ✅ 正確實作 EventBase 要求的 getter/setter
  @override
  List<EventItem> get subEvents => _subEvents;

  @override
  set subEvents(List<EventItem> value) => _subEvents = value;

  Map<String, dynamic> toJson() => toJsonBase();

  factory EventItem.fromJson({required Map<String, dynamic> json}) {
    final eventItem = EventItem();
    eventItem.fromJsonBase(json: json);
    return eventItem;
  }

  EventItem copyWith({
    String? newId,
    DateTime? newStartDate,
    DateTime? newEndDate,
    RepeatRule? newRepeatOptions,
    List<ReminderOption>? newReminderOptions,
    List<EventItem>? newSubEvents,
  }) {
    return EventItem(
      id: newId ?? id,
      subEvents: newSubEvents ?? subEvents,
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

  static List<ReminderOption> parseReminderOptions({dynamic jsonValue}) {
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
