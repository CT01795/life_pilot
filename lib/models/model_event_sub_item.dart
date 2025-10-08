import 'package:life_pilot/models/model_event.dart';
import 'package:life_pilot/notification/core/reminder_option.dart';
import 'package:life_pilot/utils/core/utils_enum.dart';
import 'package:uuid/uuid.dart';

import 'model_event_base.dart';

final _uuid = const Uuid();

class EventSubItem with EventBase {
  EventSubItem({String? id}) {
    this.id = id ?? _uuid.v4(); // 使用 EventBase 提供的 id
  }

  Map<String, dynamic> toJson() => toJsonBase();

  factory EventSubItem.fromJson({required Map<String, dynamic> json}) {
    final item = EventSubItem();
    item.fromJsonBase(json: json);
    return item;
  }

  EventSubItem copyWith({
    String? newId,
    DateTime? newStartDate,
    DateTime? newEndDate,
    RepeatRule? newRepeatOptions,
    List<ReminderOption>? newReminderOptions,
  }) {
    return EventSubItem(id: newId ?? id)
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

  Event toEvent() => Event(
        id: id,
        subEvents: [],
      )
        ..masterGraphUrl = masterGraphUrl
        ..masterUrl = masterUrl
        ..startDate = startDate
        ..endDate = endDate
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
        ..repeatOptions = repeatOptions
        ..reminderOptions = reminderOptions
        ..isHoliday = isHoliday
        ..isTaiwanHoliday = isTaiwanHoliday
        ..isApproved = isApproved;
}
