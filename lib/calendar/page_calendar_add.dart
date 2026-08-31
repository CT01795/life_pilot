import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:life_pilot/calendar/controller_calendar.dart';
import 'package:life_pilot/calendar/controller_page_calendar_add.dart';
import 'package:life_pilot/event/event_save_exception.dart';
import 'package:life_pilot/event/widgets_event_country_dropdown.dart';
import 'package:life_pilot/utils/app_navigator.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/utils/event_latln.dart';
import 'package:life_pilot/utils/extension.dart';
import 'package:life_pilot/utils/widgets/widgets_confirmation_dialog.dart';
import 'package:provider/provider.dart';

class PageCalendarAdd extends StatefulWidget {
  final ControllerCalendar controllerCalendar;
  final EventItem? existingEvent;
  final DateTime? initialDate;

  const PageCalendarAdd({
    super.key,
    required this.controllerCalendar,
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
  final Map<String, FocusNode> _focusNodes = {};
  bool _isSaving = false;
  bool _hasUnsavedChanges = false;
  bool _allowPop = false;
  bool _discardDialogVisible = false;

  @override
  void initState() {
    super.initState();
    controllerAdd = widget.controllerCalendar.createAddController(
      existingEvent: widget.existingEvent,
      initialDate: widget.initialDate,
    );
    for (final controller in controllerAdd.controllerMap.values) {
      controller.addListener(_markUnsavedChanges);
    }
    controllerAdd.onContentChanged = _markUnsavedChanges;
  }

  @override
  void dispose() {
    controllerAdd.onContentChanged = null;
    _scrollController.dispose();
    controllerAdd.dispose();
    for (var node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _markUnsavedChanges() {
    if (!mounted || _hasUnsavedChanges) return;
    setState(() => _hasUnsavedChanges = true);
  }

  Future<void> _confirmDiscardChanges(AppLocalizations loc) async {
    if (_discardDialogVisible) return;
    _discardDialogVisible = true;
    final shouldDiscard = await showConfirmationDialog(
      content: loc.unsavedChangesPrompt,
      confirmText: loc.discardChanges,
      cancelText: loc.cancel,
    );
    _discardDialogVisible = false;
    if (!shouldDiscard || !mounted) return;

    setState(() => _allowPop = true);
    await Future<void>.delayed(Duration.zero);
    if (mounted) Navigator.of(context).pop();
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
    if (_isSaving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);
    try {
      FocusScope.of(context).unfocus();

      EventItem event = controllerAdd.toEventItem();
      event = await ClusterItem.getLatLngFromAddressItem(event);
      await widget.controllerCalendar.saveEventWithNotification(
        oldEvent: widget.existingEvent ?? event,
        newEvent: event,
        isNew: widget.existingEvent == null,
      );
      AppNavigator.showSnackBar(loc.eventSaved);
      if (context.mounted) {
        setState(() {
          _hasUnsavedChanges = false;
          _allowPop = true;
        });
        await Future<void>.delayed(Duration.zero);
        if (context.mounted) Navigator.pop(context, event);
      }
    } on EventSaveException catch (error) {
      final message = switch (error.error) {
        EventSaveError.missingName => loc.eventSaveError,
        EventSaveError.duplicate => loc.eventAlreadyExists,
      };
      AppNavigator.showErrorBar(message);
    } catch (_) {
      AppNavigator.showErrorBar(loc.eventSaveFailed);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    Map<String, String> fields = {
      EventFields.name: loc.activityName,
      EventFields.country: _countryLabel(),
      EventFields.city: loc.city,
      EventFields.location: loc.location,
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
              PopScope(
                canPop: _allowPop || !_hasUnsavedChanges,
                onPopInvokedWithResult: (didPop, _) {
                  if (!didPop) _confirmDiscardChanges(loc);
                },
                child: TextButton(
                  onPressed: _isSaving ? null : () => _saveEvent(loc),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white70,
                  ),
                  child: _isSaving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(loc.save),
                ),
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
                  ..._buildTextFields(
                      loc: loc, ctl: controllerAdd, fields: fields),
                  Gaps.h16,
                  Text(loc.eventSub),
                  Selector<ControllerPageCalendarAdd, int>(
                    selector: (_, ctl) => ctl.subEvents.length,
                    builder: (_, length, __) {
                      return Column(
                        children: List.generate(
                          length,
                          (index) => _buildSubEventCard(
                              loc: loc,
                              ctl: controllerAdd,
                              index: index,
                              fields: fields),
                        ),
                      );
                    },
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      controllerAdd.addSubEvent();
                      // 自動滑到最下
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
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

  String _countryLabel() =>
      switch (Localizations.localeOf(context).languageCode) {
        'zh' => '國家',
        'ja' => '国',
        'ko' => '국가',
        _ => 'Country',
      };

  // =====================================================
  // 🧱 組件建構部分
  // =====================================================
  List<Widget> _buildTextFields(
      {required AppLocalizations loc,
      required ControllerPageCalendarAdd ctl,
      required Map<String, String> fields,
      String? index}) {
    final Map<String, String> currentFields = Map.from(fields);
    return currentFields.entries.map((e) {
      final keyField = index == null ? e.key : '${e.key}_sub_$index';
      if (e.key == EventFields.country) {
        return WidgetsEventCountryDropdown(
          label: e.value,
          value: ctl.getController(key: keyField).text,
          onChanged: (value) => ctl.updateField(keyField, value, false),
        );
      }
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
      required ControllerPageCalendarAdd ctl,
      int? index}) {
    return Consumer<ControllerPageCalendarAdd>(builder: (_, ctl, __) {
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
    });
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
      required ControllerPageCalendarAdd ctl,
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
            ..._buildTextFields(
                loc: loc, ctl: ctl, index: d.id, fields: fields),
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
                        content:
                            'No. ${index + 1} ${event.name} ${loc.delete}？',
                        confirmText: loc.delete,
                        cancelText: loc.cancel,
                      );

                      if (shouldDelete == true) {
                        controllerAdd.removeSubEvent(index);
                      }
                    }),
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
  final int minLines;
  final ControllerPageCalendarAdd controller;
  final AppLocalizations loc;
  final ValueChanged<String> onChanged;

  const SpeechTextField({
    super.key,
    required this.keyField,
    required this.label,
    required this.onChanged,
    required this.controller,
    required this.loc,
    this.minLines = 1,
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
            maxLines: 3,
            minLines: minLines,
            keyboardType: TextInputType.multiline,
            onChanged: onChanged,
          ),
        ),
        Selector<ControllerPageCalendarAdd, bool>(
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
                          ctrl.selection = TextSelection.fromPosition(
                            TextPosition(offset: ctrl.text.length),
                          );
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
