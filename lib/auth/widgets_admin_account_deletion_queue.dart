import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/auth/controller_account_deletion_queue.dart';
import 'package:life_pilot/auth/model_account_deletion_page.dart';
import 'package:life_pilot/auth/repository_account_deletion.dart';
import 'package:life_pilot/l10n/app_localizations.dart';

class AdminAccountDeletionQueue extends StatefulWidget {
  const AdminAccountDeletionQueue({
    super.key,
    this.repository,
    this.disabled = false,
  });
  final RepositoryAccountDeletion? repository;
  final bool disabled;
  @override
  State<AdminAccountDeletionQueue> createState() =>
      _AdminAccountDeletionQueueState();
}

class _AdminAccountDeletionQueueState extends State<AdminAccountDeletionQueue> {
  late final ControllerAccountDeletionQueue _controller;
  late final RepositoryAccountDeletion _repository;
  @override
  void initState() {
    super.initState();
    final repo = _repository = widget.repository ?? RepositoryAccountDeletion();
    _controller = ControllerAccountDeletionQueue(
      auth: context.read<ControllerAuth>(),
      load: ({after, required offset}) => widget.disabled
          ? repo.disabledPage(offset: offset)
          : repo.adminPage(after: after),
      approve: widget.disabled ? repo.deleteDisabled : repo.approve,
      confirmCancellation: repo.confirmCancellation,
    );
    // No query merely for entering Account Security; load only on expansion.
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _process(
    AccountDeletionRequest row, {
    bool disable = false,
    bool reactivate = false,
  }) async {
    final auth = context.read<ControllerAuth>();
    final owner = auth.currentAccount;
    final loc = AppLocalizations.of(context)!;
    final label = reactivate
        ? loc.adminReactivateAccount
        : disable
        ? loc.adminDisableAccount
        : loc.confirmDelete;
    if (!row.isCancellation) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text(label),
          content: Text(row.email),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: Text(loc.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: Text(loc.confirm),
            ),
          ],
        ),
      );
      if (!mounted ||
          confirmed != true ||
          auth.currentAccount != owner ||
          !auth.isSysAdmin) {
        return;
      }
    }
    final result = await _controller.process(
      row,
      insteadOfApprove: reactivate
          ? _repository.reactivate
          : disable
          ? _repository.disable
          : null,
    );
    if (!mounted ||
        result == null ||
        auth.currentAccount != owner ||
        !auth.isSysAdmin) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result
              ? row.isCancellation
                    ? loc.adminAccountDeletionCancellationConfirmed
                    : reactivate
                    ? loc.adminAccountReactivated
                    : disable
                    ? loc.accountDisabled
                    : loc.adminAccountDeletionCompleted
              : _purgeErrorMessage(loc),
        ),
      ),
    );
  }

  String _purgeErrorMessage(AppLocalizations loc) {
    final error = _controller.actionError.toString();
    if (error.contains('account_reactivation_purge_started')) {
      return loc.adminAccountReactivationPurgeStarted;
    }
    if (error.contains('account_storage_purge_more_files')) {
      return loc.accountPurgeMoreFiles;
    }
    if (error.contains('account_storage_purge_in_progress')) {
      return loc.accountPurgeInProgress;
    }
    return loc.accountDeletionFailed(error);
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
            title: Text(
              widget.disabled
                  ? loc.adminDisabledAccounts
                  : loc.accountMenuAccountDeletion,
            ),
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
                        child: Wrap(
                          spacing: 8,
                          children: [
                            if (widget.disabled)
                              OutlinedButton(
                                onPressed: c.loading || c.working
                                    ? null
                                    : () => _process(row, reactivate: true),
                                child: Text(loc.adminReactivateAccount),
                              ),
                            if (!widget.disabled && !row.isCancellation)
                              OutlinedButton(
                                onPressed: c.loading || c.working
                                    ? null
                                    : () => _process(row, disable: true),
                                child: Text(loc.adminDisableAccount),
                              ),
                            FilledButton(
                              onPressed: c.loading || c.working
                                  ? null
                                  : () => _process(row),
                              child: Text(
                                row.isCancellation
                                    ? loc.adminAccountDeletionConfirmCancellation
                                    : loc.delete,
                              ),
                            ),
                          ],
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
