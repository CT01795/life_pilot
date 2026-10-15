import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/utils/enum.dart';
import 'package:life_pilot/utils/safe_change_notifier.dart';
import 'package:life_pilot/accounting/model_accounting_account.dart';
import 'package:life_pilot/accounting/service_accounting.dart';
import 'package:life_pilot/utils/text_normalization.dart';

class ControllerAccountingList extends SafeChangeNotifier {
  final ServiceAccounting _service;
  ControllerAuth? auth;
  String? _dataScopeKey;
  int _accountGeneration = 0;
  int _listRequest = 0;
  String? _loadingCategory;
  Future<void>? _loadFuture;

  ControllerAccountingList({
    required ServiceAccounting service,
    required this.auth,
  }) : _service = service,
       _dataScopeKey = _scopeKey(auth) {
    auth?.addListener(_onAuthChanged);
  }

  void _onAuthChanged() {
    final currentAuth = auth;
    if (currentAuth != null) updateAuth(currentAuth);
  }

  @override
  void dispose() {
    auth?.removeListener(_onAuthChanged);
    super.dispose();
  }

  static String _scopeKey(ControllerAuth? auth) =>
      '${normalizeText(auth?.currentAccount)}|'
      '${auth?.preferredStorage.name ?? ''}|'
      '${auth?.personalDataRevision ?? 0}';

  bool isLoading = false;
  Object? loadError;
  List<ModelAccountingAccount> accounts = [];

  bool _isCurrent(int generation) =>
      !notifierDisposed &&
      generation == _accountGeneration &&
      _dataScopeKey == _scopeKey(auth);

  Future<void> loadAccounts({String? inputCategory}) {
    if (notifierDisposed) return Future.value();
    final requestedCategory = inputCategory ?? category;
    if (isLoading && _loadingCategory == requestedCategory) {
      return _loadFuture ?? Future.value();
    }
    final request = ++_listRequest;
    final generation = _accountGeneration;
    final user = auth?.currentAccount ?? '';
    _loadingCategory = requestedCategory;
    isLoading = true;
    loadError = null;
    _loadFuture = _loadAccounts(user, requestedCategory, generation, request);
    notifyListeners();
    return _loadFuture!;
  }

  Future<void> _loadAccounts(
    String user,
    String requestedCategory,
    int generation,
    int request,
  ) async {
    try {
      final loaded = await _service.fetchAccounts(
        user: user,
        category: requestedCategory,
      );
      if (!_isCurrent(generation) || request != _listRequest) return;
      accounts = loaded;
    } catch (error) {
      if (_isCurrent(generation) && request == _listRequest) loadError = error;
    } finally {
      if (_isCurrent(generation) && request == _listRequest) {
        isLoading = false;
        _loadingCategory = null;
        _loadFuture = null;
        notifyListeners();
      }
    }
  }

  void updateAuth(ControllerAuth nextAuth, {bool notify = true}) {
    final nextScope = _scopeKey(nextAuth);
    if (!identical(auth, nextAuth)) {
      auth?.removeListener(_onAuthChanged);
      nextAuth.addListener(_onAuthChanged);
    }
    auth = nextAuth;
    if (_dataScopeKey == nextScope) return;
    _dataScopeKey = nextScope;
    _accountGeneration++;
    _listRequest++;
    _loadFuture = null;
    _loadingCategory = null;
    isLoading = false;
    accounts = [];
    loadError = null;
    mainCurrency = null;
    _currentCategory = null;
    if (notify) notifyListeners();
  }

  String? mainCurrency;

  String? _currentCategory;
  String get category => _currentCategory == null
      ? AccountCategory.personal.name
      : _currentCategory!;

  Future<void> setCategory(String category) async {
    if (notifierDisposed || _currentCategory == category) return;
    _currentCategory = category;
    accounts = [];
    mainCurrency = null;

    await loadAccounts();
  }

  /// Resolves the currency without owning dialogs or a BuildContext.
  Future<void> loadMainCurrency() async {
    if (notifierDisposed) return;
    final generation = _accountGeneration;
    final selectedCategory = category;
    final user = auth?.currentAccount ?? '';
    final currency = accounts.isNotEmpty
        ? accounts.first.currency
        : await _service.fetchLatestAccount(
            user: user,
            category: selectedCategory,
          );
    if (!_isCurrent(generation) || category != selectedCategory) return;
    mainCurrency = currency;
    notifyListeners();
  }

  Future<ModelAccountingAccount> createAccount({
    required String name,
    String? eventId,
  }) async {
    if (notifierDisposed) throw StateError('Controller disposed');
    final generation = _accountGeneration;
    final user = auth?.currentAccount ?? '';
    final selectedCategory = category;
    var currency = mainCurrency;
    if (currency == null || currency.isEmpty) {
      currency = await _service.fetchLatestAccount(
        user: user,
        category: selectedCategory,
      );
    }
    if (!_isCurrent(generation) || category != selectedCategory) {
      throw StateError('Account scope changed');
    }
    mainCurrency = currency;
    final modelAccountingAccount = await _service.createAccount(
      name: name,
      user: user,
      currency: currency,
      category: selectedCategory,
      eventId: eventId,
    );
    // ⭐ 統一來源：重新拉一次
    if (_isCurrent(generation)) await loadAccounts();
    return modelAccountingAccount;
  }

  Future<void> deleteAccount({required String accountId}) async {
    if (notifierDisposed) return;
    final generation = _accountGeneration;
    await _service.deleteAccount(accountId: accountId);
    if (_isCurrent(generation)) await loadAccounts();
  }

  Future<void> updateAccountImage(String accountId, XFile pickedFile) async {
    if (notifierDisposed) return;
    final generation = _accountGeneration;
    Uint8List bytes = await pickedFile.readAsBytes(); // Web / 手機都可以
    if (!_isCurrent(generation)) return;

    // 上傳圖片給後端，後端返回可訪問 URL
    final newImage = await _service.uploadAccountImageBytesDirect(
      accountId,
      bytes,
    );

    if (!_isCurrent(generation)) return;
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

  Future<ModelAccountingAccount?> findAccountByEventId({
    required String eventId,
  }) async {
    return await _service.findAccountByEventId(
      eventId: eventId,
      user: auth?.currentAccount ?? '',
    );
  }

  void updateAccountTotals({
    required String accountId,
    required int deltaBalance,
    required String? currency,
  }) {
    final index = accounts.indexWhere(
      (a) => a.id == accountId && (currency == null || a.currency == currency),
    );
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
    if (notifierDisposed) return;
    final generation = _accountGeneration;
    await _service.switchMainCurrency(accountId: accountId, currency: currency);
    if (_isCurrent(generation)) await loadAccounts();
  }
}
