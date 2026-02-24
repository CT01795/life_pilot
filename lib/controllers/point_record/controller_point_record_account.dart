import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:life_pilot/controllers/auth/controller_auth.dart';
import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/models/point_record/model_point_record_account.dart';
import 'package:life_pilot/pages/page_point_record_detail.dart';
import 'package:life_pilot/services/service_point_record.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

enum AccountCategory {
  personal,
  project,
  master,
}

class ControllerPointRecordAccount extends ChangeNotifier {
  final ServicePointRecord service;
  ControllerAuth? auth;
  String? mainCurrency;

  String? _currentCategory;
  String get category => _currentCategory == null
      ? AccountCategory.personal.name
      : _currentCategory!;

  Future<void> setCategory(String category) async {
    if (_currentCategory == category) return;
    _currentCategory = category;
    await loadAccounts(force: true);
    notifyListeners();
  }

  ControllerPointRecordAccount({
    required this.service,
    required this.auth,
  });

  List<ModelPointRecordAccount> accounts = [];
  bool isLoading = false;
  bool isLoaded = false;

  Future<void> loadAccounts({bool force = false, String? inputCategory}) async {
    if (isLoading) return;
    if (!force && isLoaded) return;
    isLoading = true;
    notifyListeners();
    accounts = await service.fetchAccounts(
        user: auth?.currentAccount ?? constEmpty,
        category: inputCategory ?? category);
    isLoading = false;
    isLoaded = true;
    notifyListeners();
  }

  Future<ModelPointRecordAccount> createAccount(
      {required String name, String? eventId}) async {
    if (mainCurrency == null || mainCurrency!.isEmpty) {
      mainCurrency = await service.fetchLatestAccount(
          user: auth?.currentAccount ?? constEmpty,
          category: category);
    }
    final modelPointRecordAccount = await service.createAccount(
        name: name,
        user: auth?.currentAccount ?? constEmpty,
        currency: mainCurrency,
        category: category,
        eventId: eventId);
    // ⭐ 統一來源：重新拉一次
    await loadAccounts(force: true);
    return modelPointRecordAccount;
  }

  Future<void> deleteAccount({required String accountId}) async {
    await service.deleteAccount(accountId: accountId);
    await loadAccounts(force: true);
  }

  Future<void> updateAccountImage(String accountId, XFile pickedFile) async {
    Uint8List bytes = await pickedFile.readAsBytes(); // Web / 手機都可以

    // 上傳圖片給後端，後端返回可訪問 URL
    final newImage = await service.uploadAccountImageBytesDirect(
        accountId, bytes);

    final index = accounts.indexWhere((a) => a.id == accountId);
    if (index == -1) return;

    accounts[index] = accounts[index].copyWith(
      masterGraphUrl: newImage,
    );

    notifyListeners();
  }

  ModelPointRecordAccount getAccountById(String id) {
    final returnAccount = accounts.firstWhereOrNull((a) => a.id == id);
    return returnAccount ?? ModelPointRecordAccount(id: Uuid().v4(), accountName: 'dummy', category: 'balance');
  }

  Future<ModelPointRecordAccount?> findAccountByEventId(
      {required String eventId}) async {
    // 或者直接從 Supabase 查詢
    return await service.findAccountByEventId(
      eventId: eventId,
      user: auth?.currentAccount ?? constEmpty,
    );
  }

  void updateAccountTotals({
    required String accountId,
    required int deltaPoints,
  }) {
    final index = accounts.indexWhere((a) =>
        a.id == accountId);
    if (index == -1) return;

    final old = accounts[index];
    accounts[index] = old.copyWith(
      points: old.points + deltaPoints,
    );

    notifyListeners();
  }

  static final ModelPointRecordAccount dummyAccount = ModelPointRecordAccount(
      id: '__dummy__',
      accountName: '',
      points: 0,
      category: '');

  // 共用方法：點 PointRecord
  Future<void> handlePointRecord({
    required BuildContext context,
    required String eventId,
  }) async {
    // 1️⃣ 嘗試找對應 eventId 的帳戶
    ModelPointRecordAccount? existingAccount = await findAccountByEventId(
      eventId: eventId,
    );

    // 2️⃣ 如果存在帳戶 → 直接跳 PointRecord 頁
    if (existingAccount != null) {
      await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => PagePointRecordDetail(
            service: context.read<ServicePointRecord>(),
            account: existingAccount,
          ),
        ),
      );
      return;
    }

    // 3️⃣ 如果不存在 → 顯示帳戶選擇 Dialog
    final selectedAccount = await _showAccountPickerDialog(context, eventId);
    if (selectedAccount == null) return;

    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PagePointRecordDetail(
          service: context.read<ServicePointRecord>(),
          account: selectedAccount,
        ),
      ),
    );
  }

  // 復用原本 Dialog
  Future<ModelPointRecordAccount?> _showAccountPickerDialog(
      BuildContext context, String eventId) {
    final loc = AppLocalizations.of(context)!;
    return showDialog<ModelPointRecordAccount>(
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
    final controller = context.read<ControllerPointRecordAccount>();
    // 延後到 build 完成再呼叫
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await controller.setCategory(widget.category);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ControllerPointRecordAccount>(
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
                          final modelPointRecordAccount =
                              await controller.createAccount(
                            name: textController.text,
                            eventId: widget.eventId,
                          );
                          Navigator.pop(context, true);
                          // 如果新增的帳戶 category 與目前 Tab 不符
                          if (modelPointRecordAccount.category !=
                              widget.category) {
                            // 切換到正確 Tab
                            final parentTabController =
                                DefaultTabController.of(context);
                            int tabIndex = modelPointRecordAccount.category ==
                                    AccountCategory.personal.name
                                ? 0
                                : 1;
                            parentTabController.animateTo(tabIndex);

                            // 同時更新帳戶列表
                            await controller
                                .setCategory(modelPointRecordAccount.category);
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
