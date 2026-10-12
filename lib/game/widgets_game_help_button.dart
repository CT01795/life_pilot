import 'package:flutter/material.dart';
import 'package:life_pilot/l10n/app_localizations.dart';

class GameHelpButton extends StatelessWidget {
  const GameHelpButton({super.key, this.description});

  final String? description;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: loc.gameInstructions,
      icon: const Icon(Icons.help_outline),
      onPressed: () => showDialog<void>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.38),
        builder: (dialogContext) => AlertDialog(
          backgroundColor: colorScheme.surface,
          surfaceTintColor: colorScheme.surface,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            //side: BorderSide(color: colorScheme.primary, width: 2),
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.help_outline, color: colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  loc.gameInstructions,
                  style: TextStyle(color: colorScheme.onSurface),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                description ?? loc.gameInstructionsGeneral,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
            ),
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
