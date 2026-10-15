import 'package:flutter/material.dart';
import 'package:life_pilot/l10n/app_localizations.dart';

/// The dialog owns its input through the entire route animation.
class WidgetsAccountNameDialog extends StatefulWidget {
  const WidgetsAccountNameDialog({super.key});

  @override
  State<WidgetsAccountNameDialog> createState() =>
      _WidgetsAccountNameDialogState();
}

class _WidgetsAccountNameDialogState extends State<WidgetsAccountNameDialog> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return AlertDialog(
      content: TextField(
        controller: _name,
        autofocus: true,
        decoration: InputDecoration(hintText: loc.accountName),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(loc.cancel),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _name,
          builder: (_, value, _) => ElevatedButton(
            onPressed: value.text.trim().isEmpty
                ? null
                : () => Navigator.pop(context, value.text.trim()),
            child: Text(loc.accountCreate),
          ),
        ),
      ],
    );
  }
}
