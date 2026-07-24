import 'package:flutter/material.dart';

class LogoutButton extends StatelessWidget {

  final VoidCallback? onLogout;
  final String tooltip;

  const LogoutButton({
    super.key,
    required this.onLogout,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.exit_to_app),
      tooltip: tooltip,
      color: Colors.white,
      onPressed: onLogout,
    );
  }
}