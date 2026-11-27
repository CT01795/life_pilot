import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/utils/enum.dart';
import 'package:life_pilot/utils/safe_change_notifier.dart';
import 'package:life_pilot/utils/refresh_request_coordinator.dart';
import 'package:life_pilot/accounting/model_accounting_account.dart';
import 'package:life_pilot/accounting/service_accounting.dart';
import 'package:life_pilot/utils/model_personal_data_scope.dart';

class ControllerAccountingList extends SafeChangeNotifier {
  static const accountPageSize = 20;
  final ServiceAccounting _service;
  final Duration requestTimeout;
  ControllerAuth? auth;
  ModelPersonalDataScope? _dataScopeKey;
  int _accountGeneration = 0;
  int _listRequest = 0;
  RefreshRequestCoordinator _loads = RefreshRequestCoordinator();
  (String, String)? _loadKey;
  Future<void>? get _loadFuture => _loads.pending;
  Timer? _searchDebounce;
  bool _hasLoadedAccounts = false;
  final _accountRefreshes = <String, Object>{};
  int _currencyRevision = 0;

  ControllerAccountingList({
    required this._service,
    required this.auth,
    this.requestTimeout = const Duration(seconds: 30),
  }) : _dataScopeKey = _scopeKey(auth) {
    auth?.addListener(_onAuthChanged);
  }

  void _onAuthChanged() {
    final currentAuth = auth;
    if (currentAuth != null) updateAuth(currentAuth);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    auth?.removeListener(_onAuthChanged);
    super.dispose();
  }

  static ModelPersonalDataScope _scopeKey(ControllerAuth? auth) =>
      ModelPersonalDataScope(
        account: auth?.currentAccount,
        storage: auth?.preferredStorage,
        revision: auth?.personalDataRevision ?? 0,
      );

  bool isLoading = false;
  bool isLoadingMore = false;
  bool hasMore = false;
  bool hasRequestedMore = false;
  Object? loadError;
  Object? loadMoreError;
  List<ModelAccountingAccount> accounts = [];
  String searchQuery = '';

  void updateSearchQueryDebounced(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 280),
      () => applySearchQuery(value),
    );
  }

  Future<void> applySearchQuery(String value) async {
    _searchDebounce?.cancel();
    _searchDebounce = null;
    final normalized = value.trim();
    if (normalized == searchQuery) return;
    searchQuery = normalized;
    await loadAccounts();
  }

  bool _isCurrent(int generation) =>
      !notifierDisposed &&
      generation == _accountGeneration &&
      _dataScopeKey == _scopeKey(auth);

  /// After a detail write, reload only the account already in this list.
  Future<void> refreshAccount(String accountId) async {
    final generation = _accountGeneration;
    final selectedCategory = category;
    final user = auth?.currentAccount;
    if (!_isCurrent(generation) || user == null || user.isEmpty) return;
    final ticket = Object();
    _accountRefreshes[accountId] = ticket;
    bool current() =>
        _isCurrent(generation) &&
        category == selectedCategory &&
        identical(_accountRefreshes[accountId], ticket);
    try {
      await _loadFuture;
      if (!current() || !accounts.any((row) => row.id == accountId)) return;
      final request = _listRequest;
      final updated = await _service
          .fetchAccountById(user: user, accountId: accountId)
          .timeout(requestTimeout);
      if (!current() || request != _listRequest) return;
      if (updated == null) {
        await loadAccounts();
        return;
      }
      accounts = [
        for (final row in accounts)
          if (row.id == accountId) updated else row,
      ];
      notifyListeners();
    } catch (_) {
      if (current()) await loadAccounts();
    } finally {
      if (identical(_accountRefreshes[accountId], ticket)) {
        _accountRefreshes.remove(accountId);
      }
    }
  }

  Future<void> loadAccounts({String? inputCategory, bool force = false}) {
    if (notifierDisposed) return Future.value();
    final requestedCategory = inputCategory ?? category;
    final requestedSearchQuery = searchQuery;
    final key = (requestedCategory, requestedSearchQuery);
    if (_loadKey != key) {
      _loads = RefreshRequestCoordinator();
      _loadKey = key;
    }
    final generation = _accountGeneration;
    final loads = _loads;
    if (force && loads.isRunning) _listRequest++;
    return loads.run(() {
      if (!_isCurrent(generation) || !identical(_loads, loads)) {
        return Future<void>.value();
      }
      final request = ++_listRequest;
      isLoading = true;
      hasRequestedMore = false;
      isLoadingMore = false;
      loadMoreError = null;
      loadError = null;
      final future = _loadAccounts(
        auth?.currentAccount ?? '',
        requestedCategory,
        requestedSearchQuery,
        generation,
        request,
      );
      if (_isCurrent(generation) && request == _listRequest) notifyListeners();
      return future;
    }, force: force);
  }

  Future<void> _loadAccounts(
    String user,
    String requestedCategory,
    String requestedSearchQuery,
    int generation,
    int request,
  ) async {
    try {
      // Bound only the read, not create/delete operations. Timeout releases
      // the shared request; its late response cannot publish or block retry.
      final loaded = await _service
          .fetchAccounts(
            user: user,
            category: requestedCategory,
            searchQuery: requestedSearchQuery,
            offset: 0,
            limit: accountPageSize + 1,
          )
          .timeout(requestTimeout);
      if (!_isCurrent(generation) || request != _listRequest) return;
      hasMore = loaded.length > accountPageSize;
      accounts = loaded.take(accountPageSize).toList(growable: false);
      _hasLoadedAccounts = true;
    } catch (error) {
      if (_isCurrent(generation) && request == _listRequest) {
        loadError = error;
        _hasLoadedAccounts = false;
      }
    } finally {
      if (_isCurrent(generation) && request == _listRequest) {
        isLoading = false;
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
    _loads = RefreshRequestCoordinator();
    _loadKey = null;
    _searchDebounce?.cancel();
    _searchDebounce = null;
    isLoading = false;
    accounts = [];
    hasMore = false;
    hasRequestedMore = false;
    isLoadingMore = false;
    loadMoreError = null;
    _hasLoadedAccounts = false;
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
    _currencyRevision++;
    accounts = [];
    _hasLoadedAccounts = false;
    mainCurrency = null;

    await loadAccounts();
  }

  /// Resolves the currency without owning dialogs or a BuildContext.
  Future<void> loadMainCurrency() async {
    if (notifierDisposed) return;
    final generation = _accountGeneration;
    final revision = _currencyRevision;
    final selectedCategory = category;
    bool isCurrent() =>
        _isCurrent(generation) &&
        revision == _currencyRevision &&
        category == selectedCategory;
    final pending = _loadFuture;
    if (pending != null) {
      await pending;
    } else if (!_hasLoadedAccounts) {
      await loadAccounts(inputCategory: selectedCategory);
    }
    if (!isCurrent()) return;
    if (!_hasLoadedAccounts && loadError != null) throw loadError!;
    final resolved = accounts.isNotEmpty ? accounts.first.currency : 'TWD';
    if (mainCurrency == resolved) return;
    mainCurrency = resolved;
    notifyListeners();
  }

  Future<void> loadMoreAccounts() async {
    if (notifierDisposed || isLoading || isLoadingMore || !hasMore) return;
    final generation = _accountGeneration;
    final request = _listRequest;
    final selectedCategory = category;
    final selectedSearchQuery = searchQuery;
    final user = auth?.currentAccount ?? '';
    isLoadingMore = true;
    hasRequestedMore = true;
    loadMoreError = null;
    notifyListeners();
    try {
      final loaded = await _service
          .fetchAccounts(
            user: user,
            category: selectedCategory,
            searchQuery: selectedSearchQuery,
            offset: accounts.length,
            limit: accountPageSize + 1,
          )
          .timeout(requestTimeout);
      if (!_isCurrent(generation) ||
          request != _listRequest ||
          category != selectedCategory) {
        return;
      }
      hasMore = loaded.length > accountPageSize;
      final known = accounts.map((row) => row.id).toSet();
      accounts = List.unmodifiable([
        ...accounts,
        ...loaded.take(accountPageSize).where((row) => known.add(row.id)),
      ]);
    } catch (error) {
      if (_isCurrent(generation) && request == _listRequest) {
        loadMoreError = error;
      }
    } finally {
      if (_isCurrent(generation) && request == _listRequest) {
        isLoadingMore = false;
        notifyListeners();
      }
    }
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
      await loadMainCurrency();
      currency = mainCurrency ?? 'TWD';
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
    if (_isCurrent(generation)) await loadAccounts(force: true);
    return modelAccountingAccount;
  }

  Future<void> deleteAccount({required String accountId}) async {
    if (notifierDisposed) return;
    final generation = _accountGeneration;
    await _service.deleteAccount(accountId: accountId);
    if (_isCurrent(generation)) await loadAccounts(force: true);
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
    if (notifierDisposed || deltaBalance == 0) return;
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
    if (_isCurrent(generation)) await loadAccounts(force: true);
  }
}
