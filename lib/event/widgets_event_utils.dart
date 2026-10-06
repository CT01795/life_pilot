import 'package:flutter/material.dart';

const double eventCardActionButtonSize = 52;
const double eventCardActionIconSize = 28;
const double eventCardActionSpacing = 8;

class EventCardActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;

  const EventCardActionButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.primary;
    return SizedBox.square(
      dimension: eventCardActionButtonSize,
      child: IconButton.filledTonal(
        iconSize: eventCardActionIconSize,
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          foregroundColor: effectiveColor,
          backgroundColor: effectiveColor.withValues(alpha: 0.12),
          disabledForegroundColor: effectiveColor.withValues(alpha: 0.38),
          disabledBackgroundColor: effectiveColor.withValues(alpha: 0.06),
        ),
        icon: Icon(icon),
      ),
    );
  }
}

class PressButton extends StatefulWidget {
  final bool? isPress;
  final Future<void> Function()? onPressed;
  final IconData pressedIcon;
  final IconData unPressedIcon;
  final String tooltip;
  final Color color;

  const PressButton({
    super.key,
    this.isPress,
    required this.color,
    required this.onPressed,
    required this.pressedIcon,
    required this.unPressedIcon,
    required this.tooltip,
  });

  @override
  State<PressButton> createState() => PressButtonState();
}

class PressButtonState extends State<PressButton> {
  bool? _isPress;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _isPress = widget.isPress;
  }

  @override
  void didUpdateWidget(covariant PressButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPress != widget.isPress) {
      _isPress = widget.isPress;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: eventCardActionButtonSize,
      child: IconButton.filledTonal(
        iconSize: eventCardActionIconSize,
        style: IconButton.styleFrom(
          foregroundColor: widget.color,
          backgroundColor: widget.color.withValues(alpha: 0.12),
          disabledForegroundColor: widget.color.withValues(alpha: 0.38),
          disabledBackgroundColor: widget.color.withValues(alpha: 0.06),
        ),
        icon: _isSubmitting
            ? SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: widget.color,
                ),
              )
            : Icon(
                _isPress == true ? widget.pressedIcon : widget.unPressedIcon,
                color: widget.color,
              ),
        tooltip: widget.tooltip,
        onPressed: widget.onPressed == null || _isSubmitting
            ? null
            : () async {
                setState(() => _isSubmitting = true);
                try {
                  await widget.onPressed!();
                } finally {
                  if (mounted) {
                    setState(() {
                      _isPress = widget.isPress;
                      _isSubmitting = false;
                    });
                  }
                }
              },
      ),
    );
  }
}
