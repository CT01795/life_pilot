import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/controller_auth.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/models/model_recommended_event.dart';
import 'package:life_pilot/services/service_storage.dart';
import 'package:life_pilot/utils/utils_common_function.dart';
import 'package:life_pilot/utils/utils_gaps.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

var logger = Logger();
final uuid = const Uuid();

class PageRecommendedEventAdd extends StatefulWidget {
  final RecommendedEvent? existingRecommendedEvent;

  const PageRecommendedEventAdd({
    super.key,
    this.existingRecommendedEvent,
  });

  @override
  State<PageRecommendedEventAdd> createState() =>
      _PageRecommendedEventAddState();
}

class _PageRecommendedEventAddState extends State<PageRecommendedEventAdd> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  AppLocalizations get loc => AppLocalizations.of(context)!;

  DateTime? startDate = DateTime.now();
  DateTime? endDate;
  TimeOfDay? startTime = TimeOfDay.fromDateTime(DateTime.now());
  TimeOfDay? endTime;
  String city = '';
  String location = '';
  String name = '';
  String type = '';
  String description = '';
  String fee = '';
  String unit = '';
  List<SubRecommendedEventItem> subEvents = [];

  String? masterGraphUrl;
  String? masterUrl;
  List<SubGraph> subGraphs = [];
  String? account = '';

  @override
  void initState() {
    super.initState();
    if (widget.existingRecommendedEvent != null) {
      final e = widget.existingRecommendedEvent!;
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
      subEvents = List.from(e.subRecommendedEvents);
      subGraphs = List.from(e.subGraphs);
      account = e.account;
    }
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
        } else {
          isStart
              ? subEvents[index].startDate = picked
              : subEvents[index].endDate = picked;
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
                    dStart, () => _pickDate(isStart: true, index: index), "S")),
            const Text(' ~ '),
            Expanded(
                child: _buildDateTile(
                    dEnd, () => _pickDate(isStart: false, index: index), "E")),
          ],
        ),
        Row(
          children: [
            Expanded(
                child: _buildTimeTile(
                    tStart, () => _pickTime(isStart: true, index: index), "S")),
            const Text(' ~ '),
            Expanded(
                child: _buildTimeTile(
                    tEnd, () => _pickTime(isStart: false, index: index), "E")),
          ],
        ),
      ],
    );
  }

  Widget _buildDateTile(DateTime? date, VoidCallback onTap, String type) {
    final text = date != null
        ? '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}'
        : (type == "S" ? loc.start_date : loc.end_date);
    return ListTile(
      contentPadding: kGapEI0,
      visualDensity: VisualDensity(horizontal: -4, vertical: -2),
      subtitle: Text(text, textAlign: TextAlign.center),
      trailing: const Icon(Icons.calendar_today),
      onTap: onTap,
    );
  }

  Widget _buildTimeTile(TimeOfDay? time, VoidCallback onTap, String type) {
    final text =
        time?.format(context) ?? (type == "S" ? loc.start_time : loc.end_time);
    return ListTile(
      contentPadding: kGapEI0,
      visualDensity: VisualDensity(horizontal: -4, vertical: -2),
      subtitle: Text(text, textAlign: TextAlign.center),
      trailing: const Icon(Icons.access_time),
      onTap: onTap,
    );
  }

  Widget _buildTextField({
    required String label,
    required String initialValue,
    required ValueChanged<String> onChanged,
    int maxLines = 1,
  }) {
    return TextFormField(
      initialValue: initialValue,
      decoration: InputDecoration(labelText: label),
      maxLines: maxLines,
      onChanged: onChanged,
    );
  }

  Widget _buildSubEventCard(int index) {
    final d = subEvents[index];
    return Card(
      key: ValueKey(d.id.isNotEmpty ? d.id : index),
      color: index % 2 == 0 ? Colors.grey[300] : Colors.purple[100],
      child: Padding(
        padding: kGapEI4,
        child: Column(
          children: [
            _buildDateTimeRow(index: index),
            _buildTextField(
                label: loc.location,
                initialValue: d.location,
                onChanged: (v) => d.location = v),
            _buildTextField(
                label: loc.activity_name,
                initialValue: d.name,
                onChanged: (v) => d.name = v),
            _buildTextField(
                label: loc.keywords,
                initialValue: d.type,
                onChanged: (v) => d.type = v),
            _buildTextField(
                label: loc.sub_url,
                initialValue: d.subUrl ?? '',
                onChanged: (v) => d.subUrl = v),
            _buildTextField(
                label: loc.description,
                initialValue: d.description,
                onChanged: (v) => d.description = v,
                maxLines: 2),
            _buildTextField(
                label: loc.fee,
                initialValue: d.fee,
                onChanged: (v) => d.fee = v),
            _buildTextField(
                label: loc.sponsor,
                initialValue: d.unit,
                onChanged: (v) => d.unit = v),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.delete, color: Colors.pinkAccent),
                onPressed: () => setState(() => subEvents.removeAt(index)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final auth = Provider.of<ControllerAuth>(context, listen: false);
    final event = RecommendedEvent(
      id: widget.existingRecommendedEvent?.id ?? uuid.v4(),
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
      subRecommendedEvents: subEvents
          .map((d) => d.id.isEmpty ? d.copyWith(id: uuid.v4()) : d)
          .toList(),
      subGraphs: subGraphs,
      account: auth.currentAccount,
    );
    await ServiceStorage()
        .saveRecommendedEvent(context, event, widget.existingRecommendedEvent == null);
    showSnackBar(context, loc.event_saved);

    Navigator.pop(context, event);
  }

  @override
  void dispose() {
    _scrollController.dispose();
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
                  label: loc.city,
                  initialValue: city,
                  onChanged: (v) => city = v),
              _buildTextField(
                  label: loc.location,
                  initialValue: location,
                  onChanged: (v) => location = v),
              _buildTextField(
                  label: loc.activity_name,
                  initialValue: name,
                  onChanged: (v) => name = v),
              _buildTextField(
                  label: loc.keywords,
                  initialValue: type,
                  onChanged: (v) => type = v),
              _buildTextField(
                  label: loc.master_url,
                  initialValue: masterUrl ?? '',
                  onChanged: (v) => masterUrl = v),
              _buildTextField(
                  label: loc.description,
                  initialValue: description,
                  onChanged: (v) => description = v,
                  maxLines: 2),
              _buildTextField(
                  label: loc.fee, initialValue: fee, onChanged: (v) => fee = v),
              _buildTextField(
                  label: loc.sponsor,
                  initialValue: unit,
                  onChanged: (v) => unit = v),
              Text(loc.event_sub),
              ...List.generate(subEvents.length, _buildSubEventCard),
              kGapH8,
              ElevatedButton.icon(
                onPressed: () {
                  setState(() => subEvents.add(SubRecommendedEventItem(
                      startDate: startDate,
                      startTime: startTime,
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
