import 'package:flutter/material.dart';
import 'package:life_pilot/accounting/service_ledger_sharing.dart';
import 'package:life_pilot/l10n/app_localizations.dart';

class DashboardAccountOption {
  const DashboardAccountOption({
    required this.id,
    required this.name,
    required this.category,
    this.sharedKind,
  });

  final String id;
  final String name;
  final String category;
  final LedgerKind? sharedKind;
}

class _DashboardAccountSelection {
  const _DashboardAccountSelection.account(this.account) : shouldClear = false;

  const _DashboardAccountSelection.clear() : account = null, shouldClear = true;

  final DashboardAccountOption? account;
  final bool shouldClear;
}

typedef DashboardAccountLoader =
    Future<List<DashboardAccountOption>> Function();
typedef DashboardAccountChanged =
    Future<void> Function(DashboardAccountOption? account);

/// Shared account picker used by the accounting and point dashboard cards.
///
/// Keeping loading, empty-state, clear-selection and error handling here avoids
/// the two selectors drifting apart when their UI is changed.
class DashboardAccountSelector extends StatefulWidget {
  const DashboardAccountSelector({
    super.key,
    required this.icon,
    required this.selectedAccountId,
    required this.selectedAccountName,
    required this.loadAccounts,
    required this.onChanged,
    required this.onOpenAccountPage,
    required this.accountPageLabel,
    this.sharedKind,
    this.onSharedChanged,
  });

  final IconData icon;
  final String? selectedAccountId;
  final String? selectedAccountName;
  final DashboardAccountLoader loadAccounts;
  final DashboardAccountChanged onChanged;
  final VoidCallback onOpenAccountPage;
  final String accountPageLabel;
  final LedgerKind? sharedKind;
  final Future<void> Function(DashboardAccountOption)? onSharedChanged;

  @override
  State<DashboardAccountSelector> createState() =>
      _DashboardAccountSelectorState();
}

class _DashboardAccountSelectorState extends State<DashboardAccountSelector> {
  static const _sharedPageSize = 12;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Tooltip(
      message: loc.selectAccount,
      child: ActionChip(
        avatar: _isLoading
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(widget.icon),
        label: SizedBox(
          width: double.infinity,
          child: Text(
            widget.selectedAccountName ?? loc.selectAccount,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.left,
          ),
        ),
        onPressed: _isLoading ? null : () => _selectAccount(loc),
      ),
    );
  }

  Future<void> _selectAccount(AppLocalizations loc) async {
    setState(() => _isLoading = true);
    try {
      final shared = _loadSharedAccounts();
      final accounts = [...await widget.loadAccounts(), ...await shared];
      if (!mounted) return;

      if (accounts.isEmpty) {
        await _showEmptyAccountDialog(loc);
        return;
      }

      final selection = await _showAccountDialog(
        loc,
        accounts,
        sharedCount: accounts.where((a) => a.sharedKind != null).length,
      );
      if (!mounted || selection == null) return;

      final option = selection.account;
      final kind = option?.sharedKind;
      if (option != null && kind != null) {
        try {
          await widget.onSharedChanged?.call(option);
        } catch (_) {
          if (mounted) _showMessage(loc.dashboardSettingSaveFailed);
        }
        return;
      }

      try {
        await widget.onChanged(
          selection.shouldClear ? null : selection.account,
        );
      } catch (_) {
        if (mounted) {
          _showMessage(loc.dashboardSettingSaveFailed);
        }
      }
    } catch (_) {
      if (mounted) {
        _showMessage(loc.accountListLoadFailed);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<List<DashboardAccountOption>> _loadSharedAccounts([
    int offset = 0,
  ]) async {
    final kind = widget.sharedKind;
    if (kind == null) return const [];
    try {
      return (await ServiceLedgerSharing().receivedKindPage(
            kind,
            offset,
            limit: _sharedPageSize,
          ))
          .map(
            (row) => DashboardAccountOption(
              id: row['share_id'] as String,
              name: row['account_name'] as String? ?? '',
              category: '',
              sharedKind: kind,
            ),
          )
          .toList(growable: false);
    } catch (_) {
      if (offset != 0) rethrow;
      // Local/owned account selection remains available if cloud reads fail.
      return const [];
    }
  }

  Future<void> _showEmptyAccountDialog(AppLocalizations loc) =>
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          content: Text(loc.accountListEmpty),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(loc.cancel),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                widget.onOpenAccountPage();
              },
              child: Text(widget.accountPageLabel),
            ),
          ],
        ),
      );

  Future<_DashboardAccountSelection?> _showAccountDialog(
    AppLocalizations loc,
    List<DashboardAccountOption> accounts, {
    required int sharedCount,
  }) {
    var offset = sharedCount;
    var hasMore = sharedCount == _sharedPageSize;
    var loadingMore = false;
    return showDialog<_DashboardAccountSelection>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, update) {
          final hasClearOption = widget.selectedAccountId != null;
          final accountCount = accounts.length + (hasClearOption ? 1 : 0);
          final itemCount = accountCount + (hasMore ? 1 : 0);
          final maxContentHeight =
              MediaQuery.sizeOf(dialogContext).height * 0.6;
          final contentHeight = (itemCount * 72.0)
              .clamp(0.0, maxContentHeight)
              .toDouble();

          return AlertDialog(
            title: Text(loc.selectAccount),
            contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            content: SizedBox(
              width: MediaQuery.sizeOf(
                dialogContext,
              ).width.clamp(0, 420).toDouble(),
              height: contentHeight,
              child: ListView.separated(
                itemCount: itemCount,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, index) {
                  if (index == accountCount) {
                    return TextButton(
                      onPressed: loadingMore
                          ? null
                          : () async {
                              update(() => loadingMore = true);
                              try {
                                final page = await _loadSharedAccounts(offset);
                                if (!dialogContext.mounted) return;
                                update(() {
                                  accounts.addAll(page);
                                  offset += page.length;
                                  hasMore = page.length == _sharedPageSize;
                                });
                              } catch (_) {
                                if (mounted && dialogContext.mounted) {
                                  _showMessage(loc.accountListLoadFailed);
                                }
                              } finally {
                                if (dialogContext.mounted) {
                                  update(() => loadingMore = false);
                                }
                              }
                            },
                      child: Text(loc.clickHereToSeeMore),
                    );
                  }
                  if (hasClearOption && index == 0) {
                    return ListTile(
                      leading: const Icon(Icons.clear),
                      title: Text(loc.clear),
                      onTap: () => Navigator.pop(
                        dialogContext,
                        const _DashboardAccountSelection.clear(),
                      ),
                    );
                  }

                  final accountIndex = index - (hasClearOption ? 1 : 0);
                  final account = accounts[accountIndex];
                  return ListTile(
                    title: Text(account.name),
                    subtitle: Text(
                      account.sharedKind == null
                          ? _categoryLabel(loc, account.category)
                          : loc.ledgerSharedAccount,
                    ),
                    onTap: () => Navigator.pop(
                      dialogContext,
                      _DashboardAccountSelection.account(account),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  String _categoryLabel(AppLocalizations loc, String category) =>
      switch (category) {
        'project' => loc.accountProject,
        'master' => loc.accountMaster,
        _ => loc.accountPersonal,
      };

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
