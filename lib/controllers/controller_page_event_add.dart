import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/controller_auth.dart';
import 'package:life_pilot/models/model_event_item.dart';
import 'package:life_pilot/models/model_event_fields.dart';
import 'package:life_pilot/notification/core/reminder_option.dart';
import 'package:life_pilot/services/service_speech.dart';
import 'package:life_pilot/utils/core/utils_const.dart';
import 'package:life_pilot/utils/core/utils_enum.dart';
import 'package:life_pilot/utils/core/utils_locator.dart';
import 'package:uuid/uuid.dart';
import '../services/service_storage.dart';

class ControllerPageEventAdd extends ChangeNotifier {
  final auth = getIt<ControllerAuth>();
  final storage = getIt<ServiceStorage>();
  final ServiceSpeech _serviceSpeech = ServiceSpeech();
  
  final String tableName;
  final Uuid uuid = const Uuid();

  EventItem? existingEvent;

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
  List<EventItem> subEvents = [];

  String? masterGraphUrl;
  String? masterUrl;
  String? account = constEmpty;
  RepeatRule repeatOptions = RepeatRule.once;
  List<ReminderOption> reminderOptions = const [ReminderOption.dayBefore8am];
  DateTime? reminderTime;

  // 語音辨識 & 朗讀
  bool isListening = false;
  String? currentListeningKey;

  final Map<String, TextEditingController> controllerMap = {};

  ControllerPageEventAdd({
    required this.tableName,
    this.existingEvent,
  }) {
    _init();
  }

  void _init() {
    if (existingEvent != null) {
      final e = existingEvent!;
      masterGraphUrl = e.masterGraphUrl;
      masterUrl = e.masterUrl;
      startDate = e.startDate;
      endDate = e.endDate;
      startTime = e.startTime;
      endTime = e.endTime;
      city = e.city;
      location = e.location;
      name = e.name;
      type = e.type;
      description = e.description;
      fee = e.fee;
      unit = e.unit;
      subEvents = List.from(e.subEvents);
      account = e.account;
      reminderOptions = e.reminderOptions;
      repeatOptions = e.repeatOptions;
    } else {
      startDate = DateTime.now();
      startTime = TimeOfDay.fromDateTime(DateTime.now());
      endDate = startDate;
    }

    initController(key: EventFields.city, initialValue: city);
    initController(key: EventFields.location, initialValue: location);
    initController(key: EventFields.name, initialValue: name);
    initController(key: EventFields.type, initialValue: type);
    initController(key: EventFields.description, initialValue: description);
    initController(key: EventFields.fee, initialValue: fee);
    initController(key: EventFields.unit, initialValue: unit);
    initController(
        key: EventFields.masterUrl, initialValue: masterUrl ?? constEmpty);
  }

  void initController({required String key, required String initialValue}) {
    if (!controllerMap.containsKey(key)) {
      controllerMap[key] = TextEditingController(text: initialValue);
    }
  }

  TextEditingController getController({required String key}) {
    return controllerMap[key]!;
  }

  Future<void> startListening(
      {required ValueChanged<String> onResult, required String key}) async {
    final available = await _serviceSpeech.startListening(
      onResult: (text) {
        onResult(text);
        notifyListeners(); // for UI update
      },
      key: key
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
    for (var c in controllerMap.values) {
      c.dispose();
    }
    super.dispose();
  }
}
