import 'package:flutter/material.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:life_pilot/subscription/service_subscription.dart';
import 'package:life_pilot/utils/app_navigator.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:provider/provider.dart';

class SubscriptionDataCleanup extends StatefulWidget {
  const SubscriptionDataCleanup({super.key});

  @override
  State<SubscriptionDataCleanup> createState() =>
      _SubscriptionDataCleanupState();
}

class _SubscriptionDataCleanupState extends State<SubscriptionDataCleanup> {
  final _email = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    final auth = context.read<ControllerAuth>();
    final loc = AppLocalizations.of(context)!;
    final isLocal = auth.preferredStorage == DataStorageLocation.local;
    final target = auth.isSysAdmin && _email.text.trim().isNotEmpty
        ? _email.text.trim()
        : null;
    setState(() => _busy = true);
    try {
      final preview = isLocal
          ? const <SubscriptionCleanupPreview>[]
          : await ServiceSubscription().fetchCleanupPreview(email: target);
      if (!mounted) return;
      final overages = preview.where((row) => row.excess > 0).toList();
      final mode = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(loc.dataCleanupTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isLocal
                    ? loc.dataCleanupLocalExplanation
                    : loc.dataCleanupCloudExplanation),
                if (!isLocal && overages.isEmpty) ...[
                  Gaps.h12,
                  Text(loc.dataCleanupNoOverage),
                ],
                for (final row in overages) ...[
                  Gaps.h8,
                  Text(loc.subscriptionOverageItem(
                    _resourceName(loc, row.resource),
                    row.used,
                    row.quota,
                    row.excess,
                  )),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(loc.cancel),
            ),
            if (!isLocal && overages.isNotEmpty)
              OutlinedButton(
                onPressed: () => Navigator.pop(dialogContext, 'excess'),
                child: Text(loc.dataCleanupExcess),
              ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, 'all'),
              child: Text(loc.dataCleanupAll),
            ),
          ],
        ),
      );
      if (mode == null || !mounted) return;
      final confirmed = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Text(loc.dataCleanupConfirmTitle),
              content: Text(mode == 'excess'
                  ? loc.dataCleanupExcessConfirm
                  : loc.dataCleanupAllConfirm),
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
      if (!confirmed || !mounted) return;
      if (isLocal) {
        await LocalDataStore.instance.deleteAllRecords(
          owner: auth.currentAccount!,
        );
      } else {
        await ServiceSubscription().cleanupData(email: target, mode: mode);
      }
      if (!mounted) return;
      await auth.refreshSubscriptionUsage(notify: false);
      AppNavigator.showSnackBar(loc.dataCleanupSuccess);
    } catch (error) {
      if (mounted) {
        AppNavigator.showErrorBar('${loc.dataCleanupFailed}\n$error');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<ControllerAuth>();
    final loc = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(loc.dataCleanupTitle,
                style: Theme.of(context).textTheme.titleMedium),
            if (auth.isSysAdmin &&
                auth.preferredStorage == DataStorageLocation.cloud) ...[
              Gaps.h12,
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: loc.dataCleanupTargetEmail,
                  prefixIcon: const Icon(Icons.person_search_outlined),
                ),
              ),
            ],
            Gaps.h12,
            OutlinedButton.icon(
              onPressed: _busy ? null : _open,
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cleaning_services_outlined),
              label: Text(loc.dataCleanupAction),
            ),
          ],
        ),
      ),
    );
  }
}

String _resourceName(AppLocalizations loc, String value) => switch (value) {
      'calendar_events' => loc.personalEvent,
      'accounting_detail' => loc.accountRecords,
      'point_record_detail' => loc.pointsRecord,
      'memory_trace' => loc.memoryTrace,
      'game_questions' => loc.game,
      'calendar_shares' => loc.calendarSharing,
      _ => value,
    };
