import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/accounting/controller_accounting_account.dart';
import 'package:life_pilot/controllers/auth/controller_auth.dart';
import 'package:life_pilot/controllers/calendar/controller_calendar.dart';
import 'package:life_pilot/models/accounting/model_accounting_account.dart';
import 'package:life_pilot/models/event/model_event_calendar.dart';
import 'package:life_pilot/controllers/event/controller_event.dart';
import 'package:life_pilot/core/app_navigator.dart';
import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/models/event/model_event_item.dart';
import 'package:life_pilot/pages/page_accounting_detail.dart';
import 'package:life_pilot/services/event/service_event.dart';
import 'package:life_pilot/services/service_accounting.dart';
import 'package:life_pilot/views/widgets/event/widgets_confirmation_dialog.dart';
import 'package:life_pilot/views/widgets/event/widgets_event_card.dart';
import 'package:life_pilot/views/widgets/event/widgets_event_dialog.dart';
import 'package:life_pilot/views/widgets/event/widgets_event_trailing.dart';
import 'package:provider/provider.dart';

class WidgetsEventList extends StatelessWidget {
  final ControllerAuth auth;
  final ServiceEvent serviceEvent;
  final List<EventItem> filteredEvents;
  final ScrollController scrollController;
  final String tableName;
  final String toTableName;
  final ControllerEvent controllerEvent;
  final ModelEventCalendar modelEventCalendar;
  final ControllerCalendar controllerCalendar;

  const WidgetsEventList({
    super.key,
    required this.auth,
    required this.controllerCalendar,
    required this.serviceEvent,
    required this.filteredEvents,
    required this.scrollController,
    required this.tableName,
    required this.toTableName,
    required this.controllerEvent,
    required this.modelEventCalendar,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Consumer<ModelEventCalendar>(
      builder: (_, view, __) {
        return ListView.builder(
          key: PageStorageKey(tableName),
          controller: scrollController,
          itemCount: filteredEvents.length,
          itemBuilder: (context, index) {
            final event = filteredEvents[index];
            EventViewModel eventViewModel = controllerEvent.buildEventViewModel(
                event: event,
                parentLocation: constEmpty,
                canDelete: controllerEvent.canDelete(
                    account: event.account ?? constEmpty),
                showSubEvents: true,
                loc: loc);

            return WidgetsEventCard(
              eventViewModel: eventViewModel,
              tableName: tableName,
              onTap: () => _showEventDialog(
                  context: context,
                  eventViewModel: eventViewModel,
                  tableName: tableName),
              onDelete: controllerEvent.canDelete(
                      account: event.account ?? constEmpty)
                  ? () async {
                      final confirmed = await showConfirmationDialog(
                        content: '${loc.eventDelete}「${event.name}」？',
                        confirmText: loc.delete,
                        cancelText: loc.cancel,
                      );

                      if (confirmed == true) {
                        try {
                          await controllerEvent.deleteEvent(event);
                          AppNavigator.showSnackBar(loc.deleteOk);
                        } catch (e) {
                          AppNavigator.showErrorBar('${loc.deleteError}: $e');
                        }
                      }
                    }
                  : null,
              onLike: tableName == TableNames.recommendedEvents
                  ? () async {
                      await controllerEvent.likeEvent(
                          event: event,
                          account: auth.currentAccount ?? AuthConstants.guest);
                    }
                  : null,
              onDislike: tableName == TableNames.recommendedEvents
                  ? () async {
                      await controllerEvent.dislikeEvent(
                          event: event,
                          account: auth.currentAccount ?? AuthConstants.guest);
                    }
                  : null,
              onAccounting: tableName == TableNames.calendarEvents ||
                      tableName == TableNames.memoryTrace
                  ? () async {
                    final controller = context.read<ControllerAccountingAccount>();

                    // 嘗試找對應 eventId 的帳戶
                    ModelAccountingAccount? existingAccount = await controller.findAccountByEventId(eventId: event.id);

                    // 如果存在，直接進入 Accounting 頁
                    if (existingAccount != null) {
                      await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PageAccountingDetail(
                            service: context.read<ServiceAccounting>(),
                            accountId: existingAccount.id,
                            accountName: existingAccount.accountName,
                          ),
                        ),
                      );
                      return;
                    }

                    final selectedAccount =
                        await _showAccountPickerDialog(context, event.id);

                    if (selectedAccount == null) return;

                    await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PageAccountingDetail(
                          service: context.read<ServiceAccounting>(),
                          accountId: selectedAccount.id,
                          accountName: selectedAccount.accountName,
                        ),
                      ),
                    );
                  } : null, //TODO
              trailing: widgetsEventTrailing(
                context: context,
                auth: auth,
                serviceEvent: serviceEvent,
                controllerCalendar: controllerCalendar,
                controllerEvent: controllerEvent,
                modelEventCalendar: modelEventCalendar,
                event: event,
                tableName: tableName,
                toTableName: toTableName,
              ),
              showSubEvents: false,
            );
          },
        );
      },
    );
  }

  void _showEventDialog(
      {required BuildContext context,
      required EventViewModel eventViewModel,
      required String tableName}) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: const Color.fromARGB(200, 128, 128, 128),
      builder: (_) => WidgetsEventDialog(
        eventViewModel: eventViewModel,
        tableName: tableName,
      ),
    );
  }

  Future<ModelAccountingAccount?> _showAccountPickerDialog(
      BuildContext context, String eventId) {
    final loc = AppLocalizations.of(context)!;
    return showDialog<ModelAccountingAccount>(
      context: context,
      builder: (_) {
        return DefaultTabController(
          length: 2,
          child: Dialog(
            child: SizedBox(
              height: 500,
              child: Column(
                children: [
                  TabBar(
                    tabs: [
                      Tab(text: loc.accountPersonal),
                      Tab(text: loc.accountProject),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _AccountListView(
                            category: AccountCategory.personal.name,
                            eventId: eventId),
                        _AccountListView(
                            category: AccountCategory.project.name,
                            eventId: eventId),
                      ],
                    ),
                  ),
                ],
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

  const _AccountListView({required this.category, required this.eventId});

  @override
  State<_AccountListView> createState() => _AccountListViewState();
}

class _AccountListViewState extends State<_AccountListView> {

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = context.read<ControllerAccountingAccount>();
    // 延後到 build 完成再呼叫
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await controller.setCategory(widget.category);
      await controller.setCurrentType(type: 'balance');
      await controller.askMainCurrency(context: context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ControllerAccountingAccount>(
      builder: (_, controller, __) {
        final accounts = controller.accounts;

        if (controller.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          children: [
            Expanded(
              child: ListView.builder(
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
              label: const Text("New Account"),
              onPressed: () async {
                final textController = TextEditingController();

                final created = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    content: TextField(
                      controller: textController,
                      decoration:
                          const InputDecoration(hintText: 'Account name'),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          final modelAccountingAccount =
                              await controller.createAccount(
                            name: textController.text,
                            eventId: widget.eventId,
                          );
                          Navigator.pop(context, true);
                          // 如果新增的帳戶 category 與目前 Tab 不符
                          if (modelAccountingAccount.category !=
                              widget.category) {
                            // 切換到正確 Tab
                            final parentTabController =
                                DefaultTabController.of(context);
                            int tabIndex = modelAccountingAccount.category ==
                                    AccountCategory.personal.name
                                ? 0
                                : 1;
                            parentTabController.animateTo(tabIndex);

                            // 同時更新帳戶列表
                            await controller
                                .setCategory(modelAccountingAccount.category);
                          } else {
                            // 如果同 Tab，直接刷新
                            //await controller.setCategory(widget.category);
                          }
                        },
                        child: const Text('Create'),
                      ),
                    ],
                  ),
                );

                if (created == true) {
                  controller.setCategory(widget.category);
                }
              },
            ),
          ],
        );
      },
    );
  }
}
