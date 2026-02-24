import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:life_pilot/controllers/auth/controller_auth.dart';
import 'package:life_pilot/controllers/event/controller_event.dart';
import 'package:life_pilot/controllers/event/controller_page_event_add.dart';
import 'package:life_pilot/core/app_navigator.dart';
import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/core/date_time.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/models/event/model_event_fields.dart';
import 'package:life_pilot/models/event/model_event_item.dart';
import 'package:life_pilot/services/event/service_event.dart';
import 'package:life_pilot/views/widgets/core/widgets_confirmation_dialog.dart';
import 'package:provider/provider.dart';

class PageMemoryAdd extends StatefulWidget {
  final ControllerAuth auth;
  final ServiceEvent serviceEvent;
  final ControllerEvent controllerEvent;
  final String tableName;
  final EventItem? existingEvent;
  final DateTime? initialDate;

  const PageMemoryAdd({
    super.key,
    required this.auth,
    required this.serviceEvent,
    required this.controllerEvent,
    required this.tableName,
    this.existingEvent,
    this.initialDate,
  });

  @override
  State<PageMemoryAdd> createState() => _PageMemoryAddState();
}

class _PageMemoryAddState extends State<PageMemoryAdd> {
  late final ControllerPageEventAdd controllerAdd;
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final Map<String, FocusNode> _focusNodes = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).unfocus();
    });
    controllerAdd = widget.controllerEvent.createAddController(
      existingEvent: widget.existingEvent,
      initialDate: widget.initialDate,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    controllerAdd.dispose();
    for (var node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  FocusNode getFocusNode(String key) {
    if (!_focusNodes.containsKey(key)) {
      _focusNodes[key] = FocusNode();
      _focusNodes[key]!.addListener(() {
        if (!_focusNodes[key]!.hasFocus) {
          // 離焦時更新
          controllerAdd.updateField(
              key, controllerAdd.getController(key: key).text, true);
        }
      });
    }
    return _focusNodes[key]!;
  }

  Future<void> _saveEvent(AppLocalizations loc) async {
    try {
      if (!(_formKey.currentState?.validate() ?? false)) return;
      FocusScope.of(context).unfocus();

      final event = controllerAdd.toEventItem();
      await widget.controllerEvent.saveEvent(
        oldEvent: widget.existingEvent == null ? event : widget.existingEvent!,
        newEvent: event,
        isNew: widget.existingEvent == null,
      );

      AppNavigator.showSnackBar(loc.eventSaved);
      if (context.mounted) Navigator.pop(context, event);
    } catch (error) {
      final message = error.toString().contains("event_save_error")
          ? loc.eventSaveError
          : error.toString();
      AppNavigator.showErrorBar(message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return ChangeNotifierProvider.value(
        value: controllerAdd,
        child: Consumer<ControllerPageEventAdd>(builder: (context, ctl, _) {
          return Scaffold(
            appBar: AppBar(
              title: Text(loc.eventAddEdit),
              actions: [
                TextButton(
                  onPressed: () => _saveEvent(loc),
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
                  padding: Insets.directionalL4R4T4B8,
                  children: [
                    _buildDateTimeRow(loc: loc, ctl: ctl),
                    ..._buildTextFields(loc: loc, ctl: ctl),
                    Gaps.h16,
                    Text(loc.eventSub),
                    ...List.generate(
                        ctl.subEvents.length,
                        (index) => _buildSubEventCard(
                            loc: loc, ctl: ctl, index: index)),
                    ElevatedButton.icon(
                      onPressed: () {
                        final newSub = EventItem(id: ctl.uuid.v4())
                          ..startDate = ctl.startDate
                          ..endDate = ctl.endDate
                          ..startTime = ctl.startTime
                          ..endTime = ctl.endTime
                          ..city = ctl.city
                          ..location = ctl.location
                          ..ageMin = ctl.ageMin
                          ..ageMax = ctl.ageMax
                          ..isFree = ctl.isFree
                          ..priceMin = ctl.priceMin
                          ..priceMax = ctl.priceMax
                          ..isOutdoor = ctl.isOutdoor
                          ..isLike = ctl.isLike
                          ..isDislike = ctl.isDislike
                          ..pageViews = ctl.pageViews
                          ..cardClicks = ctl.cardClicks
                          ..saves = ctl.saves
                          ..registrationClicks = ctl.registrationClicks
                          ..likeCounts = ctl.likeCounts
                          ..dislikeCounts = ctl.dislikeCounts;
                        setState(() {
                          final newIndex = newSub.id;
                          ctl.subEvents.add(newSub);
                          // ✅ 初始化該子事件的控制器
                          final subFields = {
                            EventFields.city: newSub.city,
                            EventFields.location: newSub.location,
                            EventFields.name: newSub.name,
                            EventFields.type: newSub.type,
                            EventFields.description: newSub.description,
                            //EventFields.fee: newSub.fee,
                            EventFields.unit: newSub.unit,
                            EventFields.masterUrl:
                                newSub.masterUrl ?? constEmpty,
                          };
                          subFields.forEach((key, value) {
                            ctl.initController(
                                key: '${key}_sub_$newIndex',
                                initialValue: value);
                          });
                        });
                        // 自動滑到最下
                        WidgetsBinding.instance.addPostFrameCallback((_) {
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
                      label: Text(loc.eventAddSub),
                    ),
                  ],
                ),
              ),
            ),
          );
        }));
  }

  // =====================================================
  // 🧱 組件建構部分
  // =====================================================
  List<Widget> _buildTextFields(
      {required AppLocalizations loc,
      required ControllerPageEventAdd ctl,
      String? index}) {
    Map<String, String> fields = {
      EventFields.city: loc.city,
      EventFields.location: loc.location,
      EventFields.name: loc.activityName,
      EventFields.type: loc.keywords,
      EventFields.masterUrl: loc.masterUrl,
      EventFields.description: loc.description,
      //EventFields.fee: loc.fee,
      //EventFields.unit: loc.sponsor,
      //EventFields.ageMin: loc.ageMin,
      //EventFields.ageMax: loc.ageMax,
      //EventFields.isFree: loc.isFree,
      //EventFields.priceMin: loc.priceMin,
      //EventFields.priceMax: loc.priceMax,
      //EventFields.isOutdoor: loc.isOutdoor,
    };
    return fields.entries.map((e) {
      final keyField = index == null ? e.key : '${e.key}_sub_$index';
      return SpeechTextField(
        keyField: keyField,
        label: e.value,
        controller: ctl,
        loc: loc,
        onChanged: (v) => ctl.updateField(keyField, v, false),
      );
    }).toList();
  }

  Widget _buildDateTimeRow(
      {required AppLocalizations loc,
      required ControllerPageEventAdd ctl,
      int? index}) {
    final dStart =
        index == null ? ctl.startDate : ctl.subEvents[index].startDate;
    final dEnd = index == null ? ctl.endDate : ctl.subEvents[index].endDate;
    final tStart =
        index == null ? ctl.startTime : ctl.subEvents[index].startTime;
    final tEnd = index == null ? ctl.endTime : ctl.subEvents[index].endTime;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
                child: _buildDateTile(
                    loc: loc,
                    date: dStart,
                    onTap: () =>
                        _pickDate(ctl: ctl, isStart: true, index: index),
                    type: CalendarMisc.startToS)),
            const Text(' ~ '),
            Expanded(
                child: _buildDateTile(
                    loc: loc,
                    date: dEnd,
                    onTap: () =>
                        _pickDate(ctl: ctl, isStart: false, index: index),
                    type: CalendarMisc.endToE)),
          ],
        ),
        Row(
          children: [
            Expanded(
                child: _buildTimeTile(
                    loc: loc,
                    time: tStart,
                    onTap: () =>
                        _pickTime(ctl: ctl, isStart: true, index: index),
                    type: CalendarMisc.startToS)),
            const Text(' ~ '),
            Expanded(
                child: _buildTimeTile(
                    loc: loc,
                    time: tEnd,
                    onTap: () =>
                        _pickTime(ctl: ctl, isStart: false, index: index),
                    type: CalendarMisc.endToE)),
          ],
        ),
      ],
    );
  }

  // =====================================================
  // 📅 時間與日期選擇
  // =====================================================
  Future<void> _pickDate(
      {required ControllerPageEventAdd ctl,
      required bool isStart,
      int? index}) async {
    final now = DateTime.now();
    final initial = isStart
        ? (index == null ? ctl.startDate : ctl.subEvents[index].startDate) ??
            now
        : (index == null ? ctl.endDate : ctl.subEvents[index].endDate) ?? now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.subtract(const Duration(days: 1800)),
      lastDate: now.add(const Duration(days: 1800)),
    );
    if (picked == null) return;

    setState(() {
      if (index == null) {
        isStart ? ctl.startDate = picked : ctl.endDate = picked;
        if (ctl.startDate != null &&
            ctl.endDate != null &&
            ctl.startDate!.isAfter(ctl.endDate!)) {
          ctl.endDate = ctl.startDate;
        }
      } else {
        isStart
            ? ctl.subEvents[index].startDate = picked
            : ctl.subEvents[index].endDate = picked;

        if (ctl.subEvents[index].startDate != null &&
            ctl.subEvents[index].endDate != null &&
            ctl.subEvents[index].startDate!
                .isAfter(ctl.subEvents[index].endDate!)) {
          ctl.subEvents[index].endDate = ctl.subEvents[index].startDate;
        }
      }
    });
  }

  Future<void> _pickTime(
      {required ControllerPageEventAdd ctl,
      required bool isStart,
      int? index}) async {
    final initial = isStart
        ? (index == null ? ctl.startTime : ctl.subEvents[index].startTime) ??
            TimeOfDay.now()
        : (index == null ? ctl.endTime : ctl.subEvents[index].endTime) ??
            TimeOfDay.now();

    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    setState(() {
      if (index == null) {
        isStart ? ctl.startTime = picked : ctl.endTime = picked;
      } else {
        isStart
            ? ctl.subEvents[index].startTime = picked
            : ctl.subEvents[index].endTime = picked;
      }
    });
  }

  Widget _buildDateTile(
      {required AppLocalizations loc,
      DateTime? date,
      required VoidCallback onTap,
      required String type}) {
    final text = date != null
        ? date.formatDateString(passYear: false, formatShow: true)
        : (type == CalendarMisc.startToS ? loc.startDate : loc.endDate);
    return ListTile(
      contentPadding: Insets.e0,
      visualDensity: VisualDensity(horizontal: -4, vertical: -2),
      subtitle: Text(text, textAlign: TextAlign.center),
      trailing: const Icon(Icons.calendar_today),
      onTap: onTap,
    );
  }

  Widget _buildTimeTile(
      {required AppLocalizations loc,
      TimeOfDay? time,
      required VoidCallback onTap,
      required String type}) {
    final text = time?.format(context) ??
        (type == CalendarMisc.startToS ? loc.startTime : loc.endTime);
    return ListTile(
      contentPadding: Insets.e0,
      visualDensity: VisualDensity(horizontal: -4, vertical: -2),
      subtitle: Text(text, textAlign: TextAlign.center),
      trailing: const Icon(Icons.access_time),
      onTap: onTap,
    );
  }

  Widget _buildSubEventCard(
      {required AppLocalizations loc,
      required ControllerPageEventAdd ctl,
      required int index}) {
    final d = ctl.subEvents[index];

    return Card(
      key: ValueKey(d.id),
      color: index % 2 == 0 ? Colors.blueGrey[50] : Colors.grey[300],
      child: Padding(
        padding: Insets.all4,
        child: Column(
          children: [
            _buildDateTimeRow(loc: loc, ctl: ctl, index: index),
            ..._buildTextFields(loc: loc, ctl: ctl, index: d.id),
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
                  onPressed: () async {
                    final event = ctl.subEvents[
                        index]; // 假設你有 subEvents list 裡的 item 為 event
                    final shouldDelete = await showConfirmationDialog(
                      content: 'No. ${index + 1} ${event.name} ${loc.delete}？',
                      confirmText: loc.delete,
                      cancelText: loc.cancel,
                    );

                    if (shouldDelete == true) {
                      try {
                        setState(() => ctl.subEvents.removeAt(index));
                      } catch (e) {
                        AppNavigator.showErrorBar('${loc.deleteError}: $e');
                      }
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SpeechTextField extends StatelessWidget {
  final String keyField;
  final String label;
  final int maxLines;
  final ControllerPageEventAdd controller;
  final AppLocalizations loc;
  final ValueChanged<String> onChanged;

  const SpeechTextField({
    super.key,
    required this.keyField,
    required this.label,
    required this.onChanged,
    required this.controller,
    required this.loc,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final ctrl = controller.getController(key: keyField);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (ctrl.text.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.volume_up),
            tooltip: loc.speakUp,
            onPressed: () => controller.speakText(text: ctrl.text),
          ),
        Expanded(
          child: TextFormField(
            controller: ctrl,
            decoration: InputDecoration(
              labelText: label,
              isDense: true,
              contentPadding: Insets.all3,
            ),
            maxLines: maxLines,
            onChanged: onChanged,
          ),
        ),
        IconButton(
          icon: Icon(
            Icons.mic,
            color: controller.isListening &&
                    controller.currentListeningKey == keyField
                ? Colors.red
                : null,
          ),
          tooltip: loc.speak,
          onPressed: () async {
            if (controller.isListening &&
                controller.currentListeningKey == keyField) {
              await controller.stopListening();
            } else {
              if (controller.isListening) {
                await controller.stopListening();
                await Future.delayed(const Duration(milliseconds: 200));
              }
              await controller.startListening(
                  onResult: (text) {
                    ctrl.text += ' $text'; // 加上追加模式
                    onChanged(ctrl.text);
                  },
                  key: keyField);
            }
          },
        ),
      ],
    );
  }
}
