import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:image_picker/image_picker.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/safe_change_notifier.dart';
import 'package:life_pilot/utils/enum.dart';
import 'package:life_pilot/point_record/model_point_record_account.dart';
import 'package:life_pilot/point_record/page_point_record_detail.dart';
import 'package:life_pilot/point_record/service_point_record.dart';
import 'package:provider/provider.dart';

class ControllerPointRecordList extends SafeChangeNotifier {
  final ServicePointRecord service;
  ControllerAuth? auth;
  String? _dataScopeKey;
  int _accountGeneration = 0;

  String? _currentCategory;
  String get category => _currentCategory == null
      ? AccountCategory.personal.name
      : _currentCategory!;

  Future<void> setCategory(String category) async {
    if (_currentCategory == category) return;
    _currentCategory = category;
    await loadAccounts();
  }

  ControllerPointRecordList({required this.service, required this.auth})
    : _dataScopeKey = _scopeKey(auth);

  static String _scopeKey(ControllerAuth? auth) =>
      '${auth?.currentAccount?.trim().toLowerCase() ?? ''}|'
      '${auth?.preferredStorage.name ?? ''}|'
      '${auth?.personalDataRevision ?? 0}';

  List<ModelPointRecordAccount> accounts = [];
  bool isLoading = false;

  Future<void> loadAccounts({String? inputCategory}) async {
    if (isLoading) return;
    final generation = _accountGeneration;
    isLoading = true;
    notifyListeners();
    try {
      final loaded = await service.fetchAccounts(
        user: auth?.currentAccount ?? '',
        category: inputCategory ?? category,
      );
      if (generation != _accountGeneration) return;
      accounts = loaded;
    } finally {
      if (generation == _accountGeneration) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  void updateAuth(ControllerAuth nextAuth, {bool notify = true}) {
    final nextScope = _scopeKey(nextAuth);
    auth = nextAuth;
    if (_dataScopeKey == nextScope) return;
    _dataScopeKey = nextScope;
    _accountGeneration++;
    isLoading = false;
    accounts = [];
    _currentCategory = null;
    if (notify) notifyListeners();
  }

  Future<ModelPointRecordAccount> createAccount({
    required String name,
    String? eventId,
  }) async {
    final modelPointRecordAccount = await service.createAccount(
      name: name,
      user: auth?.currentAccount ?? '',
      currency: null,
      category: category,
      eventId: eventId,
    );
    // ⭐ 統一來源：重新拉一次
    await loadAccounts();
    return modelPointRecordAccount;
  }

  Future<void> deleteAccount({required String accountId}) async {
    await service.deleteAccount(accountId: accountId);
    await loadAccounts();
  }

  Future<void> updateAccountImage(String accountId, XFile pickedFile) async {
    Uint8List bytes = await pickedFile.readAsBytes(); // Web / 手機都可以

    // 上傳圖片給後端，後端返回可訪問 URL
    final newImage = await service.uploadAccountImageBytesDirect(
      accountId,
      bytes,
    );

    final index = accounts.indexWhere((a) => a.id == accountId);
    if (index == -1) return;

    accounts[index] = accounts[index].copyWith(masterGraphUrl: newImage);

    notifyListeners();
  }

  ModelPointRecordAccount? getAccountById(String id) {
    return accounts.firstWhereOrNull((a) => a.id == id);
  }

  Future<ModelPointRecordAccount?> findAccountByEventId({
    required String eventId,
  }) async {
    return await service.findAccountByEventId(
      eventId: eventId,
      user: auth?.currentAccount ?? '',
    );
  }

  void updateAccountTotals({
    required String accountId,
    required int deltaPoints,
  }) {
    final index = accounts.indexWhere((a) => a.id == accountId);
    if (index == -1) return;

    final old = accounts[index];
    accounts[index] = old.copyWith(points: old.points + deltaPoints);

    notifyListeners();
  }

  Future<void> handlePointRecord({
    required BuildContext context,
    required String eventId,
  }) async {
    final existingAccount = await findAccountByEventId(eventId: eventId);
    if (!context.mounted) return;

    final account =
        existingAccount ??
        await _showAccountPickerDialog(context: context, eventId: eventId);
    if (account == null || !context.mounted) return;

    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PagePointRecordDetail(
          service: context.read<ServicePointRecord>(),
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
                          _AccountListView(
                            category: AccountCategory.personal.name,
                            eventId: eventId,
                          ),
                          _AccountListView(
                            category: AccountCategory.project.name,
                            eventId: eventId,
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

  const _AccountListView({required this.category, required this.eventId});

  @override
  State<_AccountListView> createState() => _AccountListViewState();
}

class _AccountListViewState extends State<_AccountListView> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
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
              onPressed: () async {
                final textController = TextEditingController();

                final created = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    content: TextField(
                      controller: textController,
                      decoration: InputDecoration(hintText: loc.accountName),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(loc.cancel),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          final modelPointRecordAccount = await controller
                              .createAccount(
                                name: textController.text,
                                eventId: widget.eventId,
                              );
                          Navigator.pop(context, true);
                          // 如果新增的帳戶 category 與目前 Tab 不符
                          if (modelPointRecordAccount.category !=
                              widget.category) {
                            // 切換到正確 Tab
                            final parentTabController = DefaultTabController.of(
                              context,
                            );
                            int tabIndex =
                                modelPointRecordAccount.category ==
                                    AccountCategory.personal.name
                                ? 0
                                : 1;
                            parentTabController.animateTo(tabIndex);

                            // 同時更新帳戶列表
                            await controller.setCategory(
                              modelPointRecordAccount.category,
                            );
                          }
                        },
                        child: Text(loc.accountCreate),
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
