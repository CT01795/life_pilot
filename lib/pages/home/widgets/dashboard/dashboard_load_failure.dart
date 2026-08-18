import 'package:flutter/material.dart';
import 'package:life_pilot/l10n/app_localizations.dart';

class DashboardLoadFailure extends StatelessWidget {
  const DashboardLoadFailure({
    required this.onRetry,
    super.key,
  });

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return ListTile(
      leading: const Icon(Icons.error_outline),
      title: Text(loc.dashboardLoadFailed),
      trailing: TextButton(
        onPressed: () => onRetry(),
        child: Text(loc.retry),
      ),
    );
  }
}
