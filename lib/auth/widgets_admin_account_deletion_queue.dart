import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/auth/controller_account_deletion_queue.dart';
import 'package:life_pilot/auth/model_account_deletion_page.dart';
import 'package:life_pilot/auth/repository_account_deletion.dart';
import 'package:life_pilot/l10n/app_localizations.dart';

class AdminAccountDeletionQueue extends StatefulWidget {
  const AdminAccountDeletionQueue({super.key, this.repository});
  final RepositoryAccountDeletion? repository;
  @override
  State<AdminAccountDeletionQueue> createState() =>
      _AdminAccountDeletionQueueState();
}

class _AdminAccountDeletionQueueState extends State<AdminAccountDeletionQueue> {
  late final ControllerAccountDeletionQueue _controller;
  @override
  void initState() {
    super.initState();
    final repo = widget.repository ?? RepositoryAccountDeletion();
    _controller = ControllerAccountDeletionQueue(
      auth: context.read<ControllerAuth>(),
      load: repo.adminPage,
      approve: repo.approve,
      confirmCancellation: repo.confirmCancellation,
    );
    // No query merely for entering Account Security; load only on expansion.
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _process(AccountDeletionRequest row) async {
    final auth = context.read<ControllerAuth>();
    final owner = auth.currentAccount;
    final result = await _controller.process(row);
    if (!mounted ||
        result == null ||
        auth.currentAccount != owner ||
        !auth.isSysAdmin) {
      return;
    }
    final loc = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result
              ? row.isCancellation
                    ? loc.adminAccountDeletionCancellationConfirmed
                    : loc.adminAccountDeletionCompleted
              : loc.accountDeletionFailed(_controller.actionError.toString()),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final c = _controller;
        return Card(
          child: ExpansionTile(
            leading: const Icon(Icons.person_remove_outlined),
            title: Text(loc.accountMenuAccountDeletion),
            subtitle: Text(loc.adminSubscriptionTitle),
            onExpansionChanged: (open) {
              if (open) unawaited(c.load());
            },
            children: [
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: IconButton(
                  tooltip: loc.refreshList,
                  onPressed: c.loading || c.working ? null : () => c.load(),
                  icon: const Icon(Icons.refresh),
                ),
              ),
              for (final row in c.rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ListTile(
                        title: Text(row.email),
                        subtitle: Text(
                          row.isCancellation
                              ? loc.adminAccountDeletionCancellationRequested
                              : row.requestedAt ?? '',
                        ),
                      ),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: FilledButton(
                          onPressed: c.loading || c.working
                              ? null
                              : () => _process(row),
                          child: Text(
                            row.isCancellation
                                ? loc.adminAccountDeletionConfirmCancellation
                                : loc.continueLabel,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (c.loading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                )
              else if (c.loadError != null)
                Column(
                  children: [
                    Text(loc.dashboardLoadFailed),
                    TextButton.icon(
                      onPressed: () => c.load(more: c.retryMore),
                      icon: const Icon(Icons.refresh),
                      label: Text(loc.retry),
                    ),
                  ],
                )
              else if (c.hasMore)
                TextButton(
                  onPressed: c.working ? null : () => c.load(more: true),
                  child: Text(loc.clickHereToSeeMore),
                )
              else if (c.rows.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(loc.noData),
                ),
            ],
          ),
        );
      },
    );
  }
}
