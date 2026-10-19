import 'package:flutter/material.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/event/page_content_performance.dart';
import 'package:life_pilot/event/service_content_performance.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

/// Shared entry point for personal submissions and the vendor workspace.
class ContentPerformanceLink extends StatelessWidget {
  final bool attractions;
  final ServiceContentPerformance? service;
  const ContentPerformanceLink({
    super.key,
    required this.attractions,
    this.service,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final account = context.select<ControllerAuth, String?>(
      (auth) => auth.currentAccount,
    );
    return Tooltip(
      message: loc.viewPerformance,
      child: TextButton.icon(
        icon: const Icon(Icons.insights),
        label: Text(
          attractions ? loc.attractionPerformance : loc.activityPerformance,
        ),
        onPressed: account == null || account.isEmpty
            ? null
            : () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PageContentPerformance(
                    attractions: attractions,
                    service: service,
                  ),
                ),
              ),
      ),
    );
  }
}
