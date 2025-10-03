import 'package:flutter/material.dart';
import 'package:life_pilot/models/model_event.dart';
import 'package:life_pilot/models/model_event_fields.dart';
import 'package:life_pilot/notification/core/reminder_option.dart';
import 'package:life_pilot/utils/core/utils_const.dart';
import 'package:life_pilot/utils/utils_date_time.dart';
import 'package:life_pilot/utils/core/utils_enum.dart';
import 'package:uuid/uuid.dart';

final _uuid = const Uuid();

DateTime? fromStringOrNull(String? date) =>
    date != null && date.isNotEmpty ? DateTime.tryParse(date) : null;

TimeOfDay? parseTimeOfDay(String? time) => time?.parseToTimeOfDay();

mixin EventBase {
  String id = _uuid.v4();
  String? masterGraphUrl;
  String? masterUrl;
  DateTime? startDate;
  DateTime? endDate;
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  String city = constEmpty;
  String location = constEmpty;
  String name = constEmpty;
  String type = constEmpty;
  String description = constEmpty;
  String fee = constEmpty;
  String unit = constEmpty;
  String? account = constEmpty;
  RepeatRule repeatOptions = RepeatRule.once;
  List<ReminderOption> reminderOptions = const [ReminderOption.dayBefore8am];
  bool isHoliday = false;
  bool isTaiwanHoliday = false;
  bool isApproved = false;

  void setFromForm({
    required String id,
    required String? masterGraphUrl,
    required String? masterUrl,
    required DateTime? startDate,
    required DateTime? endDate,
    required TimeOfDay? startTime,
    required TimeOfDay? endTime,
    required String city,
    required String location,
    required String name,
    required String type,
    required String description,
    required String fee,
    required String unit,
    required String? account,
    required RepeatRule repeatOptions,
    required List<ReminderOption> reminderOptions,
  }) {
    this.id = id;
    this.masterGraphUrl = masterGraphUrl;
    this.masterUrl = masterUrl;
    this.startDate = startDate;
    this.endDate = endDate;
    this.startTime = startTime;
    this.endTime = endTime;
    this.city = city;
    this.location = location;
    this.name = name;
    this.type = type;
    this.description = description;
    this.fee = fee;
    this.unit = unit;
    this.account = account;
    this.repeatOptions = repeatOptions;
    this.reminderOptions = reminderOptions;
  }

  void initializeFromParent(EventBase parent) {
    startDate = parent.startDate;
    endDate = parent.endDate;
    startTime = parent.startTime;
    endTime = parent.endTime;
    city = parent.city;
    location = parent.location;
  }

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
      EventFields.fee: fee,
      EventFields.unit: unit,
      EventFields.account: account,
      EventFields.repeatOptions: repeatOptions.key(),
      EventFields.reminderOptions:
          reminderOptions.map((e) => e.toKey()).toList(),
      EventFields.isHoliday: isHoliday,
      EventFields.isTaiwanHoliday: isTaiwanHoliday,
      EventFields.isApproved: isApproved,
    };
  }

  void fromJsonBase(Map<String, dynamic> json) {
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
    fee = json[EventFields.fee] ?? constEmpty;
    unit = json[EventFields.unit] ?? constEmpty;
    account = json[EventFields.account] ?? constEmpty;
    repeatOptions =
        RepeatRuleExtension.fromKey(json[EventFields.repeatOptions]);
    reminderOptions = Event.parseReminderOptions(json[EventFields.reminderOptions]);
    isHoliday = json[EventFields.isHoliday] == true;
    isTaiwanHoliday = json[EventFields.isTaiwanHoliday] == true;
    isApproved = json[EventFields.isApproved] == true;
  }
}
