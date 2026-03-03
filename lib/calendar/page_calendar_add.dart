import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/calendar/controller_calendar.dart';
import 'package:life_pilot/calendar/controller_page_calendar_add.dart';
import 'package:life_pilot/utils/app_navigator.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/event/service_event.dart';
import 'package:life_pilot/utils/extension.dart';
import 'package:life_pilot/utils/widgets/widgets_confirmation_dialog.dart';
import 'package:provider/provider.dart';

class PageCalendarAdd extends StatefulWidget {
  final ControllerAuth auth;
  final ServiceEvent serviceEvent;
  final ControllerCalendar controllerCalendar;
  final String tableName;
  final EventItem? existingEvent;
  final DateTime? initialDate;

  const PageCalendarAdd({
    super.key,
    required this.auth,
    required this.serviceEvent,
    required this.controllerCalendar,
    required this.tableName,
    this.existingEvent,
    this.initialDate,
  });

  @override
  State<PageCalendarAdd> createState() => _PageCalendarAddState();
}

class _PageCalendarAddState extends State<PageCalendarAdd> {
  late final ControllerPageCalendarAdd controllerAdd;
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final Map<String, TextEditingController> _textControllers = {};
  final Map<String, FocusNode> _focusNodes = {};

  @override
  void initState() {
    super.initState();
    controllerAdd = widget.controllerCalendar.createAddController(
      existingEvent: widget.existingEvent,
      initialDate: widget.initialDate,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).unfocus();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    controllerAdd.dispose();
    for (var node in _focusNodes.values) {
      node.dispose();
    }
    for (var ctrl in _textControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  TextEditingController getTextController(String key, {String? initial}) {
    return _textControllers.putIfAbsent(
        key, () => TextEditingController(text: initial ?? ''));
  }

  FocusNode getFocusNode(String key, {EventItem? sub}) {
    if (!_focusNodes.containsKey(key)) {
      _focusNodes[key] = FocusNode();
      _focusNodes[key]!.addListener(() {
        if (!_focusNodes[key]!.hasFocus) {
          // 離焦時更新
          final value = getTextController(key).text;
          final realKey = key.split('_').first;
          controllerAdd.updateField(realKey, value, check: true, sub: sub);
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
      await widget.controllerCalendar.saveEventWithNotification(
        oldEvent: widget.existingEvent ?? event,
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
        child: Consumer<ControllerPageCalendarAdd>(builder: (context, _, __) {
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
                    _buildDateTimeRow(loc: loc, ctl: controllerAdd),
                    ..._buildTextFields(loc: loc, ctl: controllerAdd),
                    Gaps.h16,
                    Text(loc.eventSub),
                    ...List.generate(
                        controllerAdd.event.subEvents.length,
                        (index) => _buildSubEventCard(
                            loc: loc,
                            sub: controllerAdd.event.subEvents[index],
                            index: index)),
                    ElevatedButton.icon(
                      onPressed: () {
                        controllerAdd.addSubEvent();
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
      required ControllerPageCalendarAdd ctl,
      EventItem? sub}) {
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
      final keyField = sub == null ? e.key : '${e.key}_sub_${sub.id}';
      final controller = getTextController(keyField,
          initial: sub != null
              ? sub.toJson()[e.key]?.toString() ?? ''
              : ctl.event.toJson()[e.key]?.toString() ?? '');
      final focusNode = getFocusNode(keyField, sub: sub);
      return SpeechTextField(
        keyField: keyField,
        label: e.value,
        textController: controller,
        focusNode: focusNode,
        controller: ctl,
        loc: loc,
        onChanged: (v) => ctl.updateField(e.key, v, sub: sub, check: false),
      );
    }).toList();
  }

  Widget _buildSubEventCard(
      {required AppLocalizations loc,
      required EventItem sub,
      required int index}) {
    return Card(
      key: ValueKey(sub.id),
      color: index % 2 == 0 ? Colors.blueGrey[50] : Colors.grey[300],
      child: Padding(
        padding: Insets.all4,
        child: Column(
          children: [
            _buildDateTimeRow(loc: loc, ctl: controllerAdd, sub: sub),
            ..._buildTextFields(loc: loc, ctl: controllerAdd, sub: sub),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '#${index + 1} ${DateFormat('MM/dd').format(sub.startDate!)} ${sub.startTime!.format(context)} ${sub.name.substring(0, sub.name.length > 5 ? 5 : sub.name.length)}${sub.name.length > 5 ? '...' : ''}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.pinkAccent),
                  tooltip: loc.delete,
                  onPressed: () async {
                    final event = controllerAdd.event.subEvents[
                        index]; // 假設你有 subEvents list 裡的 item 為 event
                    final shouldDelete = await showConfirmationDialog(
                      content: 'No. ${index + 1} ${event.name} ${loc.delete}？',
                      confirmText: loc.delete,
                      cancelText: loc.cancel,
                    );

                    if (shouldDelete == true) {
                      try {
                        controllerAdd.removeSubEvent(sub.id);
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

  Widget _buildDateTimeRow(
      {required AppLocalizations loc,
      required ControllerPageCalendarAdd ctl,
      EventItem? sub}) {
    final dStart = sub?.startDate ?? ctl.event.startDate;
    final dEnd = sub?.endDate ?? ctl.event.endDate;
    final tStart = sub?.startTime ?? ctl.event.startTime;
    final tEnd = sub?.endTime ?? ctl.event.endTime;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
                child: _buildDateTile(
                    loc: loc,
                    date: dStart,
                    onTap: () =>
                        _pickDate(item: sub ?? ctl.event, isStart: true),
                    type: CalendarMisc.startToS)),
            const Text(' ~ '),
            Expanded(
                child: _buildDateTile(
                    loc: loc,
                    date: dEnd,
                    onTap: () =>
                        _pickDate(item: sub ?? ctl.event, isStart: false),
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
                        _pickTime(item: sub ?? ctl.event, isStart: true),
                    type: CalendarMisc.startToS)),
            const Text(' ~ '),
            Expanded(
                child: _buildTimeTile(
                    loc: loc,
                    time: tEnd,
                    onTap: () =>
                        _pickTime(item: sub ?? ctl.event, isStart: false),
                    type: CalendarMisc.endToE)),
          ],
        ),
      ],
    );
  }

  // ==========================
  // 📅 日期 / 時間選擇
  // ==========================
  Future<void> _pickDate(
      {required EventItem item, required bool isStart}) async {
    final now = DateTime.now();
    final initial = isStart ? item.startDate ?? now : item.endDate ?? now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.subtract(const Duration(days: 1800)),
      lastDate: now.add(const Duration(days: 1800)),
    );
    if (picked == null) return;
    controllerAdd.updateDate(
      item: item,
      date: picked,
      isStart: isStart,
    );
  }

  Future<void> _pickTime(
      {required EventItem item, required bool isStart}) async {
    final initial = isStart
        ? item.startTime ?? TimeOfDay.now()
        : item.endTime ?? TimeOfDay.now();

    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    controllerAdd.updateTime(
      item: item,
      time: picked,
      isStart: isStart,
    );
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
}

class SpeechTextField extends StatelessWidget {
  final String keyField;
  final String label;
  final int maxLines;
  final ControllerPageCalendarAdd controller;
  final AppLocalizations loc;
  final ValueChanged<String> onChanged;
  final TextEditingController textController;
  final FocusNode focusNode;

  const SpeechTextField({
    super.key,
    required this.keyField,
    required this.label,
    required this.onChanged,
    required this.controller,
    required this.loc,
    required this.textController,
    required this.focusNode,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (textController.text.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.volume_up),
            tooltip: loc.speakUp,
            onPressed: () => controller.speakText(text: textController.text),
          ),
        Expanded(
          child: TextFormField(
            controller: textController,
            focusNode: focusNode,
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
                    textController.text += ' $text'; // 加上追加模式
                    onChanged(textController.text);
                  },
                  key: keyField);
            }
          },
        ),
      ],
    );
  }
}
