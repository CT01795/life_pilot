import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/utils/safe_change_notifier.dart';
import 'package:life_pilot/utils/enum.dart';
import 'package:life_pilot/point_record/model_point_record_account.dart';
import 'package:life_pilot/point_record/service_point_record.dart';
import 'package:life_pilot/utils/model_personal_data_scope.dart';

class ControllerPointRecordList extends SafeChangeNotifier {
  final ServicePointRecord service;
  final Duration requestTimeout;
  ControllerAuth? auth;
  ModelPersonalDataScope? _dataScopeKey;
  int _accountGeneration = 0;
  int _listRequest = 0;
  String? _loadingCategory;
  Future<void>? _loadFuture;

  String? _currentCategory;
  String get category => _currentCategory == null
      ? AccountCategory.personal.name
      : _currentCategory!;

  Future<void> setCategory(String category) async {
    if (notifierDisposed || _currentCategory == category) return;
    _currentCategory = category;
    accounts = [];

    await loadAccounts();
  }

  ControllerPointRecordList({
    required this.service,
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
    auth?.removeListener(_onAuthChanged);
    super.dispose();
  }

  static ModelPersonalDataScope _scopeKey(ControllerAuth? auth) =>
      ModelPersonalDataScope(
        account: auth?.currentAccount,
        storage: auth?.preferredStorage,
        revision: auth?.personalDataRevision ?? 0,
      );

  List<ModelPointRecordAccount> accounts = [];
  bool isLoading = false;
  Object? loadError;

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
    final completion = Completer<void>();
    final future = completion.future;
    // Publish before invoking the service or listeners; either can re-enter.
    _loadFuture = future;
    unawaited(
      _loadAccounts(user, requestedCategory, generation, request).then<void>(
        (_) => completion.complete(),
        onError: (Object error, StackTrace stack) =>
            completion.completeError(error, stack),
      ),
    );
    if (_isCurrent(generation) && request == _listRequest) notifyListeners();
    return future;
  }

  Future<void> _loadAccounts(
    String user,
    String requestedCategory,
    int generation,
    int request,
  ) async {
    try {
      // Bound only the read, not create/delete operations. Timeout releases
      // the shared request; its late response cannot publish or block retry.
      final loaded = await service
          .fetchAccounts(user: user, category: requestedCategory)
          .timeout(requestTimeout);
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
    _currentCategory = null;
    if (notify) notifyListeners();
  }

  Future<ModelPointRecordAccount> createAccount({
    required String name,
    String? eventId,
  }) async {
    if (notifierDisposed) throw StateError('Controller disposed');
    final generation = _accountGeneration;
    final modelPointRecordAccount = await service.createAccount(
      name: name,
      user: auth?.currentAccount ?? '',
      currency: null,
      category: category,
      eventId: eventId,
    );
    // ⭐ 統一來源：重新拉一次
    if (_isCurrent(generation)) await loadAccounts();
    return modelPointRecordAccount;
  }

  Future<void> deleteAccount({required String accountId}) async {
    if (notifierDisposed) return;
    final generation = _accountGeneration;
    await service.deleteAccount(accountId: accountId);
    if (_isCurrent(generation)) await loadAccounts();
  }

  Future<void> updateAccountImage(String accountId, XFile pickedFile) async {
    if (notifierDisposed) return;
    final generation = _accountGeneration;
    Uint8List bytes = await pickedFile.readAsBytes(); // Web / 手機都可以
    if (!_isCurrent(generation)) return;

    // 上傳圖片給後端，後端返回可訪問 URL
    final newImage = await service.uploadAccountImageBytesDirect(
      accountId,
      bytes,
    );

    if (!_isCurrent(generation)) return;
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
    if (notifierDisposed || deltaPoints == 0) return;
    final index = accounts.indexWhere((a) => a.id == accountId);
    if (index == -1) return;

    final old = accounts[index];
    accounts[index] = old.copyWith(points: old.points + deltaPoints);

    notifyListeners();
  }
}
