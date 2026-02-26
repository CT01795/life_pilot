import 'package:flutter/material.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/extension.dart';

Widget widgetsDateButton({
  required BuildContext context,
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
              : date.formatDateString( passYear: true, formatShow: true )),
          onPressed: () async {
            DateTime? picked = await showDatePicker(
              context: context,
              initialDate: date ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            onDateChanged(picked);
          },
        ),
      ),
      if (date != null)
        IconButton(
          icon: const Icon(Icons.clear),
          tooltip: loc.dateClear,
          onPressed: () => onDateChanged(null),
        ),
    ],
  );
}


