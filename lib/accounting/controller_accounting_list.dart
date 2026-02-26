import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/utils/enum.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/accounting/model_accounting_account.dart';
import 'package:life_pilot/accounting/page_accounting_detail.dart';
import 'package:life_pilot/accounting/service_accounting.dart';
import 'package:provider/provider.dart';

class ControllerAccountingList extends ChangeNotifier {
  final ServiceAccounting service;
  ControllerAuth? auth;

  ControllerAccountingList({
    required this.service,
    required this.auth,
  });

  bool isLoading = false;
  List<ModelAccountingAccount> accounts = [];

  Future<void> loadAccounts({String? inputCategory}) async {
    if (isLoading) return;
    isLoading = true;
    notifyListeners();
    accounts = await service.fetchAccounts(
        user: auth?.currentAccount ?? '',
        category: inputCategory ?? category);
    isLoading = false;
    notifyListeners();
  }

  String? mainCurrency;

  String? _currentCategory;
  String get category => _currentCategory == null
      ? AccountCategory.personal.name
      : _currentCategory!;

  Future<void> setCategory(String category) async {
    if (_currentCategory == category) return;
    _currentCategory = category;
    await loadAccounts();
  }

  Future<void> askMainCurrency({required BuildContext context}) async {
    if (accounts.isNotEmpty) {
      mainCurrency = accounts[0].currency;
      return;
    }
    if (accounts.isEmpty || mainCurrency == null || mainCurrency!.isEmpty) {
      mainCurrency = await service.fetchLatestAccount(
          user: auth?.currentAccount ?? '', category: category);
      notifyListeners();
      return;
    }

    final textController = TextEditingController(text: mainCurrency);

    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Set main currency'),
        content: TextField(controller: textController),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, textController.text),
              child: Text('OK')),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      mainCurrency = result.toUpperCase();
      notifyListeners();
    } else {
      mainCurrency ??= 'TWD'; // ✅ 如果使用者沒輸入，給預設
      notifyListeners();
    }
  }

  Future<ModelAccountingAccount> createAccount(
      {required String name, String? eventId}) async {
    if (mainCurrency == null || mainCurrency!.isEmpty) {
      mainCurrency = await service.fetchLatestAccount(
          user: auth?.currentAccount ?? '', category: category);
    }
    final modelAccountingAccount = await service.createAccount(
        name: name,
        user: auth?.currentAccount ?? '',
        currency: mainCurrency,
        category: category,
        eventId: eventId);
    // ⭐ 統一來源：重新拉一次
    await loadAccounts();
    return modelAccountingAccount;
  }

  Future<void> deleteAccount({required String accountId}) async {
    await service.deleteAccount(accountId: accountId);
    await loadAccounts();
  }

  Future<void> updateAccountImage(String accountId, XFile pickedFile) async {
    Uint8List bytes = await pickedFile.readAsBytes(); // Web / 手機都可以

    // 上傳圖片給後端，後端返回可訪問 URL
    final newImage =
        await service.uploadAccountImageBytesDirect(accountId, bytes);

    final index = accounts.indexWhere((a) => a.id == accountId);
    if (index == -1) return;

    accounts[index] = accounts[index].copyWith(
      masterGraphUrl: newImage,
      currency: mainCurrency,
    );

    notifyListeners();
  }

  ModelAccountingAccount? getAccountById(String id) {
    return accounts.firstWhereOrNull((a) => a.id == id);
  }

  Future<ModelAccountingAccount?> findAccountByEventId(
      {required String eventId}) async {
    // 或者直接從 Supabase 查詢
    return await service.findAccountByEventId(
      eventId: eventId,
      user: auth?.currentAccount ?? '',
    );
  }

  void updateAccountTotals({
    required String accountId,
    required int deltaBalance,
    required String? currency,
  }) {
    final index = accounts.indexWhere((a) =>
        a.id == accountId && (currency == null || a.currency == currency));
    if (index == -1) return;

    final old = accounts[index];
    accounts[index] = old.copyWith(
      balance: old.balance + deltaBalance,
      currency: old.currency,
      exchangeRate: old.exchangeRate,
    );

    notifyListeners();
  }

  Future<void> changeMainCurrency({
    required String accountId,
    required String currency,
  }) async {
    await service.switchMainCurrency(
      accountId: accountId,
      currency: currency,
    );
    await loadAccounts();
  }

  // 共用方法：點 Accounting
  Future<void> handleAccounting({
    required BuildContext context,
    required String eventId,
  }) async {
    // 1️⃣ 嘗試找對應 eventId 的帳戶
    ModelAccountingAccount? existingAccount = await findAccountByEventId(
      eventId: eventId,
    );

    // 2️⃣ 如果存在帳戶 → 直接跳 Accounting 頁
    if (existingAccount != null) {
      await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => PageAccountingDetail(
            service: context.read<ServiceAccounting>(),
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
        builder: (_) => PageAccountingDetail(
          service: context.read<ServiceAccounting>(),
          account: selectedAccount,
        ),
      ),
    );
  }

  // 復用原本 Dialog
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
                      //Tab(text: loc.accountMaster),
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
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final controller = context.read<ControllerAccountingList>();
      await controller.setCategory(widget.category);
      await controller.askMainCurrency(context: context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ControllerAccountingList>(
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
