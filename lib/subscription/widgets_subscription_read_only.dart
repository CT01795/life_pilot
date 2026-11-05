import 'package:flutter/material.dart';
import 'package:life_pilot/l10n/app_localizations.dart';

/// Keeps the read-only notice visible without pushing a small viewport's
/// contents outside the screen. Long translations can scroll independently.
class SubscriptionReadOnlyNotice extends StatelessWidget {
  const SubscriptionReadOnlyNotice({
    super.key,
    required this.message,
    required this.child,
    this.onRetry,
  });
  final String message;
  final Widget child;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      return Column(
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: constraints.maxHeight * .3),
            child: SingleChildScrollView(
              child: SafeArea(
                bottom: false,
                child: Material(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(message),
                        if (onRetry != null)
                          TextButton(
                            onPressed: onRetry,
                            child: Text(AppLocalizations.of(context)!.retry),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(child: child),
        ],
      );
    },
  );
}
