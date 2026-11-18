import 'dart:async';

import 'package:life_pilot/utils/widgets/widgets_load_more.dart';
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

class DashboardAccountOptionPage {
  const DashboardAccountOptionPage({
    required this.rows,
    required this.nextCursor,
  });

  final List<DashboardAccountOption> rows;
  final Map<String, dynamic>? nextCursor;
}

class _DashboardAccountSelection {
  const _DashboardAccountSelection.account(this.account) : shouldClear = false;

  const _DashboardAccountSelection.clear() : account = null, shouldClear = true;

  final DashboardAccountOption? account;
  final bool shouldClear;
}

typedef DashboardAccountLoader =
    Future<DashboardAccountOptionPage> Function({
      required String search,
      Map<String, dynamic>? cursor,
      String? selectedId,
    });
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
    this.onSharedChanged,
  });

  final IconData icon;
  final String? selectedAccountId;
  final String? selectedAccountName;
  final DashboardAccountLoader loadAccounts;
  final DashboardAccountChanged onChanged;
  final VoidCallback onOpenAccountPage;
  final String accountPageLabel;
  final Future<void> Function(DashboardAccountOption)? onSharedChanged;

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
      final firstPage = await widget.loadAccounts(
        search: '',
        selectedId: widget.selectedAccountId,
      );
      final accounts = firstPage.rows.toList(growable: true);
      if (!mounted) return;

      if (accounts.isEmpty) {
        await _showEmptyAccountDialog(loc);
        return;
      }

      final selection = await _showAccountDialog(
        loc,
        accounts,
        initialCursor: firstPage.nextCursor,
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
    required Map<String, dynamic>? initialCursor,
  }) async {
    var cursor = initialCursor;
    var loadingMore = false;
    var search = '';
    var searchRevision = 0;
    Timer? debounce;
    final searchController = TextEditingController();
    final result = await showDialog<_DashboardAccountSelection>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, update) {
          final hasClearOption = widget.selectedAccountId != null;
          final accountCount = accounts.length + (hasClearOption ? 1 : 0);
          final itemCount = accountCount + 1;
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
              child: Column(
                children: [
                  TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: loc.search,
                    ),
                    onChanged: (value) {
                      debounce?.cancel();
                      final revision = ++searchRevision;
                      debounce = Timer(
                        const Duration(milliseconds: 300),
                        () async {
                          search = value.trim();
                          update(() => loadingMore = true);
                          try {
                            final page = await widget.loadAccounts(
                              search: search,
                              selectedId: widget.selectedAccountId,
                            );
                            if (!dialogContext.mounted ||
                                revision != searchRevision) {
                              return;
                            }
                            update(() {
                              accounts
                                ..clear()
                                ..addAll(page.rows);
                              cursor = page.nextCursor;
                            });
                          } catch (_) {
                            if (dialogContext.mounted) {
                              _showMessage(loc.accountListLoadFailed);
                            }
                          } finally {
                            if (dialogContext.mounted &&
                                revision == searchRevision) {
                              update(() => loadingMore = false);
                            }
                          }
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      itemCount: itemCount,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, index) {
                        if (index == accountCount) {
                          return WidgetsLoadMore(
                            hasMore: cursor != null,
                            loading: loadingMore,
                            count: accounts.length,
                            scope: widget.selectedAccountId,
                            onLoadMore: () async {
                              update(() => loadingMore = true);
                              try {
                                final page = await widget.loadAccounts(
                                  search: search,
                                  cursor: cursor,
                                  selectedId: widget.selectedAccountId,
                                );
                                if (!dialogContext.mounted) return;
                                update(() {
                                  accounts.addAll(
                                    page.rows.where(
                                      (row) => !accounts.any(
                                        (existing) =>
                                            existing.id == row.id &&
                                            existing.sharedKind ==
                                                row.sharedKind,
                                      ),
                                    ),
                                  );
                                  cursor = page.nextCursor;
                                });
                              } catch (_) {
                                if (mounted && dialogContext.mounted) {
                                  _showMessage(loc.accountListLoadFailed);
                                }
                                rethrow;
                              } finally {
                                if (dialogContext.mounted) {
                                  update(() => loadingMore = false);
                                }
                              }
                            },
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
                ],
              ),
            ),
          );
        },
      ),
    );
    debounce?.cancel();
    searchController.dispose();
    return result;
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
