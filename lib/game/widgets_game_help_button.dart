import 'package:flutter/material.dart';
import 'package:life_pilot/l10n/app_localizations.dart';

class GameHelpButton extends StatelessWidget {
  const GameHelpButton({super.key, this.description});

  final String? description;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return IconButton(
      tooltip: loc.gameInstructions,
      icon: const Icon(Icons.help_outline),
      onPressed: () => showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(loc.gameInstructions),
          content: SingleChildScrollView(
            child: Text(description ?? loc.gameInstructionsGeneral),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(loc.close),
            ),
          ],
        ),
      ),
    );
  }
}
