import 'dart:async';
import 'package:flutter/material.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/date_time.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/utils/enum.dart';
import 'package:life_pilot/utils/service/service_speech.dart';
import 'package:uuid/uuid.dart';

class ControllerPageCalendarAdd extends ChangeNotifier {
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
  List<EventItem> subEvents = [];
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

  ControllerPageCalendarAdd({
    required this.auth,
    required this.tableName,
    this.existingEvent,
    this.initialDate,
  }) {
    _init();
  }

  // 初始化欄位與控制器
  void _init() {
    final now = DateTime.now();
    final e = existingEvent;
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
    subEvents = e != null ? List.from(e.subEvents) : [];
    account = e?.account ?? auth.currentAccount;
    reminderOptions =
        e?.reminderOptions ?? const [CalendarReminderOption.dayBefore8am];
    repeatOptions = e?.repeatOptions ?? CalendarRepeatRule.once;
    final fields = {
      EventFields.city: city,
      EventFields.location: location,
      EventFields.name: name,
      EventFields.type: type,
      EventFields.description: description,
      EventFields.masterUrl: masterUrl ?? '',
    };

    for (final entry in fields.entries) {
      initController(key: entry.key, initialValue: entry.value.toString());
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
        EventFields.masterUrl: sub.masterUrl ?? '',
      };

      for (final entry in subFields.entries) {
        initController(
          key: '${entry.key}_sub_${sub.id}',
          initialValue:
              entry.value.toString().isEmpty ? '' : entry.value.toString(),
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
      case EventFields.masterUrl:
        masterUrl = value;
        break;
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
      case EventFields.masterUrl:
        sub.masterUrl = value;
        break;
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
        newAccount: auth.currentAccount,
        newRepeatOptions: existingEvent?.repeatOptions ?? repeatOptions,
        newReminderOptions: existingEvent?.reminderOptions ?? reminderOptions,
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
      ..account = auth.currentAccount
      ..repeatOptions = existingEvent?.repeatOptions ?? repeatOptions
      ..reminderOptions = existingEvent?.reminderOptions ?? reminderOptions;
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
      ..location = location;

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
