import 'package:flutter/material.dart';
import 'package:life_pilot/l10n/app_localizations.dart';

/// An empty filtered list has no pagination controls or end-of-list notice.
class WidgetsEventEmptyState extends StatelessWidget {
  const WidgetsEventEmptyState({
    super.key,
    required this.message,
    this.onClear,
  });
  final String message;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.search_off_rounded,
            size: 48,
            color: Color(0xFF829097),
          ),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          if (onClear != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.filter_alt_off_rounded),
              label: Text(AppLocalizations.of(context)!.clear),
            ),
          ],
        ],
      ),
    ),
  );
}
