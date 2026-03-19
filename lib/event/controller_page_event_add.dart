import 'dart:async';
import 'package:flutter/material.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/event/service_event_public.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/date_time.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/utils/enum.dart';
import 'package:life_pilot/utils/service/service_speech.dart';
import 'package:uuid/uuid.dart';

class ControllerPageEventAdd extends ChangeNotifier {
  final ControllerAuth auth;
  final ServiceSpeech _serviceSpeech = ServiceSpeech();

  final String tableName;
  final Uuid uuid = const Uuid();

  EventItem? existingEvent;
  final DateTime? initialDate;
  DateTime? startDate;
  DateTime? endDate;
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  String city = '';
  String location = '';
  String name = '';
  String type = '';
  String description = '';
  String unit = '';
  List<EventItem> subEvents = [];

  num? ageMin;
  num? ageMax;
  bool? isFree;
  num? priceMin;
  num? priceMax;
  bool? isOutdoor;
  bool? isLike;
  bool? isDislike;
  int? pageViews;
  int? cardClicks;
  int? saves;
  int? registrationClicks;
  int? likeCounts;
  int? dislikeCounts;
  String? source;

  String? masterGraphUrl;
  String? masterUrl;
  String? account = '';
  CalendarRepeatRule repeatOptions = CalendarRepeatRule.once;
  List<CalendarReminderOption> reminderOptions = const [
    CalendarReminderOption.dayBefore8am
  ];
  DateTime? reminderTime;

  // --- 語音辨識 ---
  bool isListening = false;
  String? currentListeningKey;

  // --- 控制器管理 ---
  final Map<String, TextEditingController> controllerMap = {};

  ControllerPageEventAdd({
    required this.auth,
    required this.tableName,
    this.existingEvent,
    this.initialDate,
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
    this.source,
  }) {
    _init();
  }

  // 初始化欄位與控制器
  void _init() {
    final now = DateTime.now();

    final e = existingEvent;
    masterGraphUrl = e?.masterGraphUrl;
    masterUrl = e?.masterUrl;
    startDate = e?.startDate ?? initialDate ?? now;
    endDate = e?.endDate ?? startDate;
    startTime = e?.startTime ?? TimeOfDay.fromDateTime(now);
    endTime = e?.endTime;
    city = e?.city ?? '';
    location = e?.location ?? '';
    name = e?.name ?? '';
    type = e?.type ?? '';
    description = e?.description ?? '';
    unit = e?.unit ?? '';
    subEvents = e != null ? List.from(e.subEvents) : [];
    account = e?.account ?? auth.currentAccount;
    reminderOptions =
        e?.reminderOptions ?? const [CalendarReminderOption.dayBefore8am];
    repeatOptions = e?.repeatOptions ?? CalendarRepeatRule.once;
    ageMin = e?.ageMin;
    ageMax = e?.ageMax;
    isFree = e?.isFree;
    priceMin = e?.priceMin;
    priceMax = e?.priceMax;
    isOutdoor = e?.isOutdoor;
    isLike = e?.isLike;
    isDislike = e?.isDislike;
    pageViews = e?.pageViews;
    cardClicks = e?.cardClicks;
    saves = e?.saves;
    registrationClicks = e?.registrationClicks;
    likeCounts = e?.likeCounts;
    dislikeCounts = e?.dislikeCounts;
    source = e?.source;
    final fields = {
      EventFields.city: city,
      EventFields.location: location,
      EventFields.name: name,
      EventFields.type: type,
      EventFields.description: description,
      EventFields.unit: unit,
      EventFields.masterUrl: masterUrl ?? '',
      EventFields.ageMin: ageMin,
      EventFields.ageMax: ageMax,
      EventFields.isFree: isFree,
      EventFields.priceMin: priceMin,
      EventFields.priceMax: priceMax,
      EventFields.isOutdoor: isOutdoor,
      EventFields.isLike: isLike,
      EventFields.isDislike: isDislike,
      EventFields.pageViews: pageViews,
      EventFields.cardClicks: cardClicks,
      EventFields.saves: saves,
      EventFields.registrationClicks: registrationClicks,
      EventFields.likeCounts: likeCounts,
      EventFields.dislikeCounts: dislikeCounts,
      EventFields.source: source,
    };
    for (final entry in fields.entries) {
      initController(
          key: entry.key, initialValue: entry.value?.toString() ?? '');
    }

    // ✅ 初始化子事件控制器
    for (int i = 0; i < subEvents.length; i++) {
      final sub = subEvents[i];
      final subFields = {
        EventFields.city: sub.city,
        EventFields.location: sub.location,
        EventFields.name: sub.name,
        EventFields.type: sub.type,
        EventFields.description: sub.description,
        EventFields.unit: sub.unit,
        EventFields.masterUrl: sub.masterUrl ?? '',
        EventFields.ageMin: sub.ageMin,
        EventFields.ageMax: sub.ageMax,
        EventFields.isFree: sub.isFree,
        EventFields.priceMin: sub.priceMin,
        EventFields.priceMax: sub.priceMax,
        EventFields.isOutdoor: sub.isOutdoor,
        EventFields.isLike: sub.isLike,
        EventFields.isDislike: sub.isDislike,
        EventFields.pageViews: sub.pageViews,
        EventFields.cardClicks: sub.cardClicks,
        EventFields.saves: sub.saves,
        EventFields.registrationClicks: sub.registrationClicks,
        EventFields.likeCounts: sub.likeCounts,
        EventFields.dislikeCounts: sub.dislikeCounts,
        EventFields.source: sub.source,
      };

      for (final entry in subFields.entries) {
        initController(
          key: '${entry.key}_sub_${sub.id}',
          initialValue:
              entry.value?.toString() == null || entry.value!.toString().isEmpty
                  ? ''
                  : entry.value!.toString(),
        );
      }
    }
  }

  // 建立或取得控制器
  TextEditingController initController(
      {required String key, required String initialValue}) {
    return controllerMap.putIfAbsent(
        key, () => TextEditingController(text: initialValue));
  }

  TextEditingController getController({required String key}) {
    return controllerMap[key] ?? initController(key: key, initialValue: '');
  }

  void parseFacebookText(String text) {
    final parsed = ServiceEventPublic.parseFacebookText(text);
    updateField(EventFields.name, parsed.name, true);
    updateField(EventFields.location, parsed.location, true);
    updateField(EventFields.city, parsed.city, true);
    updateField(EventFields.masterUrl, parsed.masterUrl ?? "", true);
    updateField(EventFields.unit, parsed.unit, true);
    updateField(EventFields.description, parsed.description, true);
    updateField(EventFields.type, parsed.type, true);

    if (parsed.startDate != null) {
      setDate(parsed.startDate!, isStart: true);
    }
    if (parsed.endDate != null) {
      setDate(parsed.endDate!, isStart: false);
    }

    if (parsed.startTime != null) {
      setTime(parsed.startTime!, isStart: true);
    }
    if (parsed.endTime != null) {
      setTime(parsed.endTime!, isStart: false);
    }
    notifyListeners();
  }

  // 更新欄位（主事件 / 子事件）
  void updateField(String key, String value, bool check) {
    // ✅ 判斷是否是 subEvent 欄位
    if (key.contains('_sub_')) {
      final parts = key.split('_sub_');
      if (parts.length == 2) {
        final field = parts[0];
        final nowId = parts[1];
        final sub = subEvents.firstWhere((e) => e.id == nowId,
            orElse: () => EventItem(id: nowId));
        _updateSubEvent(key, sub, field, value, check);
        return;
      }
    }
    _updateMainField(key, value, check);
  }

  void _updateMainField(String key, String value, bool check) {
    switch (key) {
      case EventFields.city:
        city = value;
        break;
      case EventFields.location:
        location = value;
        break;
      case EventFields.name:
        name = value;
        break;
      case EventFields.type:
        type = value;
        break;
      case EventFields.description:
        description = value;
        break;
      case EventFields.unit:
        unit = value;
        break;
      case EventFields.masterUrl:
        masterUrl = value;
        break;
      case EventFields.ageMin:
        ageMin = value.isEmpty ? null : num.parse(value);
        if (check &&
            ageMin != null &&
            ageMax != null &&
            ageMin!.compareTo(ageMax!) > 0) {
          ageMax = ageMin;
          controllerMap[EventFields.ageMax]?.text = ageMax.toString();
        }
        break;
      case EventFields.ageMax:
        ageMax = value.isEmpty ? null : num.parse(value);
        if (check &&
            ageMin != null &&
            ageMax != null &&
            ageMin!.compareTo(ageMax!) > 0) {
          ageMin = ageMax;
          controllerMap[EventFields.ageMin]?.text = ageMin.toString();
        }
        break;
      case EventFields.isFree:
        isFree = value.isEmpty ? null : bool.parse(value);
        break;
      case EventFields.priceMin:
        priceMin = value.isEmpty ? null : num.parse(value);
        if (check &&
            priceMin != null &&
            priceMax != null &&
            priceMin!.compareTo(priceMax!) > 0) {
          priceMax = priceMin;
          controllerMap[EventFields.priceMax]?.text = priceMax.toString();
        }
        break;
      case EventFields.priceMax:
        priceMax = value.isEmpty ? null : num.parse(value);
        if (check &&
            priceMin != null &&
            priceMax != null &&
            priceMin!.compareTo(priceMax!) > 0) {
          priceMin = priceMax;
          controllerMap[EventFields.priceMin]?.text = priceMin.toString();
        }
        break;
      case EventFields.isOutdoor:
        isOutdoor = value.isEmpty ? null : bool.parse(value);
        break;
      case EventFields.isLike:
        isLike = value.isEmpty ? null : bool.parse(value);
        break;
      case EventFields.isDislike:
        isDislike = value.isEmpty ? null : bool.parse(value);
        break;
    }
    if (controllerMap[key]?.text != value) {
      controllerMap[key]?.text = value;
    }
  }

  void _updateSubEvent(
      String mapKey, EventItem sub, String key, String value, bool check) {
    switch (key) {
      case EventFields.city:
        sub.city = value;
        break;
      case EventFields.location:
        sub.location = value;
        break;
      case EventFields.name:
        sub.name = value;
        break;
      case EventFields.type:
        sub.type = value;
        break;
      case EventFields.description:
        sub.description = value;
        break;
      case EventFields.unit:
        sub.unit = value;
        break;
      case EventFields.masterUrl:
        sub.masterUrl = value;
        break;
      case EventFields.ageMin:
        sub.ageMin = value.isEmpty ? null : num.parse(value);
        if (check &&
            sub.ageMin != null &&
            sub.ageMax != null &&
            sub.ageMin!.compareTo(sub.ageMax!) > 0) {
          sub.ageMax = sub.ageMin;
          controllerMap[
                  mapKey.replaceAll(EventFields.ageMin, EventFields.ageMax)]
              ?.text = sub.ageMax.toString();
        }
        break;
      case EventFields.ageMax:
        sub.ageMax = value.isEmpty ? null : num.parse(value);
        if (check &&
            sub.ageMin != null &&
            sub.ageMax != null &&
            sub.ageMin!.compareTo(sub.ageMax!) > 0) {
          sub.ageMin = sub.ageMax;
          controllerMap[
                  mapKey.replaceAll(EventFields.ageMax, EventFields.ageMin)]
              ?.text = sub.ageMin.toString();
        }
        break;
      case EventFields.isFree:
        sub.isFree = value.isEmpty ? null : bool.parse(value);
        break;
      case EventFields.priceMin:
        sub.priceMin = value.isEmpty ? null : num.parse(value);
        if (check &&
            sub.priceMin != null &&
            sub.priceMax != null &&
            sub.priceMin!.compareTo(sub.priceMax!) > 0) {
          sub.priceMax = sub.priceMin;
          controllerMap[
                  mapKey.replaceAll(EventFields.priceMin, EventFields.priceMax)]
              ?.text = sub.priceMax.toString();
        }
        break;
      case EventFields.priceMax:
        sub.priceMax = value.isEmpty ? null : num.parse(value);
        if (check &&
            sub.priceMin != null &&
            sub.priceMax != null &&
            sub.priceMin!.compareTo(sub.priceMax!) > 0) {
          sub.priceMin = sub.priceMax;
          controllerMap[
                  mapKey.replaceAll(EventFields.priceMax, EventFields.priceMin)]
              ?.text = sub.priceMin.toString();
        }
        break;
      case EventFields.isOutdoor:
        sub.isOutdoor = value.isEmpty ? null : bool.parse(value);
        break;
      case EventFields.isLike:
        sub.isLike = value.isEmpty ? null : bool.parse(value);
        break;
      case EventFields.isDislike:
        sub.isDislike = value.isEmpty ? null : bool.parse(value);
        break;
    }
    if (controllerMap[mapKey]?.text != value) {
      controllerMap[mapKey]?.text = value;
    }
  }

  // 將目前表單內容轉換為 EventItem
  EventItem toEventItem() {
    // ✅ 先更新 subEvents 的內容
    final sortedSubs = List<EventItem>.from(subEvents)..sort(_compareEvents);
    //subEvents.sort(_compareEvents);

    final updatedSubs = sortedSubs.map((sub) {
      String getText(String field) {
        String? tmpValue = controllerMap['${field}_sub_${sub.id}']?.text;
        return tmpValue == null || tmpValue.isEmpty ? '' : tmpValue;
      }

      return sub.copyWith(
        newSubEvents: [],
        newMasterUrl: getText(EventFields.masterUrl),
        newCity: getText(EventFields.city),
        newLocation: getText(EventFields.location),
        newName: getText(EventFields.name),
        newType: getText(EventFields.type),
        newDescription: getText(EventFields.description),
        newUnit: getText(EventFields.unit),
        newAgeMin: getText(EventFields.ageMin).isEmpty
            ? null
            : num.parse(getText(EventFields.ageMin)),
        newAgeMax: getText(EventFields.ageMax).isEmpty
            ? null
            : num.parse(getText(EventFields.ageMax)),
        newIsFree: getText(EventFields.isFree).isEmpty
            ? null
            : bool.parse(getText(EventFields.isFree)),
        newPriceMin: getText(EventFields.priceMin).isEmpty
            ? null
            : num.parse(getText(EventFields.priceMin)),
        newPriceMax: getText(EventFields.priceMax).isEmpty
            ? null
            : num.parse(getText(EventFields.priceMax)),
        newIsOutdoor: getText(EventFields.isOutdoor).isEmpty
            ? null
            : bool.parse(getText(EventFields.isOutdoor)),
        newIsLike: getText(EventFields.isLike).isEmpty
            ? null
            : bool.parse(getText(EventFields.isLike)),
        newIsDislike: getText(EventFields.isDislike).isEmpty
            ? null
            : bool.parse(getText(EventFields.isDislike)),
        newPageViews: existingEvent?.pageViews ?? pageViews,
        newCardClicks: existingEvent?.cardClicks ?? cardClicks,
        newSaves: existingEvent?.saves ?? saves,
        newRegistrationClicks:
            existingEvent?.registrationClicks ?? registrationClicks,
        newLikeCounts: existingEvent?.likeCounts ?? likeCounts,
        newDislikeCounts: existingEvent?.dislikeCounts ?? dislikeCounts,
        newAccount: auth.currentAccount,
        newRepeatOptions: existingEvent?.repeatOptions ?? repeatOptions,
        newReminderOptions: existingEvent?.reminderOptions ?? reminderOptions,
        newMasterGraphUrl: sub.masterGraphUrl,
        newSource: existingEvent?.source ?? source,
      );
    }).toList();

    // ✅ 再組主事件
    return EventItem(
      id: existingEvent?.id ?? uuid.v4(),
      subEvents: updatedSubs,
    )
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
      ..unit = unit
      ..account = auth.currentAccount
      ..repeatOptions = existingEvent?.repeatOptions ?? repeatOptions
      ..reminderOptions = existingEvent?.reminderOptions ?? reminderOptions
      ..masterGraphUrl = masterGraphUrl
      ..ageMin = ageMin
      ..ageMax = ageMax
      ..isFree = isFree
      ..priceMin = priceMin
      ..priceMax = priceMax
      ..isOutdoor = isOutdoor
      ..isLike = isLike
      ..isDislike = isDislike
      ..pageViews = existingEvent?.pageViews ?? pageViews
      ..cardClicks = existingEvent?.cardClicks ?? cardClicks
      ..saves = existingEvent?.saves ?? saves
      ..registrationClicks =
          existingEvent?.registrationClicks ?? registrationClicks
      ..likeCounts = existingEvent?.likeCounts ?? likeCounts
      ..dislikeCounts = existingEvent?.dislikeCounts ?? dislikeCounts
      ..source = existingEvent?.source ?? source;
  }

  int _compareEvents(EventItem a, EventItem b) {
    int compareDate(DateTime? x, DateTime? y) =>
        (x ?? DateTime(2100)).compareTo(y ?? DateTime(2100));

    int compare = compareDate(a.startDate, b.startDate);
    if (compare != 0) return compare;

    compare = DateTimeCompare.compareTimeOfDay(a.startTime, b.startTime);
    if (compare != 0) return compare;

    compare = compareDate(a.endDate, b.endDate);
    if (compare != 0) return compare;

    return DateTimeCompare.compareTimeOfDay(a.endTime, b.endTime);
  }

  // --- 語音控制區 ---
  Future<void> startListening(
      {required ValueChanged<String> onResult, required String key}) async {
    final available = await _serviceSpeech.startListening(
      onResult: (text) {
        onResult(text);
        notifyListeners();
      },
    );
    if (!available) return;
    isListening = true;
    currentListeningKey = key;
    notifyListeners();
  }

  Future<void> stopListening() async {
    await _serviceSpeech.stopListening();
    isListening = false;
    currentListeningKey = null;
    notifyListeners();
  }

  Future<void> speakText({required String text}) async {
    await _serviceSpeech.speakText(text: text);
  }

  void addSubEvent() {
    final newSub = EventItem(id: uuid.v4())
      ..startDate = startDate
      ..endDate = endDate
      ..startTime = startTime
      ..endTime = endTime
      ..city = city
      ..location = location
      ..ageMin = ageMin
      ..ageMax = ageMax
      ..isFree = isFree
      ..priceMin = priceMin
      ..priceMax = priceMax
      ..isOutdoor = isOutdoor
      ..isLike = isLike
      ..isDislike = isDislike
      ..pageViews = pageViews
      ..cardClicks = cardClicks
      ..saves = saves
      ..registrationClicks = registrationClicks
      ..likeCounts = likeCounts
      ..dislikeCounts = dislikeCounts
      ..source = source;

    subEvents.add(newSub);

    _initSubControllers(newSub);

    notifyListeners();
  }

  void _initSubControllers(EventItem newSub) {
    // ✅ 初始化該子事件的控制器
    final subFields = {
      EventFields.city: newSub.city,
      EventFields.location: newSub.location,
      EventFields.name: newSub.name,
      EventFields.type: newSub.type,
      EventFields.description: newSub.description,
      EventFields.unit: newSub.unit,
      EventFields.masterUrl: newSub.masterUrl ?? '',
    };
    subFields.forEach((key, value) {
      initController(key: '${key}_sub_${newSub.id}', initialValue: value);
    });
  }

  Future<void> removeSubEvent(int index) async {
    final removed = subEvents.removeAt(index);

    // 🔥 清掉該 sub 的 controller
    controllerMap.removeWhere((key, controller) {
      final shouldRemove = key.contains('_sub_${removed.id}');
      if (shouldRemove) controller.dispose();
      return shouldRemove;
    });
    notifyListeners();
  }

  void setDate(DateTime picked, {required bool isStart, int? index}) {
    if (index == null) {
      isStart ? startDate = picked : endDate = picked;
      if (startDate != null &&
          endDate != null &&
          startDate!.isAfter(endDate!)) {
        endDate = startDate;
      }
    } else {
      isStart
          ? subEvents[index].startDate = picked
          : subEvents[index].endDate = picked;

      if (subEvents[index].startDate != null &&
          subEvents[index].endDate != null &&
          subEvents[index].startDate!.isAfter(subEvents[index].endDate!)) {
        subEvents[index].endDate = subEvents[index].startDate;
      }
    }
    notifyListeners();
  }

  void setTime(TimeOfDay picked, {required bool isStart, int? index}) {
    if (index == null) {
      isStart ? startTime = picked : endTime = picked;
      if (startDate == endDate &&
          startTime != null &&
          endTime != null &&
          startTime!.isAfter(endTime!)) {
        endTime = startTime;
      }
    } else {
      isStart
          ? subEvents[index].startTime = picked
          : subEvents[index].endTime = picked;

      if (subEvents[index].startDate == subEvents[index].endDate &&
          subEvents[index].startTime != null &&
          subEvents[index].endTime != null &&
          subEvents[index].startTime!.isAfter(subEvents[index].endTime!)) {
        subEvents[index].endTime = subEvents[index].startTime;
      }
    }
    notifyListeners();
  }

  @override
  void dispose() {
    for (var c in controllerMap.values) {
      c.dispose();
    }
    super.dispose();
  }
}
