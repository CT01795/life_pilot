import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:life_pilot/event/controller_event.dart';
import 'package:life_pilot/event/controller_page_event_add.dart';
import 'package:life_pilot/utils/app_navigator.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/utils/extension.dart';
import 'package:life_pilot/utils/widgets/widgets_confirmation_dialog.dart';
import 'package:provider/provider.dart';

class PageMemoryAdd extends StatefulWidget {
  final ControllerEvent controllerEvent;
  final EventItem? existingEvent;
  final DateTime? initialDate;

  const PageMemoryAdd({
    super.key,
    required this.controllerEvent,
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
    return _focusNodes.putIfAbsent(key, () {
      final node = FocusNode();

      node.addListener(() {
        if (!node.hasFocus) {
          controllerAdd.updateField(
            key,
            controllerAdd.getController(key: key).text,
            true,
          );
        }
      });

      return node;
    });
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
    return ChangeNotifierProvider.value(
        value: controllerAdd,
        child: Scaffold(
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
                  ..._buildTextFields(loc: loc, ctl: controllerAdd, fields: fields),
                  Gaps.h16,
                  Text(loc.eventSub),
                  Selector<ControllerPageEventAdd, int>(
                    selector: (_, ctl) => ctl.subEvents.length,
                    builder: (_, length, __) {
                      return ListView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          itemCount: length,
                          itemBuilder: (_, index) {
                            return _buildSubEventCard(
                                loc: loc, ctl: controllerAdd, index: index, fields: fields);
                          });
                    },
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      controllerAdd.addSubEvent();
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
        ));
  }

  // =====================================================
  // 🧱 組件建構部分
  // =====================================================
  List<Widget> _buildTextFields(
      {required AppLocalizations loc,
      required ControllerPageEventAdd ctl,
      required Map<String, String> fields,
      String? index}) {
    final Map<String,String> currentFields = Map.from(fields);
    return currentFields.entries.map((e) {
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
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: dStart ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );

                  if (picked != null) {
                    ctl.setDate(picked, isStart: true, index: index);
                  }
                },
                type: CalendarMisc.startToS,
              ),
            ),
            const Text(' ~ '),
            Expanded(
                child: _buildDateTile(
                    loc: loc,
                    date: dEnd,
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: dEnd ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );

                      if (picked != null) {
                        ctl.setDate(picked, isStart: false, index: index);
                      }
                    },
                    type: CalendarMisc.endToE)),
          ],
        ),
        Row(
          children: [
            Expanded(
                child: _buildTimeTile(
                    loc: loc,
                    time: tStart,
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: tStart ?? TimeOfDay.now(),
                      );

                      if (picked != null) {
                        ctl.setTime(picked, isStart: true, index: index);
                      }
                    },
                    type: CalendarMisc.startToS)),
            const Text(' ~ '),
            Expanded(
                child: _buildTimeTile(
                    loc: loc,
                    time: tEnd,
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: tEnd ?? TimeOfDay.now(),
                      );

                      if (picked != null) {
                        ctl.setTime(picked, isStart: false, index: index);
                      }
                    },
                    type: CalendarMisc.endToE)),
          ],
        ),
      ],
    );
  }

  // =====================================================
  // 📅 時間與日期選擇
  // =====================================================
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
      required Map<String, String> fields,
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
            ..._buildTextFields(loc: loc, ctl: ctl, index: d.id, fields: fields),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '#${index + 1} ${DateFormat('MM/dd').format(d.startDate!)} ${d.startTime!.format(context)} ${d.name.substring(0, d.name.length > 5 ? 5 : d.name.length)}${d.name.length > 5 ? '...' : ''}',
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
                      controllerAdd.removeSubEvent(index);
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
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: ctrl,
          builder: (_, value, __) {
            if (value.text.isEmpty) return const SizedBox.shrink();
            return IconButton(
              icon: const Icon(Icons.volume_up),
              tooltip: loc.speakUp,
              onPressed: () => controller.speakText(text: ctrl.text),
            );
          },
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
        Selector<ControllerPageEventAdd, bool>(
            selector: (_, ctl) =>
                ctl.isListening && ctl.currentListeningKey == keyField,
            builder: (_, isActive, __) {
              return IconButton(
                icon: Icon(
                  Icons.mic,
                  color: isActive ? Colors.red : null,
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
              );
            }),
      ],
    );
  }
}
