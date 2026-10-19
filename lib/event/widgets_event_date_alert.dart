import 'package:flutter/material.dart';
import 'package:life_pilot/l10n/app_localizations.dart';

Future<void> showEventDateAlert(BuildContext context) async {
  if (!context.mounted) return;
  final loc = AppLocalizations.of(context)!;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      content: Text(loc.invalidEventDateRange),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(loc.confirm),
        ),
      ],
    ),
  );
}
