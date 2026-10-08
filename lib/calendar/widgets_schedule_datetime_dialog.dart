import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/const.dart';

class ScheduleDateTimeChoice {
  const ScheduleDateTimeChoice({required this.date, required this.time});

  final DateTime date;
  final TimeOfDay time;

  DateTime get dateTime =>
      DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

DateTime initialRecommendedScheduleDate({
  DateTime? sourceDate,
  DateTime? currentDateTime,
}) {
  final today = DateUtils.dateOnly(currentDateTime ?? DateTime.now());
  if (sourceDate == null) return today;
  final sourceDay = DateUtils.dateOnly(sourceDate);
  return sourceDay.isBefore(today) ? today : sourceDay;
}

TimeOfDay initialRecommendedScheduleTime({
  required DateTime selectedDate,
  TimeOfDay? sourceTime,
  DateTime? currentDateTime,
}) {
  final now = currentDateTime ?? DateTime.now();
  final currentTime = TimeOfDay.fromDateTime(now);
  if (!DateUtils.isSameDay(selectedDate, now) || sourceTime == null) {
    return sourceTime ?? currentTime;
  }
  final sourceMinutes = sourceTime.hour * 60 + sourceTime.minute;
  final currentMinutes = currentTime.hour * 60 + currentTime.minute;
  return sourceMinutes > currentMinutes ? sourceTime : currentTime;
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
        scrollable: true,
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
              _SchedulePickerRow(
                icon: Icons.calendar_today_outlined,
                label: loc.recordDate,
                value: DateFormat.yMMMd(loc.localeName).format(selectedDate),
                onPressed: () async {
                  final value = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(1900),
                    lastDate: DateTime(2200),
                  );
                  if (value != null) setState(() => selectedDate = value);
                },
              ),
              _SchedulePickerRow(
                icon: Icons.schedule_outlined,
                label: loc.recordTime,
                value: selectedTime.format(context),
                onPressed: () async {
                  final value = await showTimePicker(
                    context: context,
                    initialTime: selectedTime,
                  );
                  if (value != null) setState(() => selectedTime = value);
                },
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
              ScheduleDateTimeChoice(date: selectedDate, time: selectedTime),
            ),
            child: Text(loc.confirm),
          ),
        ],
      ),
    ),
  );
}

class _SchedulePickerRow extends StatelessWidget {
  const _SchedulePickerRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon),
            Gaps.w16,
            Expanded(child: Text(label)),
          ],
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton(onPressed: onPressed, child: Text(value)),
        ),
      ],
    ),
  );
}
