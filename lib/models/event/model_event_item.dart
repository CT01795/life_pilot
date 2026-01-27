import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:life_pilot/models/event/model_event_base.dart';
import 'package:life_pilot/models/event/model_event_base_mixin.dart';
import 'package:life_pilot/core/calendar/utils_calendar.dart';

class EventItem with EventBaseMixin implements EventBase {
  // 用私有變數保存 subEvents
  List<EventItem> _subEvents = [];

  EventItem({
    String? id,
    List<EventItem>? subEvents,
    String? masterGraphUrl,
    String? masterUrl,
    DateTime? startDate,
    DateTime? endDate,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    String? city,
    String? location,
    String? name,
    String? type,
    String? description,
    //String? fee,
    String? unit,
    String? account,
    RepeatRule? repeatOptions,
    List<ReminderOption>? reminderOptions,
    bool? isHoliday,
    bool? isTaiwanHoliday,
    bool? isApproved,
    num? ageMin,
    num? ageMax,
    bool? isFree,
    num? priceMin,
    num? priceMax,
    bool? isOutdoor,
    bool? isLike,
    bool? isDislike,
  }) : super() {
    this.id = id ?? this.id;
    _subEvents = subEvents ?? [];
    this.masterGraphUrl = masterGraphUrl ?? this.masterGraphUrl;
    this.masterUrl = masterUrl ?? this.masterUrl;
    this.startDate = startDate ?? this.startDate;
    this.endDate = endDate ?? this.endDate;
    this.startTime = startTime ?? this.startTime;
    this.endTime = endTime ?? this.endTime;
    this.city = city ?? this.city;
    this.location = location ?? this.location;
    this.name = name ?? this.name;
    this.type = type ?? this.type;
    this.description = description ?? this.description;
    //this.fee = fee ?? this.fee;
    this.unit = unit ?? this.unit;
    this.account = account ?? this.account;
    this.repeatOptions = repeatOptions ?? this.repeatOptions;
    this.reminderOptions = reminderOptions ?? this.reminderOptions;
    this.isHoliday = isHoliday ?? this.isHoliday;
    this.isTaiwanHoliday = isTaiwanHoliday ?? this.isTaiwanHoliday;
    this.isApproved = isApproved ?? this.isApproved;
    this.ageMin = ageMin ?? this.ageMin;
    this.ageMax = ageMax ?? this.ageMax;
    this.isFree = isFree ?? this.isFree;
    this.priceMin = priceMin ?? this.priceMin;
    this.priceMax = priceMax ?? this.priceMax;
    this.isOutdoor = isOutdoor ?? this.isOutdoor;
    this.isLike = isLike ?? this.isLike;
    this.isDislike = isDislike ?? this.isDislike;
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
    String? newMasterGraphUrl,
    String? newMasterUrl,
    DateTime? newStartDate,
    DateTime? newEndDate,
    TimeOfDay? newStartTime,
    TimeOfDay? newEndTime,
    String? newCity,
    String? newLocation,
    String? newName,
    String? newType,
    String? newDescription,
    //String? newFee,
    String? newUnit,
    String? newAccount,
    RepeatRule? newRepeatOptions,
    List<ReminderOption>? newReminderOptions,
    bool? newIsHoliday,
    bool? newIsTaiwanHoliday,
    bool? newIsApproved,
    num? newAgeMin,
    num? newAgeMax,
    bool? newIsFree,
    num? newPriceMin,
    num? newPriceMax,
    bool? newIsOutdoor,
    bool? newIsLike,
    bool? newIsDislike,
    List<EventItem>? newSubEvents,
  }) {
    return EventItem(
        id: newId ?? id,
        subEvents: newSubEvents ?? subEvents,
        masterGraphUrl: newMasterGraphUrl ?? masterGraphUrl,
        masterUrl: newMasterUrl ?? masterUrl,
        startDate: newStartDate ?? startDate,
        endDate: newEndDate ?? endDate,
        startTime: newStartTime ?? startTime,
        endTime: newEndTime ?? endTime,
        city: newCity ?? city,
        location: newLocation ?? location,
        name: newName ?? name,
        type: newType ?? type,
        description: newDescription ?? description,
        //fee: newFee ?? fee,
        unit: newUnit ?? unit,
        account: newAccount ?? account,
        repeatOptions: newRepeatOptions ?? repeatOptions,
        reminderOptions: newReminderOptions ?? reminderOptions,
        isHoliday: newIsHoliday ?? isHoliday,
        isTaiwanHoliday: newIsTaiwanHoliday ?? isTaiwanHoliday,
        isApproved: newIsApproved ?? isApproved,
        ageMin: newAgeMin ?? ageMin,
        ageMax: newAgeMax ?? ageMax,
        isFree: newIsFree ?? isFree,
        priceMin: newPriceMin ?? priceMin,
        priceMax: newPriceMax ?? priceMax,
        isOutdoor: newIsOutdoor ?? isOutdoor,
        isLike: newIsLike?? isLike,
        isDislike: newIsDislike ?? isDislike,
      );
  }

  static List<ReminderOption> parseReminderOptions({dynamic jsonValue}) {
    const defaultOption = [ReminderOption.dayBefore8am];
    if (jsonValue == null) return defaultOption;

    try {
      final list = (jsonValue is String)
        ? (jsonDecode(jsonValue) as List<dynamic>)
        : (jsonValue is List ? jsonValue : []);
    return list.map((e) => ReminderMapper.fromKey(key: e.toString()))
          .whereType<ReminderOption>()
          .toList();
    } catch (_) {
      return defaultOption;
    }
  }
}

class EventWithRow {
  final EventItem event;
  final int rowIndex;

  EventWithRow({required this.event, required this.rowIndex});
}
