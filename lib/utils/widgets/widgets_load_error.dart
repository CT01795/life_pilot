import 'package:flutter/material.dart';
import 'package:life_pilot/l10n/app_localizations.dart';

/// A retryable failure, kept separate from successful empty results.
class WidgetsLoadError extends StatelessWidget {
  const WidgetsLoadError({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(loc.dashboardLoadFailed),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(loc.retry),
          ),
        ],
      ),
    );
  }
}
