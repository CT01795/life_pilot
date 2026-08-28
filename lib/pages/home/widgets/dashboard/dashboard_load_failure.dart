import 'package:flutter/material.dart';
import 'package:life_pilot/l10n/app_localizations.dart';

class DashboardLoadFailure extends StatefulWidget {
  const DashboardLoadFailure({
    required this.onRetry,
    super.key,
  });

  final Future<void> Function() onRetry;

  @override
  State<DashboardLoadFailure> createState() => _DashboardLoadFailureState();
}

class _DashboardLoadFailureState extends State<DashboardLoadFailure> {
  bool _retrying = false;

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    try {
      await widget.onRetry();
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return ListTile(
      leading: const Icon(Icons.error_outline),
      title: Text(loc.dashboardLoadFailed),
      trailing: _retrying
          ? const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : TextButton(
              onPressed: _retry,
              child: Text(loc.retry),
            ),
    );
  }
}
