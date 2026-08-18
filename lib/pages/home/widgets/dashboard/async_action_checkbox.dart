import 'package:flutter/material.dart';

class AsyncActionCheckbox extends StatefulWidget {
  const AsyncActionCheckbox({
    required this.onAccepted,
    super.key,
  });

  final Future<void> Function() onAccepted;

  @override
  State<AsyncActionCheckbox> createState() => _AsyncActionCheckboxState();
}

class _AsyncActionCheckboxState extends State<AsyncActionCheckbox> {
  bool _isRunning = false;

  Future<void> _handleChanged(bool? value) async {
    if (value != true || _isRunning) return;

    setState(() => _isRunning = true);
    try {
      await widget.onAccepted();
    } finally {
      if (mounted) setState(() => _isRunning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Checkbox(
      value: false,
      onChanged: _isRunning ? null : _handleChanged,
    );
  }
}
