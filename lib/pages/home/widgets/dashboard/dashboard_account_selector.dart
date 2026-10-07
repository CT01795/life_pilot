import 'package:flutter/material.dart';
import 'package:life_pilot/l10n/app_localizations.dart';

class DashboardAccountOption {
  const DashboardAccountOption({
    required this.id,
    required this.name,
    required this.category,
  });

  final String id;
  final String name;
  final String category;
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
  });

  final IconData icon;
  final String? selectedAccountId;
  final String? selectedAccountName;
  final DashboardAccountLoader loadAccounts;
  final DashboardAccountChanged onChanged;
  final VoidCallback onOpenAccountPage;
  final String accountPageLabel;

  @override
  State<DashboardAccountSelector> createState() =>
      _DashboardAccountSelectorState();
}

class _DashboardAccountSelectorState extends State<DashboardAccountSelector> {
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
      final accounts = await widget.loadAccounts();
      if (!mounted) return;

      if (accounts.isEmpty) {
        await _showEmptyAccountDialog(loc);
        return;
      }

      final selection = await _showAccountDialog(loc, accounts);
      if (selection == null) return;

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
    List<DashboardAccountOption> accounts,
  ) => showDialog<_DashboardAccountSelection>(
    context: context,
    builder: (dialogContext) {
      final hasClearOption = widget.selectedAccountId != null;
      final itemCount = accounts.length + (hasClearOption ? 1 : 0);
      final maxContentHeight = MediaQuery.sizeOf(dialogContext).height * 0.6;
      final contentHeight = (itemCount * 72.0)
          .clamp(72.0, maxContentHeight)
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
                subtitle: Text(_categoryLabel(loc, account.category)),
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
  );

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
