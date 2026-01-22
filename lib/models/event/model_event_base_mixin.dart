import 'package:flutter/material.dart';
import 'package:life_pilot/models/event/model_event_item.dart';
import 'package:life_pilot/models/event/model_event_base.dart';
import 'package:life_pilot/models/event/model_event_fields.dart';
import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/core/calendar/utils_calendar.dart';
import 'package:life_pilot/core/date_time.dart';
import 'package:uuid/uuid.dart';

final _uuid = const Uuid();
mixin EventBaseMixin implements EventBase {
  @override
  String id = _uuid.v4();
  @override
  String? masterGraphUrl;
  @override
  String? masterUrl;
  @override
  DateTime? startDate;
  @override
  DateTime? endDate;
  @override
  TimeOfDay? startTime;
  @override
  TimeOfDay? endTime;
  @override
  String city = constEmpty;
  @override
  String location = constEmpty;
  @override
  String name = constEmpty;
  @override
  String type = constEmpty;
  @override
  String description = constEmpty;
  //@override
  //String fee = constEmpty;
  @override
  String unit = constEmpty;
  @override
  String? account = constEmpty;
  @override
  RepeatRule repeatOptions = RepeatRule.once;
  @override
  List<ReminderOption> reminderOptions = const [ReminderOption.dayBefore8am];
  @override
  bool isHoliday = false;
  @override
  bool isTaiwanHoliday = false;
  @override
  bool isApproved = false;
  @override
  int? ageMin;
  @override
  int? ageMax;
  @override
  bool? isFree;
  @override
  double? priceMin;
  @override
  double? priceMax;
  @override
  bool? isOutdoor;

  // -------------------- JSON --------------------
  @override
  Map<String, dynamic> toJsonBase() {
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
      //EventFields.fee: fee,
      EventFields.unit: unit,
      EventFields.account: account,
      EventFields.repeatOptions: repeatOptions.key,
      EventFields.reminderOptions: reminderOptions
          .map((e) => ReminderMapper.toKey(reminderOption: e))
          .toList(),
      EventFields.isHoliday: isHoliday,
      EventFields.isTaiwanHoliday: isTaiwanHoliday,
      EventFields.isApproved: isApproved,
      EventFields.ageMin: ageMin,
      EventFields.ageMax: ageMax,
      EventFields.isFree: isFree,
      EventFields.priceMin: priceMin,
      EventFields.priceMax: priceMax,
      EventFields.isOutdoor: isOutdoor,
      EventFields.subEvents: subEvents.map((e) => e.toJson()).toList(),
    };
  }

  @override
  void fromJsonBase({required Map<String, dynamic> json}) {
    id = json[EventFields.id] ?? _uuid.v4();
    masterGraphUrl = json[EventFields.masterGraphUrl];
    masterUrl = json[EventFields.masterUrl];
    startDate = fromStringOrNull(json[EventFields.startDate]);
    endDate = fromStringOrNull(json[EventFields.endDate]);
    startTime = parseTimeOfDay(json[EventFields.startTime]);
    endTime = parseTimeOfDay(json[EventFields.endTime]);
    city = json[EventFields.city] ?? constEmpty;
    location = json[EventFields.location] ?? constEmpty;
    name = json[EventFields.name] ?? constEmpty;
    type = json[EventFields.type] ?? constEmpty;
    description = json[EventFields.description] ?? constEmpty;
    //fee = json[EventFields.fee] ?? constEmpty;
    unit = json[EventFields.unit] ?? constEmpty;
    account = json[EventFields.account] ?? constEmpty;
    repeatOptions =
        RepeatRuleExtension.fromKey(json[EventFields.repeatOptions]);
    reminderOptions = EventItem.parseReminderOptions(
        jsonValue: json[EventFields.reminderOptions]);
    isHoliday = json[EventFields.isHoliday] == true;
    isTaiwanHoliday = json[EventFields.isTaiwanHoliday] == true;
    isApproved = json[EventFields.isApproved] == true;
    ageMin = json[EventFields.ageMin];
    ageMax = json[EventFields.ageMax];
    isFree = json[EventFields.isFree];
    priceMin = json[EventFields.priceMin];
    priceMax = json[EventFields.priceMax];
    isOutdoor = json[EventFields.isOutdoor];
    final subEventsJson = json[EventFields.subEvents];
    if (subEventsJson is List && subEventsJson.isNotEmpty) {
      subEvents = subEventsJson
          .whereType<Map<String, dynamic>>() // 確保元素是 Map
          .map((e) => EventItem.fromJson(json: e))
          .toList();
    } else {
      subEvents = [];
    }
  }

  void initializeFromParent({required EventBase parent}) {
    startDate = parent.startDate;
    endDate = parent.endDate;
    startTime = parent.startTime;
    endTime = parent.endTime;
    city = parent.city;
    location = parent.location;
    ageMin = parent.ageMin;
    ageMax = parent.ageMax;
    isFree = parent.isFree;
    priceMin = parent.priceMin;
    priceMax = parent.priceMax;
    isOutdoor = parent.isOutdoor;
  }

  DateTime? fromStringOrNull(String? date) {
    if (date == null || date.isEmpty) return null;
    final d = DateTime.tryParse(date);
    return d?.toLocal();
  }

  TimeOfDay? parseTimeOfDay(String? time) => time?.parseToTimeOfDay();
}
