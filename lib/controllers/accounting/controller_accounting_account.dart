import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:life_pilot/controllers/auth/controller_auth.dart';
import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/models/accounting/model_accounting_account.dart';
import 'package:life_pilot/services/service_accounting.dart';

enum AccountCategory {
  personal,
  project,
  master,
}

class ControllerAccountingAccount extends ChangeNotifier {
  final ServiceAccounting service;
  ControllerAuth? auth;
  String? mainCurrency;
  String _currentType = 'points'; // 預設值

  String get currentType => _currentType;

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

  // ⭐ 關鍵：由頁面來決定
  Future<void> setCurrentType({required String type}) async {
    if (_currentType == type && isLoaded) return;

    _currentType = type;
    isLoaded = false;
    await loadAccounts(force: true);
  }

  ControllerAccountingAccount({
    required this.service,
    required this.auth,
  });

  Future<void> askMainCurrency({required BuildContext context}) async {
    if (accounts.isNotEmpty || mainCurrency == null || mainCurrency!.isEmpty) {
      mainCurrency = await service.fetchLatestAccount(
          user: auth?.currentAccount ?? constEmpty,
          currentType: currentType,
          category: category);
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

  List<ModelAccountingAccount> accounts = [];
  bool isLoading = false;
  bool isLoaded = false;

  Future<void> loadAccounts({bool force = false}) async {
    if (isLoading) return;
    if (!force && isLoaded) return;
    isLoading = true;
    notifyListeners();
    accounts = await service.fetchAccounts(
        user: auth?.currentAccount ?? constEmpty,
        currentType: currentType,
        category: category);
    isLoading = false;
    isLoaded = true;
    notifyListeners();
  }

  Future<ModelAccountingAccount> createAccount(
      {required String name, String? eventId}) async {
    if (mainCurrency == null || mainCurrency!.isEmpty) {
      mainCurrency = await service.fetchLatestAccount(
          user: auth?.currentAccount ?? constEmpty,
          currentType: currentType,
          category: category);
    }
    final modelAccountingAccount = await service.createAccount(
        name: name,
        user: auth?.currentAccount ?? constEmpty,
        currency: mainCurrency,
        currentType: currentType,
        category: category,
        eventId: eventId);
    // ⭐ 統一來源：重新拉一次
    await loadAccounts(force: true);
    return modelAccountingAccount;
  }

  Future<void> deleteAccount({required String accountId}) async {
    await service.deleteAccount(accountId: accountId, currentType: currentType);
    await loadAccounts(force: true);
  }

  Future<void> updateAccountImage(String accountId, XFile pickedFile) async {
    Uint8List bytes = await pickedFile.readAsBytes(); // Web / 手機都可以

    // 上傳圖片給後端，後端返回可訪問 URL
    final newImage = await service.uploadAccountImageBytesDirect(
        accountId, bytes, currentType);

    final index = accounts.indexWhere((a) => a.id == accountId);
    if (index == -1) return;

    accounts[index] = accounts[index].copyWith(
      masterGraphUrl: newImage,
      currency: mainCurrency,
    );

    notifyListeners();
  }

  ModelAccountingAccount getAccountById(String id) => accounts.firstWhere(
        (a) => a.id == id,
        orElse: () => dummyAccount,
      );

  Future<ModelAccountingAccount?> findAccountByEventId(
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
    required int deltaBalance,
    required String? currency,
  }) {
    final index = accounts.indexWhere((a) =>
        a.id == accountId && (currency == null || a.currency == currency));
    if (index == -1) return;

    final old = accounts[index];
    accounts[index] = old.copyWith(
      points: old.points + deltaPoints,
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
    await loadAccounts(force: true);
  }

  static final ModelAccountingAccount dummyAccount = ModelAccountingAccount(
      id: '__dummy__',
      accountName: '',
      points: 0,
      balance: 0,
      currency: null,
      category: '');
}
