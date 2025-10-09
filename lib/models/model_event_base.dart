import 'package:flutter/material.dart';
import 'package:life_pilot/models/model_event_item.dart';
import 'package:life_pilot/notification/core/reminder_option.dart';
import 'package:life_pilot/utils/core/utils_enum.dart';

abstract class EventBase {
  String get id;
  String? get masterGraphUrl;
  String? get masterUrl;
  DateTime? get startDate;
  DateTime? get endDate;
  TimeOfDay? get startTime;
  TimeOfDay? get endTime;
  String get city;
  String get location;
  String get name;
  String get type;
  String get description;
  String get fee;
  String get unit;
  String? get account;
  RepeatRule get repeatOptions;
  List<ReminderOption> get reminderOptions;
  bool get isHoliday;
  bool get isTaiwanHoliday;
  bool get isApproved;
  // ⬇️ 改為 getter + setter
  List<EventItem> get subEvents;
  set subEvents(List<EventItem> value);

  Map<String, dynamic> toJsonBase();
  void fromJsonBase({required Map<String, dynamic> json});
}
