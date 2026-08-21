import 'package:flutter/material.dart';
import 'package:life_pilot/l10n/app_localizations.dart';

class GameExitGuard extends StatefulWidget {
  const GameExitGuard({super.key, required this.child});

  final Widget child;

  @override
  State<GameExitGuard> createState() => _GameExitGuardState();
}

class _GameExitGuardState extends State<GameExitGuard> {
  bool _canPop = false;
  bool _isConfirming = false;

  Future<void> _handlePop(bool didPop, Object? result) async {
    if (didPop || _isConfirming) return;

    // A true result is used by the games when a round completes normally.
    if (result == true) {
      _pop(result);
      return;
    }

    _isConfirming = true;
    final loc = AppLocalizations.of(context)!;
    final shouldLeave = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            content: Text(loc.leaveGameConfirmation),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(loc.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(loc.confirm),
              ),
            ],
          ),
        ) ??
        false;
    _isConfirming = false;

    if (mounted && shouldLeave) {
      _pop(true);
    }
  }

  void _pop(Object? result) {
    if (!mounted) return;
    setState(() => _canPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context, result);
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: _canPop,
      onPopInvokedWithResult: _handlePop,
      child: widget.child,
    );
  }
}
