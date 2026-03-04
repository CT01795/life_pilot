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

  @override
  void initState() {
    super.initState();
    _isPress = widget.isPress;
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        _isPress == true ? widget.pressedIcon : widget.unPressedIcon,
        color: widget.color,
      ),
      tooltip: widget.tooltip,
      onPressed: () async {
        if (widget.onPressed != null) await widget.onPressed!();
        setState(() {
          _isPress = !(_isPress ?? false);
        });
      },
    );
  }
}
