import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:life_pilot/controllers/controller_auth.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/models/model_event.dart';
import 'package:life_pilot/notification/notification_common.dart';
import 'package:life_pilot/services/service_storage.dart';
import 'package:life_pilot/utils/utils_common_function.dart';
import 'package:life_pilot/utils/utils_const.dart';
import 'package:life_pilot/utils/utils_enum.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:uuid/uuid.dart';

final uuid = const Uuid();

class PageRecommendedEventAdd extends StatefulWidget {
  final String tableName;
  final Event? existingRecommendedEvent;
  final DateTime? initialDate;

  const PageRecommendedEventAdd({
    super.key,
    required this.tableName,
    this.existingRecommendedEvent,
    this.initialDate,
  });

  @override
  State<PageRecommendedEventAdd> createState() =>
      _PageRecommendedEventAddState();
}

class _PageRecommendedEventAddState extends State<PageRecommendedEventAdd> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  AppLocalizations get loc => AppLocalizations.of(context)!;

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
  List<SubEventItem> subEvents = [];

  String? masterGraphUrl;
  String? masterUrl;
  String? account = constEmpty;
  RepeatRule repeatOptions = RepeatRule.once;
  List<ReminderOption> reminderOptions = const [ReminderOption.dayBefore8am];
  DateTime? reminderTime;

  String? _currentListeningKey;
  final Map<String, TextEditingController> _controllers = {};
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _lastWords = constEmpty;
  late FlutterTts _flutterTts;

  void _initController(String key, [String initialValue = constEmpty]) {
    if (!_controllers.containsKey(key)) {
      _controllers[key] = TextEditingController(text: initialValue);
    }
  }

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _flutterTts = FlutterTts();
    final e = widget.existingRecommendedEvent;
    if (e != null) {
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
      startDate = widget.initialDate ?? DateTime.now();
      startTime = TimeOfDay.fromDateTime(DateTime.now());
      endDate = startDate;
    }

    _initController(EventFields.city, e?.city ?? constEmpty);
    _initController(EventFields.location, e?.location ?? constEmpty);
    _initController(EventFields.name, e?.name ?? constEmpty);
    _initController(EventFields.type, e?.type ?? constEmpty);
    _initController(EventFields.description, e?.description ?? constEmpty);
    _initController(EventFields.fee, e?.fee ?? constEmpty);
    _initController(EventFields.unit, e?.unit ?? constEmpty);
    _initController(EventFields.masterUrl, e?.masterUrl ?? constEmpty);
  }

  Future<void> _startListening(
      ValueChanged<String> onResult, String key) async {
    bool available = await _speech.initialize();
    if (!available) return;
    setState(() {
      _isListening = true;
      _currentListeningKey = key;
    });
    _speech.listen(
      onResult: (result) {
        setState(() {
          _lastWords = result.recognizedWords;
          onResult(_lastWords); // ⬅️ 呼叫 callback 寫入欄位
        });
      },
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.dictation, // 可選，加強聽寫效果
      ),
    );
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    setState(() {
      _isListening = false;
      _currentListeningKey = null;
    });
  }

  Future<void> _pickDate({required bool isStart, int? index}) async {
    final initial = isStart
        ? (index == null ? startDate : subEvents[index].startDate) ??
            DateTime.now()
        : (index == null ? endDate : subEvents[index].endDate) ??
            DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1800)),
      lastDate: DateTime.now().add(const Duration(days: 1800)),
    );

    if (picked != null) {
      setState(() {
        if (index == null) {
          isStart ? startDate = picked : endDate = picked;
          if (startDate != null && endDate != null && startDate!.isAfter(endDate!)) {
            endDate = startDate;
          }
        } else {
          isStart
              ? subEvents[index].startDate = picked
              : subEvents[index].endDate = picked;

          if (subEvents[index].startDate != null && subEvents[index].endDate != null && subEvents[index].startDate!.isAfter(subEvents[index].endDate!)) {
            subEvents[index].endDate = subEvents[index].startDate;
          }
        }
      });
    }
  }

  Future<void> _pickTime({required bool isStart, int? index}) async {
    final initial = isStart
        ? (index == null ? startTime : subEvents[index].startTime) ??
            TimeOfDay.now()
        : (index == null ? endTime : subEvents[index].endTime) ??
            TimeOfDay.now();

    final picked = await showTimePicker(context: context, initialTime: initial);

    if (picked != null) {
      setState(() {
        if (index == null) {
          isStart ? startTime = picked : endTime = picked;
        } else {
          isStart
              ? subEvents[index].startTime = picked
              : subEvents[index].endTime = picked;
        }
      });
    }
  }

  Widget _buildDateTimeRow({int? index}) {
    final dStart = index == null ? startDate : subEvents[index].startDate;
    final dEnd = index == null ? endDate : subEvents[index].endDate;
    final tStart = index == null ? startTime : subEvents[index].startTime;
    final tEnd = index == null ? endTime : subEvents[index].endTime;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
                child: _buildDateTile(
                    dStart,
                    () => _pickDate(isStart: true, index: index),
                    constStartToS)),
            const Text(' ~ '),
            Expanded(
                child: _buildDateTile(
                    dEnd,
                    () => _pickDate(isStart: false, index: index),
                    constEndToE)),
          ],
        ),
        Row(
          children: [
            Expanded(
                child: _buildTimeTile(
                    tStart,
                    () => _pickTime(isStart: true, index: index),
                    constStartToS)),
            const Text(' ~ '),
            Expanded(
                child: _buildTimeTile(
                    tEnd,
                    () => _pickTime(isStart: false, index: index),
                    constEndToE)),
          ],
        ),
      ],
    );
  }

  Widget _buildDateTile(DateTime? date, VoidCallback onTap, String type) {
    final text = date != null
        ? '${date.year}/${date.month.toString().padLeft(2, constZero)}/${date.day.toString().padLeft(2, constZero)}'
        : (type == constStartToS ? loc.start_date : loc.end_date);
    return ListTile(
      contentPadding: kGapEI0,
      visualDensity: VisualDensity(horizontal: -4, vertical: -2),
      subtitle: Text(text, textAlign: TextAlign.center),
      trailing: const Icon(Icons.calendar_today),
      onTap: onTap,
    );
  }

  Widget _buildTimeTile(TimeOfDay? time, VoidCallback onTap, String type) {
    final text = time?.format(context) ??
        (type == constStartToS ? loc.start_time : loc.end_time);
    return ListTile(
      contentPadding: kGapEI0,
      visualDensity: VisualDensity(horizontal: -4, vertical: -2),
      subtitle: Text(text, textAlign: TextAlign.center),
      trailing: const Icon(Icons.access_time),
      onTap: onTap,
    );
  }

  Widget _buildTextField({
    required String key,
    required String label,
    required ValueChanged<String> onChanged,
    int maxLines = 1,
  }) {
    _initController(key, constEmpty); // 確保 controller 有初始化
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 新增朗讀按鈕
        if ((_controllers[key]?.text.isNotEmpty ?? false))
          IconButton(
            icon: const Icon(Icons.volume_up),
            tooltip: loc.speak_up,
            onPressed: () async {
              final textToSpeak = _controllers[key]?.text ?? constEmpty;
              if (textToSpeak.isNotEmpty) {
                await _flutterTts.stop();
                await _flutterTts.speak(textToSpeak);
              }
            },
          ),
        Expanded(
          child: TextFormField(
            controller: _controllers[key],
            decoration: InputDecoration(
              labelText: label,
              isDense: true,
              contentPadding: kGapEI3,
            ), // 讓欄位更緊湊
            maxLines: maxLines,
            onChanged: onChanged,
          ),
        ),
        IconButton(
          icon: Icon(
            Icons.mic,
            color:
                _isListening && _currentListeningKey == key ? Colors.red : null,
          ),
          tooltip: loc.speak, // 或 "語音輸入"
          onPressed: () async {
            if (_isListening && _currentListeningKey == key) {
              await _stopListening();
            } else {
              // 如果正在聽其他欄位 → 先停掉
              if (_isListening) {
                await _stopListening();
                await Future.delayed(
                    const Duration(milliseconds: 200)); // 小延遲保險
              }
              await _startListening((text) {
                setState(() {
                  _controllers[key]?.text = text;
                  onChanged(text);
                });
              }, key);
            }
          },
        ),
      ],
    );
  }

  Widget _buildSubEventCard(int index) {
    final d = subEvents[index];

    // 確保 subEvent 也有 id，沒的話補一個
    if (d.id.isEmpty) {
      subEvents[index] = d.copyWith(newId: uuid.v4());
    }

    return Card(
      key: ValueKey(d.id),
      color: index % 2 == 0 ? Colors.blueGrey[50] : Colors.grey[300],
      child: Padding(
        padding: kGapEI4,
        child: Column(
          children: [
            _buildDateTimeRow(index: index),
            _buildTextField(
                key: '${EventFields.location}_sub_$index',
                label: loc.location,
                onChanged: (v) => setState(() => d.location = v)),
            _buildTextField(
                key: '${EventFields.name}_sub_$index',
                label: loc.activity_name,
                onChanged: (v) => setState(() => d.name = v)),
            _buildTextField(
                key: '${EventFields.type}_sub_$index',
                label: loc.keywords,
                onChanged: (v) => setState(() => d.type = v)),
            _buildTextField(
                key: '${EventFields.masterUrl}_sub_$index',
                label: loc.sub_url,
                onChanged: (v) => setState(() => d.masterUrl = v)),
            _buildTextField(
                key: '${EventFields.description}_sub_$index',
                label: loc.description,
                onChanged: (v) => setState(() => d.description = v),
                maxLines: 2),
            _buildTextField(
                key: '${EventFields.fee}_sub_$index',
                label: loc.fee,
                onChanged: (v) => setState(() => d.fee = v)),
            _buildTextField(
                key: '${EventFields.unit}_sub_$index',
                label: loc.sponsor,
                onChanged: (v) => setState(() => d.unit = v)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '#${index + 1} ${DateFormat('MM/dd').format(d.startDate!)} ${d.startTime!.format(context)} ${d.name.substring(0, d.name.length > 5 ? 5 : d.name.length)}${d.name.length > 5 ? '...' : constEmpty}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.pinkAccent),
                  tooltip: loc.delete,
                  onPressed: () => setState(() => subEvents.removeAt(index)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final auth = Provider.of<ControllerAuth>(context,listen:false);
    final event = Event(
      id: widget.existingRecommendedEvent != null
          ? widget.existingRecommendedEvent!.id
          : uuid.v4(),
      masterGraphUrl: masterGraphUrl,
      masterUrl: masterUrl,
      startDate: startDate,
      endDate: endDate,
      startTime: startTime,
      endTime: endTime,
      city: city,
      location: location,
      name: name,
      type: type,
      description: description,
      fee: fee,
      unit: unit,
      subEvents: subEvents
          .map((d) => d.id.isEmpty ? d.copyWith(newId: uuid.v4()) : d)
          .toList(),
      account: auth.currentAccount,
      reminderOptions: widget.existingRecommendedEvent == null
          ? reminderOptions
          : widget.existingRecommendedEvent!.reminderOptions,
      repeatOptions: widget.existingRecommendedEvent == null
          ? repeatOptions
          : widget.existingRecommendedEvent!.repeatOptions,
    );
    await ServiceStorage().saveRecommendedEvent(context, event,
        widget.existingRecommendedEvent == null, widget.tableName);
    showSnackBar(context, loc.event_saved);

    Navigator.pop(context, event);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    for (var c in _controllers.values) {
      c.dispose();
    }
    _flutterTts.stop(); // 停止朗讀
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.event_add_edit),
        actions: [
          TextButton(
            onPressed: _submit,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
            ),
            child: Text(loc.save),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            controller: _scrollController,
            padding: kGapEIL4R4T4B8,
            children: [
              _buildDateTimeRow(),
              _buildTextField(
                  key: EventFields.city,
                  label: loc.city,
                  onChanged: (v) => setState(() => city = v)),
              _buildTextField(
                  key: EventFields.location,
                  label: loc.location,
                  onChanged: (v) => setState(() => location = v)),
              _buildTextField(
                  key: EventFields.name,
                  label: loc.activity_name,
                  onChanged: (v) => setState(() => name = v)),
              _buildTextField(
                  key: EventFields.type,
                  label: loc.keywords,
                  onChanged: (v) => setState(() => type = v)),
              _buildTextField(
                  key: EventFields.masterUrl,
                  label: loc.master_url,
                  onChanged: (v) => setState(() => masterUrl = v)),
              _buildTextField(
                  key: EventFields.description,
                  label: loc.description,
                  onChanged: (v) => setState(() => description = v),
                  maxLines: 2),
              _buildTextField(
                  key: EventFields.fee,
                  label: loc.fee,
                  onChanged: (v) => setState(() => fee = v)),
              _buildTextField(
                  key: EventFields.unit,
                  label: loc.sponsor,
                  onChanged: (v) => setState(() => unit = v)),
              kGapH16(),
              Text(loc.event_sub),
              ...List.generate(subEvents.length, _buildSubEventCard),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() => subEvents.add(SubEventItem(
                      id: uuid.v4(),
                      startDate: startDate,
                      endDate: endDate,
                      startTime: startTime,
                      endTime: endTime,
                      city: city,
                      location: location)));
                  Future.delayed(const Duration(milliseconds: 300), () {
                    if (_scrollController.hasClients) {
                      _scrollController.animateTo(
                        _scrollController.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    }
                  });
                },
                icon: const Icon(Icons.add),
                label: Text(loc.event_add_sub),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
