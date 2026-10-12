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

/// Gives text/audio game controls one consistent hint. Hovering never starts
/// playback; audio is played only after the user presses the control.
class GameSpeechTooltip extends StatelessWidget {
  const GameSpeechTooltip({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Tooltip(
      message: loc.pressToPlayAudio,
      child: MouseRegion(cursor: SystemMouseCursors.click, child: child),
    );
  }
}
