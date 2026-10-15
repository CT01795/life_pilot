import 'package:flutter/material.dart';
import 'package:life_pilot/utils/widgets/widgets_account_name_dialog.dart';
import 'package:life_pilot/utils/widgets/widgets_load_error.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:provider/provider.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/enum.dart';
import 'package:life_pilot/point_record/controller_point_record_list.dart';
import 'package:life_pilot/point_record/model_point_record_account.dart';
import 'package:life_pilot/point_record/page_point_record_detail.dart';
import 'package:life_pilot/point_record/service_point_record.dart';

/// Navigation and account picker widgets belong to View, not Controller.
extension PointRecordAccountNavigation on ControllerPointRecordList {
  Future<void> handlePointRecord({
    required BuildContext context,
    required String eventId,
  }) async {
    final accountService = context.read<ServicePointRecord>();
    final scope = (
      auth?.currentAccount,
      auth?.preferredStorage,
      auth?.personalDataRevision,
    );
    final existingAccount = await findAccountByEventId(eventId: eventId);
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

    final account =
        existingAccount ??
        await _showAccountPickerDialog(context: context, eventId: eventId);
    if (account == null ||
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
        builder: (_) => PagePointRecordDetail(
          service: accountService,
          account: account,
          linkedEventId: eventId,
        ),
      ),
    );
  }

  Future<ModelPointRecordAccount?> _showAccountPickerDialog({
    required BuildContext context,
    required String eventId,
  }) {
    final loc = AppLocalizations.of(context)!;
    final accountService = context.read<ServicePointRecord>();
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

    return showDialog<ModelPointRecordAccount>(
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
                        Tab(text: loc.pointGroup),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          ChangeNotifierProvider(
                            create: (_) => ControllerPointRecordList(
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
                            create: (_) => ControllerPointRecordList(
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
      final controller = context.read<ControllerPointRecordList>();
      await controller.setCategory(widget.category);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ControllerPointRecordList>(
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
