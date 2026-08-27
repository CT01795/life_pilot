import 'package:flutter/material.dart';

class PressButton extends StatefulWidget {
  final bool? isPress;
  final Future<void> Function()? onPressed;
  final IconData pressedIcon;
  final IconData unPressedIcon;
  final String tooltip;
  final Color color;

  const PressButton(
      {super.key,
      this.isPress,
      required this.color,
      required this.onPressed,
      required this.pressedIcon,
      required this.unPressedIcon,
      required this.tooltip});

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
    return IconButton(
      icon: _isSubmitting
          ? SizedBox.square(
              dimension: 20,
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
    );
  }
}
