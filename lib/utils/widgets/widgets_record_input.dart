import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/record_date_time.dart';

class WidgetsRecordDateTimePicker extends StatelessWidget {
  const WidgetsRecordDateTimePicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text(
              '${loc.recordDate}: ${DateFormat.yMd(locale).format(value)}',
            ),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: value,
                firstDate: DateTime(2000),
                lastDate: DateTime.now().add(const Duration(days: 3650)),
              );
              if (picked == null || !context.mounted) return;
              onChanged(replaceRecordDate(value, picked));
            },
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.access_time),
            label: Text(
              '${loc.recordTime}: ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(value))}',
            ),
            onPressed: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(value),
              );
              if (picked == null || !context.mounted) return;
              onChanged(replaceRecordTime(value, picked));
            },
          ),
        ],
      ),
    );
  }
}
