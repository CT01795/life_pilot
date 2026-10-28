import 'dart:async';
import 'package:flutter/material.dart';
import 'package:life_pilot/l10n/app_localizations.dart';

class WidgetsStockSectionFailure extends StatelessWidget {
  const WidgetsStockSectionFailure({
    super.key,
    required this.error,
    required this.onRetry,
  });
  final Object error;
  final Future<void> Function() onRetry;
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          error is TimeoutException
              ? loc.stockReadTimeout
              : loc.stockLoadFailed,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: Text(loc.retry),
        ),
      ],
    );
  }
}
