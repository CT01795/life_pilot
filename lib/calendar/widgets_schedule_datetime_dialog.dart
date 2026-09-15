import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/const.dart';

class ScheduleDateTimeChoice {
  const ScheduleDateTimeChoice({required this.date, required this.time});

  final DateTime date;
  final TimeOfDay time;

  DateTime get dateTime => DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
}

Future<ScheduleDateTimeChoice?> showScheduleDateTimeDialog(
  BuildContext context, {
  required String title,
  required DateTime initialDate,
  required TimeOfDay initialTime,
  String? description,
}) {
  var selectedDate = DateUtils.dateOnly(initialDate);
  var selectedTime = initialTime;
  final loc = AppLocalizations.of(context)!;

  return showDialog<ScheduleDateTimeChoice>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(loc.addToSchedule),
        content: SizedBox(
          width: MediaQuery.sizeOf(context).width.clamp(0, 420).toDouble(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              if (description != null && description.trim().isNotEmpty) ...[
                Gaps.h8,
                Text(description),
              ],
              Gaps.h16,
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_outlined),
                title: Text(loc.recordDate),
                trailing: TextButton(
                  onPressed: () async {
                    final value = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(1900),
                      lastDate: DateTime(2200),
                    );
                    if (value != null) setState(() => selectedDate = value);
                  },
                  child: Text(
                    DateFormat.yMMMd(loc.localeName).format(selectedDate),
                  ),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule_outlined),
                title: Text(loc.recordTime),
                trailing: TextButton(
                  onPressed: () async {
                    final value = await showTimePicker(
                      context: context,
                      initialTime: selectedTime,
                    );
                    if (value != null) setState(() => selectedTime = value);
                  },
                  child: Text(selectedTime.format(context)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(loc.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              ScheduleDateTimeChoice(
                date: selectedDate,
                time: selectedTime,
              ),
            ),
            child: Text(loc.confirm),
          ),
        ],
      ),
    ),
  );
}
