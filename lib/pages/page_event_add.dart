import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:life_pilot/controllers/controller_page_event_add.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/models/model_event_item.dart';
import 'package:life_pilot/models/model_event_fields.dart';
import 'package:life_pilot/utils/utils_common_function.dart';
import 'package:life_pilot/utils/core/utils_const.dart';
import 'package:life_pilot/utils/dialog/utils_show_dialog.dart';
import 'package:provider/provider.dart';

class PageEventAdd extends StatefulWidget {
  final String tableName;
  final EventItem? existingEvent;
  final DateTime? initialDate;

  const PageEventAdd({
    super.key,
    required this.tableName,
    this.existingEvent,
    this.initialDate,
  });

  @override
  State<PageEventAdd> createState() => _PageEventAddState();
}

class _PageEventAddState extends State<PageEventAdd> {
  late ControllerPageEventAdd controller;
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  late AppLocalizations _loc;

  @override
  void initState() {
    super.initState();
    controller = ControllerPageEventAdd(
      tableName: widget.tableName,
      existingEvent: widget.existingEvent,
      initialDate: widget.initialDate,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loc = AppLocalizations.of(context)!;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    controller.dispose();
    super.dispose();
  }

  Widget _buildDateTimeRow({int? index}) {
    final dStart = index == null ? controller.startDate : controller.subEvents[index].startDate;
    final dEnd = index == null ? controller.endDate : controller.subEvents[index].endDate;
    final tStart = index == null ? controller.startTime : controller.subEvents[index].startTime;
    final tEnd = index == null ? controller.endTime : controller.subEvents[index].endTime;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
                child: _buildDateTile(date: dStart,
                    onTap: () => _pickDate(isStart: true, index: index),
                    type: constStartToS)),
            const Text(' ~ '),
            Expanded(
                child: _buildDateTile(date: dEnd,
                    onTap: () => _pickDate(isStart: false, index: index),
                    type: constEndToE)),
          ],
        ),
        Row(
          children: [
            Expanded(
                child: _buildTimeTile(time: tStart,
                    onTap: () => _pickTime(isStart: true, index: index),
                    type: constStartToS)),
            const Text(' ~ '),
            Expanded(
                child: _buildTimeTile(time: tEnd,
                    onTap: () => _pickTime(isStart: false, index: index),
                    type: constEndToE)),
          ],
        ),
      ],
    );
  }

  Future<void> _pickDate({required bool isStart, int? index}) async {
    final initial = isStart
        ? (index == null ? controller.startDate : controller.subEvents[index].startDate) ??
            DateTime.now()
        : (index == null ? controller.endDate : controller.subEvents[index].endDate) ??
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
          isStart ? controller.startDate = picked : controller.endDate = picked;
          if (controller.startDate != null &&
              controller.endDate != null &&
              controller.startDate!.isAfter(controller.endDate!)) {
            controller.endDate = controller.startDate;
          }
        } else {
          isStart
              ? controller.subEvents[index].startDate = picked
              : controller.subEvents[index].endDate = picked;

          if (controller.subEvents[index].startDate != null &&
              controller.subEvents[index].endDate != null &&
              controller.subEvents[index].startDate!.isAfter(controller.subEvents[index].endDate!)) {
            controller.subEvents[index].endDate = controller.subEvents[index].startDate;
          }
        }
      });
    }
  }

  Future<void> _pickTime({required bool isStart, int? index}) async {
    final initial = isStart
        ? (index == null ? controller.startTime : controller.subEvents[index].startTime) ??
            TimeOfDay.now()
        : (index == null ? controller.endTime : controller.subEvents[index].endTime) ??
            TimeOfDay.now();

    final picked = await showTimePicker(context: context, initialTime: initial);

    if (picked != null) {
      setState(() {
        if (index == null) {
          isStart ? controller.startTime = picked : controller.endTime = picked;
        } else {
          isStart
              ? controller.subEvents[index].startTime = picked
              : controller.subEvents[index].endTime = picked;
        }
      });
    }
  }

  Widget _buildDateTile(
      {DateTime? date, required VoidCallback onTap, required String type}) {
    final text = date != null
        ? '${date.year}/${date.month.toString().padLeft(2, constZero)}/${date.day.toString().padLeft(2, constZero)}'
        : (type == constStartToS ? _loc.start_date : _loc.end_date);
    return ListTile(
      contentPadding: kGapEI0,
      visualDensity: VisualDensity(horizontal: -4, vertical: -2),
      subtitle: Text(text, textAlign: TextAlign.center),
      trailing: const Icon(Icons.calendar_today),
      onTap: onTap,
    );
  }

  Widget _buildTimeTile(
      {TimeOfDay? time, required VoidCallback onTap, required String type}) {
    final text = time?.format(context) ??
        (type == constStartToS ? _loc.start_time : _loc.end_time);
    return ListTile(
      contentPadding: kGapEI0,
      visualDensity: VisualDensity(horizontal: -4, vertical: -2),
      subtitle: Text(text, textAlign: TextAlign.center),
      trailing: const Icon(Icons.access_time),
      onTap: onTap,
    );
  }

  Widget _buildSubEventCard({required int index}) {
    final d = controller.subEvents[index];

    // 確保 subEvent 也有 id，沒的話補一個
    if (d.id.isEmpty) {
      controller.subEvents[index] = d.copyWith(newId: controller.uuid.v4());
    }

    return Card(
      key: ValueKey(d.id),
      color: index % 2 == 0 ? Colors.blueGrey[50] : Colors.grey[300],
      child: Padding(
        padding: kGapEI4,
        child: Column(
          children: [
            _buildDateTimeRow(index: index),
            SpeechTextField(
              keyField: '${EventFields.location}_sub_$index',
              label: _loc.location,
              onChanged: (v) => setState(() => d.location = v),
              controller: controller,
              loc: _loc,
            ),
            SpeechTextField(
              keyField: '${EventFields.name}_sub_$index',
              label: _loc.activity_name,
              onChanged: (v) => setState(() => d.name = v),
              controller: controller,
              loc: _loc,
            ),
            SpeechTextField(
              keyField: '${EventFields.type}_sub_$index',
              label: _loc.keywords,
              onChanged: (v) => setState(() => d.type = v),
              controller: controller,
              loc: _loc,
            ),
            SpeechTextField(
              keyField: '${EventFields.masterUrl}_sub_$index',
              label: _loc.sub_url,
              onChanged: (v) => setState(() => d.masterUrl = v),
              controller: controller,
              loc: _loc,
            ),
            SpeechTextField(
              keyField: '${EventFields.description}_sub_$index',
              label: _loc.description,
              onChanged: (v) => setState(() => d.description = v),
              maxLines: 2,
              controller: controller,
              loc: _loc,
            ),
            SpeechTextField(
              keyField: '${EventFields.fee}_sub_$index',
              label: _loc.fee,
              onChanged: (v) => setState(() => d.fee = v),
              controller: controller,
              loc: _loc,
            ),
            SpeechTextField(
              keyField: '${EventFields.unit}_sub_$index',
              label: _loc.sponsor,
              onChanged: (v) => setState(() => d.unit = v),
              controller: controller,
              loc: _loc,
            ),
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
                  tooltip: _loc.delete,
                  onPressed: () async {
                    final event =
                        controller.subEvents[index]; // 假設你有 subEvents list 裡的 item 為 event
                    final shouldDelete = await showConfirmationDialog(
                      content: 'No. ${index + 1} ${event.name} ${_loc.delete}？',
                      confirmText: _loc.delete,
                      cancelText: _loc.cancel,
                    );

                    if (shouldDelete == true) {
                      try {
                        setState(() => controller.subEvents.removeAt(index));
                      } catch (e) {
                        showSnackBar(message: '${_loc.delete_error}: $e');
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

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final newEvent = EventItem(
      subEvents: controller.subEvents
          .map((d) => d.id.isEmpty ? d.copyWith(newId: controller.uuid.v4()) : d)
          .toList(),
    );

    newEvent.setFromForm(
      id: widget.existingEvent?.id ?? controller.uuid.v4(),
      masterGraphUrl: controller.masterGraphUrl,
      masterUrl: controller.masterUrl,
      startDate: controller.startDate,
      endDate: controller.endDate,
      startTime: controller.startTime,
      endTime: controller.endTime,
      city: controller.city,
      location: controller.location,
      name: controller.name,
      type: controller.type,
      description: controller.description,
      fee: controller.fee,
      unit: controller.unit,
      account: controller.auth.currentAccount,
      repeatOptions: widget.existingEvent?.repeatOptions ?? controller.repeatOptions,
      reminderOptions: widget.existingEvent?.reminderOptions ?? controller.reminderOptions,
    );

    await controller.storage.saveEvent(
        event: newEvent,
        isNew: widget.existingEvent == null,
        tableName: widget.tableName,
        loc: _loc);
    showSnackBar(message: _loc.event_saved);

    Navigator.pop(context, newEvent);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ControllerPageEventAdd>.value(
      value: controller,
      child: Consumer<ControllerPageEventAdd>(
        builder: (context, ctl, child) {
          return Scaffold(
            appBar: AppBar(
              title: Text(_loc.event_add_edit),
              actions: [
                TextButton(
                  onPressed: _submit,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                  ),
                  child: Text(_loc.save),
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
                    SpeechTextField(
                      keyField: EventFields.city,
                      label: _loc.city,
                      onChanged: (v) => setState(() => controller.city = v),
                      controller: controller,
                      loc: _loc,
                    ),
                    SpeechTextField(
                      keyField: EventFields.location,
                      label: _loc.location,
                      onChanged: (v) => setState(() => controller.location = v),
                      controller: controller,
                      loc: _loc,
                    ),
                    SpeechTextField(
                      keyField: EventFields.name,
                      label: _loc.activity_name,
                      onChanged: (v) => setState(() => controller.name = v),
                      controller: controller,
                      loc: _loc,
                    ),
                    SpeechTextField(
                      keyField: EventFields.type,
                      label: _loc.keywords,
                      onChanged: (v) => setState(() => controller.type = v),
                      controller: controller,
                      loc: _loc,
                    ),
                    SpeechTextField(
                      keyField: EventFields.masterUrl,
                      label: _loc.master_url,
                      onChanged: (v) => setState(() => controller.masterUrl = v),
                      controller: controller,
                      loc: _loc,
                    ),
                    SpeechTextField(
                      keyField: EventFields.description,
                      label: _loc.description,
                      onChanged: (v) => setState(() => controller.description = v),
                      maxLines: 2,
                      controller: controller,
                      loc: _loc,
                    ),
                    SpeechTextField(
                      keyField: EventFields.fee,
                      label: _loc.fee,
                      onChanged: (v) => setState(() => controller.fee = v),
                      controller: controller,
                      loc: _loc,
                    ),
                    SpeechTextField(
                      keyField: EventFields.unit,
                      label: _loc.sponsor,
                      onChanged: (v) => setState(() => controller.unit = v),
                      controller: controller,
                      loc: _loc,
                    ),
                    kGapH16(),
                    Text(_loc.event_sub),
                    ...List.generate(controller.subEvents.length, (index) => _buildSubEventCard(index: index)),
                    ElevatedButton.icon(
                      onPressed: () {
                        final newSub = EventItem(id: controller.uuid.v4())
                          ..startDate = controller.startDate
                          ..endDate = controller.endDate
                          ..startTime = controller.startTime
                          ..endTime = controller.endTime
                          ..city = controller.city
                          ..location = controller.location;
                        setState(() {
                          controller.subEvents.add(newSub);
                        });
                        // 自動滑到最下
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
                      label: Text(_loc.event_add_sub),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      )
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

  const SpeechTextField({super.key, 
    required this.keyField,
    required this.label,
    required this.onChanged,
    required this.controller,
    required this.loc,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    controller.initController(key: keyField, initialValue: '');
    final ctrl = controller.getController(key: keyField);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (ctrl.text.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.volume_up),
            tooltip: loc.speak_up,
            onPressed: () => controller.speakText(text: ctrl.text),
          ),
        Expanded(
          child: TextFormField(
            controller: ctrl,
            decoration: InputDecoration(
              labelText: label,
              isDense: true,
              contentPadding: kGapEI3,
            ),
            maxLines: maxLines,
            onChanged: onChanged,
          ),
        ),
        IconButton(
          icon: Icon(
            Icons.mic,
            color: controller.isListening && controller.currentListeningKey == keyField
                ? Colors.red
                : null,
          ),
          tooltip: loc.speak,
          onPressed: () async {
            if (controller.isListening && controller.currentListeningKey == keyField) {
              await controller.stopListening();
            } else {
              if (controller.isListening) {
                await controller.stopListening();
                await Future.delayed(const Duration(milliseconds: 200));
              }
              await controller.startListening(onResult: (text) {
                ctrl.text += ' $text'; // 加上追加模式
                onChanged(ctrl.text);
              }, key: keyField);
            }
          },
        ),
      ],
    );
  }
}