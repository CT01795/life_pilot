import 'package:flutter/material.dart';
import 'package:life_pilot/utils/widgets/widgets_account_name_dialog.dart';
import 'package:life_pilot/utils/widgets/widgets_load_error.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:provider/provider.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/enum.dart';
import 'package:life_pilot/accounting/controller_accounting_list.dart';
import 'package:life_pilot/accounting/model_accounting_account.dart';
import 'package:life_pilot/accounting/page_accounting_detail.dart';
import 'package:life_pilot/accounting/service_accounting.dart';

/// Navigation and account picker widgets belong to View, not Controller.
extension AccountingAccountNavigation on ControllerAccountingList {
  // 共用方法：點 Accounting
  Future<void> handleAccounting({
    required BuildContext context,
    required String eventId,
  }) async {
    final accountService = context.read<ServiceAccounting>();
    final scope = (
      auth?.currentAccount,
      auth?.preferredStorage,
      auth?.personalDataRevision,
    );
    // 1️⃣ 嘗試找對應 eventId 的帳戶
    ModelAccountingAccount? existingAccount = await findAccountByEventId(
      eventId: eventId,
    );

    if (!context.mounted ||
        notifierDisposed ||
        scope !=
            (
              auth?.currentAccount,
              auth?.preferredStorage,
              auth?.personalDataRevision,
            )) {
      return;
    }
    // 2️⃣ 如果存在帳戶 → 直接跳 Accounting 頁
    if (existingAccount != null) {
      await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => PageAccountingDetail(
            service: accountService,
            account: existingAccount,
            linkedEventId: eventId,
          ),
        ),
      );
      return;
    }

    // 3️⃣ 如果不存在 → 顯示帳戶選擇 Dialog
    final selectedAccount = await _showAccountPickerDialog(context, eventId);
    if (selectedAccount == null ||
        !context.mounted ||
        notifierDisposed ||
        scope !=
            (
              auth?.currentAccount,
              auth?.preferredStorage,
              auth?.personalDataRevision,
            )) {
      return;
    }

    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PageAccountingDetail(
          service: accountService,
          account: selectedAccount,
          linkedEventId: eventId,
        ),
      ),
    );
  }

  // 復用原本 Dialog
  Future<ModelAccountingAccount?> _showAccountPickerDialog(
    BuildContext context,
    String eventId,
  ) {
    final loc = AppLocalizations.of(context)!;
    final accountService = context.read<ServiceAccounting>();
    final accountAuth = auth;
    final ownerScope = (
      auth?.currentAccount,
      auth?.preferredStorage,
      auth?.personalDataRevision,
    );
    void refreshOwner() {
      if (!notifierDisposed &&
          ownerScope ==
              (
                auth?.currentAccount,
                auth?.preferredStorage,
                auth?.personalDataRevision,
              )) {
        loadAccounts();
      }
    }

    return showDialog<ModelAccountingAccount>(
      context: context,
      builder: (dialogContext) {
        final screenSize = MediaQuery.sizeOf(dialogContext);
        return DefaultTabController(
          length: 2,
          child: Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 640,
                maxHeight: screenSize.height * 0.8,
              ),
              child: SizedBox(
                width: double.maxFinite,
                height: screenSize.height * 0.75,
                child: Column(
                  children: [
                    TabBar(
                      tabs: [
                        Tab(text: loc.accountPersonal),
                        Tab(text: loc.accountProject),
                        //Tab(text: loc.accountMaster),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          ChangeNotifierProvider(
                            create: (_) => ControllerAccountingList(
                              service: accountService,
                              auth: accountAuth,
                            ),
                            child: _AccountListView(
                              category: AccountCategory.personal.name,
                              eventId: eventId,
                              onCreated: refreshOwner,
                            ),
                          ),
                          ChangeNotifierProvider(
                            create: (_) => ControllerAccountingList(
                              service: accountService,
                              auth: accountAuth,
                            ),
                            child: _AccountListView(
                              category: AccountCategory.project.name,
                              eventId: eventId,
                              onCreated: refreshOwner,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AccountListView extends StatefulWidget {
  final String category;
  final String eventId;
  final VoidCallback onCreated;

  const _AccountListView({
    required this.category,
    required this.eventId,
    required this.onCreated,
  });

  @override
  State<_AccountListView> createState() => _AccountListViewState();
}

class _AccountListViewState extends State<_AccountListView> {
  bool _creating = false;
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final controller = context.read<ControllerAccountingList>();
      await controller.setCategory(widget.category);
      if (!mounted) return;
      // Account creation resolves a default currency only when needed.
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ControllerAccountingList>(
      builder: (_, controller, _) {
        final accounts = controller.accounts;
        final loc = AppLocalizations.of(context)!;

        if (controller.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          children: [
            if (controller.loadError != null)
              WidgetsLoadError(onRetry: () => controller.loadAccounts()),
            Expanded(
              child: ListView.builder(
                scrollCacheExtent: const ScrollCacheExtent.pixels(240),
                addAutomaticKeepAlives: false,
                itemCount: accounts.length,
                itemBuilder: (_, index) {
                  final account = accounts[index];
                  return ListTile(
                    title: Text(account.accountName),
                    onTap: () {
                      Navigator.pop(context, account);
                    },
                  );
                },
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.add),
              label: Text(loc.accountNew),
              onPressed: _creating
                  ? null
                  : () async {
                      setState(() => _creating = true);
                      try {
                        final name = await showDialog<String>(
                          context: context,
                          builder: (_) => const WidgetsAccountNameDialog(),
                        );
                        if (!mounted || name == null) return;
                        await controller.createAccount(
                          name: name,
                          eventId: widget.eventId,
                        );
                        widget.onCreated();
                      } catch (_) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(loc.unknownError)),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _creating = false);
                      }
                    },
            ),
          ],
        );
      },
    );
  }
}
