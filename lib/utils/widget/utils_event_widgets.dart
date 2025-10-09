import 'package:flutter/material.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/my_app.dart';
import 'package:life_pilot/utils/core/utils_const.dart';

Widget widgetBuildDateButton({
  required DateTime? date,
  required String label,
  required IconData icon,
  required void Function(DateTime?) onDateChanged,
  required AppLocalizations loc,
}) {
  return Row(
    children: [
      Expanded(
        child: ElevatedButton.icon(
          icon: Icon(icon),
          label: Text(date == null
              ? label
              : "${date.month.toString().padLeft(2, constZero)}/${date.day.toString().padLeft(2, constZero)}"),
          onPressed: () async {
            DateTime? picked = await showDatePicker(
              context: navigatorKey.currentState!.context,
              initialDate: date ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (picked != null) {
              onDateChanged(picked);
            }
          },
        ),
      ),
      if (date != null)
        IconButton(
          icon: const Icon(Icons.clear),
          tooltip: loc.date_clear,
          onPressed: () => onDateChanged(null),
        ),
    ],
  );
}


