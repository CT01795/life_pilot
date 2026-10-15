import 'package:flutter/material.dart';
import 'package:life_pilot/game/social/model_game_social.dart';
import 'package:life_pilot/game/widgets_game_help_button.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/const.dart';

/// Renders semantic answer feedback; colors and icons never enter Controller.
class WidgetsSocialOption extends StatelessWidget {
  const WidgetsSocialOption({
    super.key,
    required this.option,
    required this.feedback,
    required this.selected,
    required this.canAnswer,
    required this.onAnswer,
    required this.onSpeak,
    this.fontSize = 32,
  });

  final String option;
  final SocialOptionFeedback feedback;
  final bool selected;
  final bool canAnswer;
  final VoidCallback onAnswer;
  final VoidCallback onSpeak;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final (background, border, iconColor, icon) = switch (feedback) {
      SocialOptionFeedback.neutral => (
        const Color(0xFFE3F2FD),
        const Color(0xFF1976D2),
        const Color(0xFF1976D2),
        null,
      ),
      SocialOptionFeedback.correct => (
        const Color(0xFFC8E6C9),
        const Color(0xFF388E3C),
        const Color(0xFF2E7D32),
        Icons.check_rounded,
      ),
      SocialOptionFeedback.incorrect => (
        const Color(0xFFFFCDD2),
        const Color(0xFFD32F2F),
        const Color(0xFFD32F2F),
        Icons.clear_rounded,
      ),
    };
    return Padding(
      padding: Insets.all8,
      child: SizedBox(
        width: double.infinity,
        child: GameSpeechTooltip(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: background),
            onPressed: onSpeak,
            child: Row(
              children: [
                Tooltip(
                  message: loc.checkOption,
                  child: GestureDetector(
                    onTap: canAnswer ? onAnswer : null,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: border),
                      ),
                      child: Center(
                        child: selected
                            ? Icon(Icons.check, color: border, size: 48)
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
                Gaps.w24,
                Expanded(
                  child: Text(
                    option,
                    style: TextStyle(
                      fontSize: fontSize,
                      color: const Color(0xFF212121),
                    ),
                    softWrap: true,
                    textAlign: TextAlign.start,
                  ),
                ),
                Gaps.w8,
                if (icon != null) Icon(icon, color: iconColor, size: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
