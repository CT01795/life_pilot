import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:life_pilot/point_record/model_point_record_preview.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/record_categories.dart';
import 'package:life_pilot/utils/record_date_time.dart';
import 'package:life_pilot/utils/value_parser.dart';

Future<PointRecordPreview?> showPointRecordDialog(
  BuildContext context,
  PointRecordPreview record, {
  bool isNew = false,
  bool proposal = false,
}) async {
  bool isPositive = record.value >= 0;
  final valueController = TextEditingController(
    text: isNew ? '' : record.value.abs().toString(),
  );
  final descController = TextEditingController(text: record.description);
  DateTime selectedDate = record.date ?? DateTime.now();
  String primaryCategory = record.primaryCategory;
  final secondaryController = TextEditingController(
    text: record.secondaryCategory ?? '',
  );
  final loc = AppLocalizations.of(context)!;

  String? validationError;
  return showDialog<PointRecordPreview>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(
          proposal
              ? loc.ledgerSubmitProposal
              : (isNew ? loc.manualEntry : loc.editRecord),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(
                    value: true,
                    icon: const Icon(Icons.add_circle_outline),
                    label: Text(loc.eventPointIncrease),
                  ),
                  ButtonSegment(
                    value: false,
                    icon: const Icon(Icons.remove_circle_outline),
                    label: Text(loc.eventPointDecrease),
                  ),
                ],
                selected: {isPositive},
                onSelectionChanged: (value) {
                  if (value.isEmpty) return;
                  setState(() => isPositive = value.first);
                },
              ),
              Gaps.h8,
              TextField(
                controller: descController,
                decoration: InputDecoration(labelText: loc.description),
              ),
              TextField(
                controller: valueController,
                decoration: InputDecoration(
                  labelText: loc.recordValue,
                  errorText: validationError,
                  errorMaxLines: 3,
                ),
                keyboardType: TextInputType.number,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: Text(loc.recordDate),
                subtitle: Text(
                  DateFormat.yMd(
                    Localizations.localeOf(context).toString(),
                  ).format(selectedDate),
                ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (picked != null) {
                    setState(() {
                      selectedDate = replaceRecordDate(selectedDate, picked);
                    });
                  }
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.access_time),
                title: Text(loc.recordTime),
                subtitle: Text(
                  MaterialLocalizations.of(
                    context,
                  ).formatTimeOfDay(TimeOfDay.fromDateTime(selectedDate)),
                ),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(selectedDate),
                  );
                  if (picked == null) return;
                  setState(() {
                    selectedDate = replaceRecordTime(selectedDate, picked);
                  });
                },
              ),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: RecordCategories.points.contains(primaryCategory)
                    ? primaryCategory
                    : RecordCategories.uncategorized,
                decoration: InputDecoration(
                  labelText: loc.recordPrimaryCategory,
                ),
                items: RecordCategories.points
                    .map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Text(RecordCategories.label(loc, category)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) primaryCategory = value;
                },
              ),
              TextField(
                controller: secondaryController,
                decoration: InputDecoration(
                  labelText: loc.recordSecondaryCategory,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(loc.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              final value = tryParseIntValue(valueController.text);
              final description = descController.text.trim();
              if (value == null ||
                  value <= 0 ||
                  (proposal &&
                      value > (isPositive ? 2147483647 : 2147483648)) ||
                  description.isEmpty) {
                setState(() => validationError = loc.recordInputInvalid);
                return;
              }
              Navigator.pop(
                context,
                record.copyWith(
                  value: isPositive ? value : -value,
                  description: description,
                  date: selectedDate,
                  primaryCategory: primaryCategory,
                  secondaryCategory: secondaryController.text.trim(),
                ),
              );
            },
            child: Text(proposal ? loc.ledgerSubmitProposal : loc.save),
          ),
        ],
      ),
    ),
  );
}
