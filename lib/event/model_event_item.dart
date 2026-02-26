import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/date_time.dart';
import 'package:life_pilot/utils/enum.dart';
import 'package:life_pilot/utils/mapper.dart';
import 'package:uuid/uuid.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/extension.dart';

final _uuid = Uuid();

/// ===============================================================
/// 🧩 Base Interface
/// ===============================================================
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
  //String get fee;
  String get unit;
  String? get account;
  CalendarRepeatRule get repeatOptions;
  List<CalendarReminderOption> get reminderOptions;
  bool get isHoliday;
  bool get isTaiwanHoliday;
  bool get isApproved;
  num? get ageMin;
  num? get ageMax;
  bool? get isFree;
  num? get priceMin;
  num? get priceMax;
  bool? get isOutdoor;
  bool? get isLike;
  bool? get isDislike;
  int? get pageViews;
  int? get cardClicks;
  int? get saves;
  int? get registrationClicks;
  int? get likeCounts;
  int? get dislikeCounts;
  List<EventItem> get subEvents;

  Map<String, dynamic> toJson();
}

/// ===============================================================
/// 🧩 Concrete Model
/// ===============================================================
class EventItem implements EventBase {
  @override
  String id;
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
  String city;
  @override
  String location;
  @override
  String name;
  @override
  String type;
  @override
  String description;
  @override
  String unit;
  @override
  String? account;
  @override
  CalendarRepeatRule repeatOptions;
  @override
  List<CalendarReminderOption> reminderOptions;
  @override
  bool isHoliday;
  @override
  bool isTaiwanHoliday;
  @override
  bool isApproved;
  @override
  num? ageMin;
  @override
  num? ageMax;
  @override
  bool? isFree;
  @override
  num? priceMin;
  @override
  num? priceMax;
  @override
  bool? isOutdoor;
  @override
  bool? isLike;
  @override
  bool? isDislike;
  @override
  int? pageViews;
  @override
  int? cardClicks;
  @override
  int? saves;
  @override
  int? registrationClicks;
  @override
  int? likeCounts;
  @override
  int? dislikeCounts;

  List<EventItem> _subEvents;

  @override
  List<EventItem> get subEvents => _subEvents;
 set subEvents(List<EventItem> itemList) => _subEvents = itemList;

  EventItem({
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
    this.unit = '',
    this.account,
    this.repeatOptions = CalendarRepeatRule.once,
    this.reminderOptions =
        const [CalendarReminderOption.dayBefore8am],
    this.isHoliday = false,
    this.isTaiwanHoliday = false,
    this.isApproved = false,
    this.ageMin,
    this.ageMax,
    this.isFree,
    this.priceMin,
    this.priceMax,
    this.isOutdoor,
    this.isLike,
    this.isDislike,
    this.pageViews,
    this.cardClicks,
    this.saves,
    this.registrationClicks,
    this.likeCounts,
    this.dislikeCounts,
    List<EventItem>? subEvents,
  }) : id = id ?? _uuid.v4(),
        _subEvents = List<EventItem>.from(subEvents ?? []);

  // -------------------- JSON --------------------
  @override
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
      //EventFields.fee: fee,
      EventFields.unit: unit,
      EventFields.account: account,
      EventFields.repeatOptions: repeatOptions.key,
      EventFields.reminderOptions: reminderOptions
          .map((e) => CalendarReminderMapper.toKey(reminderOption: e))
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
      //EventFields.isLike: isLike,
      //EventFields.isDislike: isDislike,
      EventFields.pageViews: pageViews,
      EventFields.cardClicks: cardClicks,
      EventFields.saves: saves,
      EventFields.registrationClicks: registrationClicks,
      EventFields.likeCounts: likeCounts,
      EventFields.dislikeCounts: dislikeCounts,
      EventFields.subEvents: subEvents.map((e) => e.toJson()).toList(),
    };
  }

  factory EventItem.fromJson(
      {required Map<String, dynamic> json}) {
    final subEventsJson = json[EventFields.subEvents];

    return EventItem(
      id: json[EventFields.id] ?? _uuid.v4(),
      masterGraphUrl: json[EventFields.masterGraphUrl],
      masterUrl: json[EventFields.masterUrl],
      startDate: fromStringOrNull(json[EventFields.startDate]),
      endDate: fromStringOrNull(json[EventFields.endDate]),
      startTime: parseTimeOfDay(json[EventFields.startTime]),
      endTime: parseTimeOfDay(json[EventFields.endTime]),
      city: json[EventFields.city] ?? '',
      location: json[EventFields.location] ?? '',
      name: json[EventFields.name] ?? '',
      type: json[EventFields.type] ?? '',
      description: json[EventFields.description] ?? '',
      unit: json[EventFields.unit] ?? '',
      account: json[EventFields.account],
      repeatOptions:
        CalendarRepeatRuleExtension.fromKey(json[EventFields.repeatOptions]),
      reminderOptions: EventItem.parseReminderOptions(
        jsonValue: json[EventFields.reminderOptions]),
      isHoliday: json[EventFields.isHoliday] == true,
      isTaiwanHoliday: json[EventFields.isTaiwanHoliday] == true,
      isApproved: json[EventFields.isApproved] == true,
      ageMin: json[EventFields.ageMin],
      ageMax: json[EventFields.ageMax],
      isFree: json[EventFields.isFree],
      priceMin: json[EventFields.priceMin],
      priceMax: json[EventFields.priceMax],
      isOutdoor: json[EventFields.isOutdoor],
      isLike: json[EventFields.isLike],
      isDislike: json[EventFields.isDislike],
      pageViews: json[EventFields.pageViews],
      cardClicks: json[EventFields.cardClicks],
      saves: json[EventFields.saves],
      registrationClicks: json[EventFields.registrationClicks],
      likeCounts: json[EventFields.likeCounts],
      dislikeCounts: json[EventFields.dislikeCounts],
      subEvents: subEventsJson is List
          ? subEventsJson
              .whereType<Map<String, dynamic>>()
              .map((e) => EventItem.fromJson(json: e))
              .toList()
          : [],
    );
  }

  // -------------------- copyWith --------------------
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
    CalendarRepeatRule? newRepeatOptions,
    List<CalendarReminderOption>? newReminderOptions,
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
    int? newPageViews,
    int? newCardClicks,
    int? newSaves,
    int? newRegistrationClicks,
    int? newLikeCounts,
    int? newDislikeCounts,
    List<EventItem>? newSubEvents,
  }) {
    return EventItem(
      id: newId ?? id,
      subEvents: newSubEvents ?? _subEvents,
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
      isLike: newIsLike ?? isLike,
      isDislike: newIsDislike ?? isDislike,
      pageViews: newPageViews ?? pageViews,
      cardClicks: newCardClicks ?? cardClicks,
      saves: newSaves ?? saves,
      registrationClicks: newRegistrationClicks ?? registrationClicks,
      likeCounts: newLikeCounts ?? likeCounts,
      dislikeCounts: newDislikeCounts ?? dislikeCounts,
    );
  }
  
  static List<CalendarReminderOption> parseReminderOptions(
      {dynamic jsonValue}) {
    const defaultOption = [CalendarReminderOption.dayBefore8am];
    if (jsonValue == null) return defaultOption;

    try {
      final list = (jsonValue is String)
          ? (jsonDecode(jsonValue) as List<dynamic>)
          : (jsonValue is List ? jsonValue : []);
      return list
          .map((e) => CalendarReminderMapper.fromKey(key: e.toString()))
          .whereType<CalendarReminderOption>()
          .toList();
    } catch (_) {
      return defaultOption;
    }
  }

  static DateTime? fromStringOrNull(String? date) {
    if (date == null || date.isEmpty) return null;
    final d = DateTime.tryParse(date);
    return d?.toLocal();
  }

  static TimeOfDay? parseTimeOfDay(String? time) => time?.parseToTimeOfDay();
}

class EventWithRow {
  final EventItem event;
  final int rowIndex;

  EventWithRow({required this.event, required this.rowIndex});
}

class EventViewModel {
  final String id;
  final String name;
  final bool showDate;
  final String dateRange;
  List<String> tags;
  final bool hasLocation;
  final String locationDisplay;
  final String? masterUrl;
  final String description;
  final List<EventViewModel> subEvents;
  final bool canDelete;
  final bool showSubEvents;
  final DateTime? startDate;
  final DateTime? endDate;
  final num? ageMin;
  final num? ageMax;
  final bool? isFree;
  final num? priceMin;
  final num? priceMax;
  final bool? isOutdoor;
  final bool? isLike;
  final bool? isDislike;
  final int? pageViews;
  final int? cardClicks;
  final int? saves;
  final int? registrationClicks;
  final int? likeCounts;
  final int? dislikeCounts;

  EventViewModel({
    required this.id,
    required this.name,
    required this.showDate,
    required this.startDate,
    required this.endDate,
    required this.dateRange,
    required this.tags,
    required this.hasLocation,
    required this.locationDisplay,
    this.masterUrl,
    this.description = '',
    this.subEvents = const [],
    this.canDelete = false,
    this.showSubEvents = true,
    this.ageMin,
    this.ageMax,
    this.isFree,
    this.priceMin,
    this.priceMax,
    this.isOutdoor,
    this.isLike,
    this.isDislike,
    this.pageViews,
    this.cardClicks,
    this.saves,
    this.registrationClicks,
    this.likeCounts,
    this.dislikeCounts,
  });

  // ---------------------------------------------------------------------------
  // 🧩 UI 資料封裝
  // ---------------------------------------------------------------------------
  static EventViewModel buildEventViewModel({
    required EventBase event,
    required String parentLocation,
    required bool canDelete,
    bool showSubEvents = true,
    required AppLocalizations loc,
    required String tableName,
  }) {
    final locationDisplay = (event.city.isNotEmpty || event.location.isNotEmpty)
        ? '${event.city}．${event.location}'
        : '';

    String isFree = event.isFree == null
        ? ''
        : (event.isFree! ? loc.free : loc.pay);
    String isOutdoor = event.isOutdoor == null
        ? ''
        : (event.isOutdoor! ? loc.outdoor : loc.indoor);
    String ageRange = event.ageMin == null
        ? ''
        : "${event.ageMin}y~${event.ageMax == null ? '' : "${event.ageMax}y"}";
    String priceRange = event.priceMin == null
        ? ''
        : "\$${event.priceMin}~${event.priceMax == null ? '' : "\$${event.priceMax}"}";
    // 處理 tags
    final tagsRawData = <String>[
      isFree,
      isOutdoor,
      ageRange,
      priceRange,
      event.type
    ].where((t) => t.isNotEmpty).toList();

    final tags = tagsRawData
        .expand((t) => t.split(RegExp(r'[\s,，]')))
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .take(3)
        .toList();

    return EventViewModel(
      id: event.id,
      name: event.name,
      showDate: tableName != TableNames.recommendedAttractions,
      startDate: event.startDate,
      endDate: event.endDate,
      dateRange: tableName != TableNames.recommendedAttractions
          ? '${DateTimeFormatter.formatEventDateTime(event, CalendarMisc.startToS)}'
              '${DateTimeFormatter.formatEventDateTime(event, CalendarMisc.endToE)}'
          : '',
      tags: tags,
      hasLocation:
          locationDisplay.isNotEmpty && locationDisplay != parentLocation,
      locationDisplay: locationDisplay,
      masterUrl: event.masterUrl,
      description: event.description,
      subEvents: showSubEvents
          ? event.subEvents
              .map((sub) => buildEventViewModel(
                  event: sub,
                  parentLocation: locationDisplay,
                  canDelete: canDelete,
                  showSubEvents: showSubEvents,
                  loc: loc,
                  tableName: tableName))
              .toList()
          : const [],
      canDelete: canDelete,
      showSubEvents: showSubEvents,
      ageMin: event.ageMin,
      ageMax: event.ageMax,
      isFree: event.isFree,
      priceMin: event.priceMin,
      priceMax: event.priceMax,
      isOutdoor: event.isOutdoor,
      isLike: event.isLike,
      isDislike: event.isDislike,
      pageViews: event.pageViews,
      cardClicks: event.cardClicks,
      saves: event.saves,
      registrationClicks: event.registrationClicks,
      likeCounts: event.likeCounts,
      dislikeCounts: event.dislikeCounts,
    );
  }
}
