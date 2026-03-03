import 'dart:async';
import 'package:flutter/material.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/date_time.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/event/service_event.dart';
import 'package:life_pilot/utils/enum.dart';
import 'package:life_pilot/utils/service/service_speech.dart';
import 'package:uuid/uuid.dart';

class ControllerPageCalendarAdd extends ChangeNotifier {
  final Uuid uuid = const Uuid();

  final ControllerAuth auth;
  final ServiceEvent serviceEvent;
  late EventItem event;
  final DateTime? initialDate;

  // --- 語音辨識 ---
  bool isListening = false;
  String? currentListeningKey;

  // --- Debounce 用 ---
  Timer? _debounce;

  final String tableName;
  ControllerPageCalendarAdd({
    required this.auth,
    required this.serviceEvent,
    required this.tableName,
    EventItem? existingEvent,
    this.initialDate,
  }) {
    final now = DateTime.now();
    event = existingEvent ??
        EventItem(
          id: uuid.v4(),
          startDate: initialDate ?? now,
          endDate: initialDate ?? now,
          startTime: TimeOfDay.fromDateTime(now),
          endTime: TimeOfDay.fromDateTime(now),
          subEvents: [],
          account: auth.currentAccount,
          reminderOptions: const [CalendarReminderOption.dayBefore8am],
          repeatOptions: CalendarRepeatRule.once,
        );
  }
  final ServiceSpeech _serviceSpeech = ServiceSpeech();

  // ==========================
  // 🔹 資料操作方法
  // ==========================
  void updateField(String key, String value,
      {bool check = true, EventItem? sub}) {
    _updateField(sub ?? event, key, value, check);
    _notifyDebounced();
  }

  void _updateField(EventItem item, String key, String value, bool check) {
    switch (key) {
      case EventFields.city:
        item.city = value;
        break;
      case EventFields.location:
        item.location = value;
        break;
      case EventFields.name:
        item.name = value;
        break;
      case EventFields.type:
        item.type = value;
        break;
      case EventFields.description:
        item.description = value;
        break;
      /*case EventFields.fee:
        item.fee = value;
        break;*/
      case EventFields.unit:
        item.unit = value;
        break;
      case EventFields.masterUrl:
        item.masterUrl = value;
        break;
      case EventFields.ageMin:
        item.ageMin = value.isEmpty ? null : num.parse(value);
        if (check &&
            item.ageMin != null &&
            item.ageMax != null &&
            item.ageMin!.compareTo(item.ageMax!) > 0) {
          item.ageMax = item.ageMin;
        }
        break;
      case EventFields.ageMax:
        item.ageMax = value.isEmpty ? null : num.parse(value);
        if (check &&
            item.ageMin != null &&
            item.ageMax != null &&
            item.ageMin!.compareTo(item.ageMax!) > 0) {
          item.ageMin = item.ageMax;
        }
        break;
      case EventFields.isFree:
        item.isFree = value.isEmpty ? null : bool.parse(value);
        break;
      case EventFields.priceMin:
        item.priceMin = value.isEmpty ? null : num.parse(value);
        if (check &&
            item.priceMin != null &&
            item.priceMax != null &&
            item.priceMin!.compareTo(item.priceMax!) > 0) {
          item.priceMax = item.priceMin;
        }
        break;
      case EventFields.priceMax:
        item.priceMax = value.isEmpty ? null : num.parse(value);
        if (check &&
            item.priceMin != null &&
            item.priceMax != null &&
            item.priceMin!.compareTo(item.priceMax!) > 0) {
          item.priceMin = item.priceMax;
        }
        break;
      case EventFields.isOutdoor:
        item.isOutdoor = value.isEmpty ? null : bool.parse(value);
        break;
      case EventFields.isLike:
        item.isLike = value.isEmpty ? null : bool.parse(value);
        break;
      case EventFields.isDislike:
        item.isDislike = value.isEmpty ? null : bool.parse(value);
        break;
    }
  }

  // Debounce 更新（減少 rebuild 次數）
  void _notifyDebounced() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      notifyListeners();
    });
  }

  void addSubEvent() {
    final sub = EventItem(
      id: uuid.v4(),
      startDate: event.startDate,
      endDate: event.endDate,
      startTime: event.startTime,
      endTime: event.endTime,
      city: event.city,
      location: event.location,
    );
    event.subEvents.add(sub);
    notifyListeners();
  }

  void removeSubEvent(String id) {
    event.subEvents.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  void updateDate({
    required EventItem item,
    required DateTime date,
    required bool isStart,
  }) {
    if (isStart) {
      item.startDate = date;
    } else {
      item.endDate = date;
    }

    if (item.startDate != null &&
        item.endDate != null &&
        item.startDate!.isAfter(item.endDate!)) {
      if (isStart) {
        item.endDate = item.startDate;
      } else {
        item.startDate = item.endDate;
      }
    }

    notifyListeners();
  }

  void updateTime({
    required EventItem item,
    required TimeOfDay time,
    required bool isStart,
  }) {
    if (isStart) {
      item.startTime = time;
    } else {
      item.endTime = time;
    }

    if (item.startDate != null &&
        item.endDate != null &&
        item.startTime != null &&
        item.endTime != null &&
        item.startDate!.compareTo(item.endDate!) == 0 &&
        item.startTime!.isAfter(item.endTime!)) {
      if (isStart) {
        item.endTime = item.startTime;
      } else {
        item.startTime = item.endTime;
      }
    }

    notifyListeners();
  }

  // 將目前表單內容轉換為 EventItem
  EventItem toEventItem() {
    // ✅ 先更新 subEvents 的內容
    event.subEvents.sort(_compareEvents);
    return event;
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
        _notifyDebounced();
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

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
