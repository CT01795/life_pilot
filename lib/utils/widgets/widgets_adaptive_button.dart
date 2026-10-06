import 'package:flutter/material.dart';

/// A localized button label that remains on one line.
///
/// Buttons keep their natural width whenever possible. On an exceptionally
/// narrow surface the text scales down instead of wrapping or overflowing.
class AdaptiveButtonLabel extends StatelessWidget {
  const AdaptiveButtonLabel(
    this.text, {
    super.key,
    this.textAlign = TextAlign.center,
    this.style,
  });

  final String text;
  final TextAlign textAlign;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Text(
      text,
      maxLines: 1,
      softWrap: false,
      textAlign: textAlign,
      style: style,
    ),
  );
}

/// Keeps actions on one row when they fit and moves whole buttons to a new
/// line when a translated label needs more room.
class AdaptiveButtonBar extends StatelessWidget {
  const AdaptiveButtonBar({
    super.key,
    required this.children,
    this.alignment = MainAxisAlignment.start,
    this.overflowAlignment = OverflowBarAlignment.start,
    this.spacing = 8,
    this.overflowSpacing = 8,
  });

  final List<Widget> children;
  final MainAxisAlignment alignment;
  final OverflowBarAlignment overflowAlignment;
  final double spacing;
  final double overflowSpacing;

  @override
  Widget build(BuildContext context) => OverflowBar(
    alignment: alignment,
    overflowAlignment: overflowAlignment,
    spacing: spacing,
    overflowSpacing: overflowSpacing,
    children: children,
  );
}
