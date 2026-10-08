import 'package:flutter/material.dart';
import 'package:life_pilot/calendar/controller_calendar.dart';
import 'package:life_pilot/pages/home/model/dashboard/model_dashboard.dart';
import 'package:life_pilot/utils/api.dart';
import 'package:life_pilot/utils/app_navigator.dart';
import 'package:life_pilot/utils/enum.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:life_pilot/utils/safe_change_notifier.dart';
import 'package:life_pilot/auth/service_auth.dart';
import 'package:life_pilot/auth/auth_session_sync.dart';
import 'package:life_pilot/utils/const.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:life_pilot/subscription/model_subscription_usage.dart';
import 'package:life_pilot/subscription/service_subscription.dart';
import 'package:life_pilot/local_storage/local_data_store.dart';

enum AccountValidationResult { valid, unavailable, signedOut }

class ControllerAuth extends SafeChangeNotifier {
  ControllerCalendar? controllerCalendar;
  final ModelDashboard? modelDashboard;
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<String?>? _externalAuthAccountSubscription;
  StreamSubscription<void>? _passwordRecoveryLinkSubscription;
  Timer? _quotaFreePeriodTimer;
  Timer? _accountValidationTimer;
  DateTime? _lastAccountValidationAt;
  Future<AccountValidationResult>? _accountValidationInFlight;
  ControllerAuth({this.controllerCalendar, this.modelDashboard});

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;
    _listenAuthState();
    _listenExternalAuthAccount();
    _passwordRecoveryLinkSubscription = ServiceAuth.passwordRecoveryLinks
        .listen((_) {
          ServiceAuth.consumePasswordRecoveryLink();
          _update(() => _currentPage = AuthPage.resetPassword);
        });
    if (ServiceAuth.consumePasswordRecoveryLink()) {
      _currentPage = AuthPage.resetPassword;
    }
  }

  void _listenAuthState() {
    _authSubscription = supabase.auth.onAuthStateChange.listen((data) async {
      logger.i('Auth Event: ${data.event}');
      logger.i('Recovery User Present: ${data.session?.user != null}');
      logger.i('Current User Present: ${supabase.auth.currentUser != null}');
      if (data.event == AuthChangeEvent.passwordRecovery) {
        // A recovery link may be opened while another account is still shown
        // in this tab. Synchronize the recovered session first so no data from
        // the previous account remains behind the reset-password page.
        await checkLoginStatus();
        _update(() {
          _currentPage = AuthPage.resetPassword;
        });
      } else if (data.event == AuthChangeEvent.signedOut) {
        _handleSignedOut();
      }
    });
  }

  void _listenExternalAuthAccount() {
    _externalAuthAccountSubscription = externalAuthAccountChanges.listen((
      account,
    ) {
      if (!_isLoggedIn) return;
      if (account != null && account.isEmpty) return;
      final current = _currentAccount?.toLowerCase();
      if (account != null && account == current) return;
      logger.i('Session account changed in another browser tab.');
      _handleSignedOut();
    });
  }

  // -------------------- 狀態 --------------------
  bool _isLoading = true;
  bool _isLoggedIn = false;
  bool _isAnonymous = false;
  String? _currentAccount;
  String _accountType = 'personal';
  String _registrationAccountType = 'personal';
  SubscriptionSnapshot _subscription = SubscriptionSnapshot.free;
  bool _quotaFreePeriodActive = false;
  int? _quotaFreePeriodEndingInDays;
  DateTime? _quotaFreePeriodEndsAt;
  DataStorageLocation _preferredStorage = DataStorageLocation.cloud;
  bool _hasStorageChoice = false;
  int _personalDataRevision = 0;
  AuthPage _currentPage = AuthPage.login;

  bool get isLoading => _isLoading;
  bool get isLoggedIn => _isLoggedIn;
  bool get isAnonymous => _isAnonymous;
  String? get currentAccount => _currentAccount;
  String get accountType => _accountType;
  String get registrationAccountType => _registrationAccountType;
  bool get isVendor => !isSysAdmin && _accountType == 'vendor';
  SubscriptionSnapshot get subscription => _subscription;
  bool get quotaFreePeriodActive => _quotaFreePeriodActive;
  int? get quotaFreePeriodEndingInDays => _quotaFreePeriodEndingInDays;
  DateTime? get quotaFreePeriodEndsAt => _quotaFreePeriodEndsAt;
  bool get isPlus => isSysAdmin || _subscription.isPlus;
  bool get canUseLocalStorage {
    if (isSysAdmin || _quotaFreePeriodActive) return true;
    final now = DateTime.now();
    final hasActiveLocalEntitlement = _subscription.entitlements.any(
      (entitlement) =>
          entitlement.storagePlan == 'local' && entitlement.endsAt.isAfter(now),
    );
    final periodEnd = _subscription.currentPeriodEnd;
    final hasActiveLocalPlan =
        _subscription.isPlus &&
        _subscription.storagePlan == 'local' &&
        (periodEnd == null || periodEnd.isAfter(now));
    return hasActiveLocalPlan || hasActiveLocalEntitlement;
  }

  void _syncLocalCreatePermission() {
    final account = _currentAccount;
    if (account == null) return;
    LocalDataStore.instance.setCreateAllowed(
      account,
      isSysAdmin || _quotaFreePeriodActive || canUseLocalStorage,
    );
  }

  DataStorageLocation get preferredStorage => _preferredStorage;
  bool get storesNewDataLocally =>
      _preferredStorage == DataStorageLocation.local;
  bool get hasStorageChoice => _hasStorageChoice;
  int get personalDataRevision => _personalDataRevision;
  bool get hasServerAdminRole =>
      supabase.auth.currentUser?.appMetadata['role'] == AuthConstants.adminRole;
  bool get isSysAdmin => hasServerAdminRole;
  AuthPage get currentPage => _currentPage;

  Future<void> refreshSubscriptionUsage({bool notify = true}) async {
    if (!_isLoggedIn || _isAnonymous) return;
    try {
      _quotaFreePeriodActive = await _loadQuotaFreePeriodActive();
      _subscription = await _loadSubscriptionUsage();
      _syncLocalCreatePermission();
      if (notify) notifyListeners();
    } catch (error, stackTrace) {
      logger.e(
        'Failed to refresh subscription usage',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<SubscriptionSnapshot> _loadSubscriptionUsage() async {
    final cloud = await ServiceSubscription().fetchMyUsage();
    final account = _currentAccount;
    final presented =
        _preferredStorage != DataStorageLocation.local || account == null
        ? _withCloudPresentation(cloud)
        : await _withLocalUsage(cloud);
    return isSysAdmin || _quotaFreePeriodActive
        ? _withUnlimitedUsage(presented)
        : presented;
  }

  Future<bool> _loadQuotaFreePeriodActive() async {
    try {
      final periods = await ServiceSubscription().fetchQuotaFreePeriods();
      _scheduleQuotaFreePeriodRefresh(periods);
      final activePeriod = periods
          .where((period) => period.isActive)
          .firstOrNull;
      _quotaFreePeriodEndsAt = activePeriod?.endsAt;
      _quotaFreePeriodEndingInDays = null;
      if (activePeriod?.reminderDays case final reminderDays?) {
        final seconds = activePeriod!.endsAt
            .difference(DateTime.now())
            .inSeconds;
        final remainingDays = (seconds / Duration.secondsPerDay).ceil();
        if (remainingDays <= reminderDays) {
          _quotaFreePeriodEndingInDays = remainingDays.clamp(0, reminderDays);
        }
      }
      return activePeriod != null;
    } catch (error, stackTrace) {
      logger.e(
        'Failed to load no-limit promotion status',
        error: error,
        stackTrace: stackTrace,
      );
      _quotaFreePeriodEndingInDays = null;
      _quotaFreePeriodEndsAt = null;
      return false;
    }
  }

  void _scheduleQuotaFreePeriodRefresh(List<QuotaFreePeriod> periods) {
    _quotaFreePeriodTimer?.cancel();
    final now = DateTime.now();
    final boundaries =
        periods
            .where((period) => period.enabled)
            .expand((period) => [period.startsAt, period.endsAt])
            .where((boundary) => boundary.isAfter(now))
            .toList(growable: false)
          ..sort();
    if (boundaries.isEmpty) return;
    final boundaryDelay =
        boundaries.first.difference(now) + const Duration(seconds: 1);
    final delay = boundaryDelay > const Duration(days: 1)
        ? const Duration(days: 1)
        : boundaryDelay;
    _quotaFreePeriodTimer = Timer(
      delay,
      () => unawaited(refreshSubscriptionUsage()),
    );
  }

  SubscriptionSnapshot _withUnlimitedUsage(SubscriptionSnapshot base) =>
      base.copyWithUsage({
        for (final entry in base.usage.entries)
          entry.key: SubscriptionUsage(
            resource: entry.value.resource,
            used: entry.value.used,
            quota: -1,
          ),
      });

  SubscriptionSnapshot _withCloudPresentation(SubscriptionSnapshot base) {
    final now = DateTime.now();
    final cloudEntitlements =
        base.entitlements
            .where(
              (entitlement) =>
                  entitlement.storagePlan == 'cloud' &&
                  entitlement.endsAt.isAfter(now),
            )
            .toList(growable: false)
          ..sort((a, b) => b.endsAt.compareTo(a.endsAt));
    final cloudEntitlement = cloudEntitlements.firstOrNull;
    final basePeriodEnd = base.currentPeriodEnd;
    final baseCloudPlus =
        base.isPlus &&
        base.storagePlan == 'cloud' &&
        (basePeriodEnd == null || basePeriodEnd.isAfter(now));

    if (!baseCloudPlus && cloudEntitlement == null) {
      return SubscriptionSnapshot(
        plan: 'free',
        usage: base.usage,
        status: 'inactive',
        storagePlan: 'cloud',
        lastDataActivityAt: base.lastDataActivityAt,
        downgradeGraceEndsAt: base.downgradeGraceEndsAt,
        entitlements: base.entitlements,
      );
    }

    return SubscriptionSnapshot(
      plan: 'plus',
      usage: base.usage,
      status: baseCloudPlus ? base.status : 'active',
      currentPeriodEnd:
          cloudEntitlement?.endsAt ?? (baseCloudPlus ? basePeriodEnd : null),
      cancelAtPeriodEnd: baseCloudPlus ? base.cancelAtPeriodEnd : false,
      storagePlan: 'cloud',
      quotaMultiplier: cloudEntitlement?.multiplier ?? base.quotaMultiplier,
      quarterlyPricePaidTwd:
          cloudEntitlement?.pricePaidTwd ?? base.quarterlyPricePaidTwd,
      pricingVersionName:
          cloudEntitlement?.versionName ?? base.pricingVersionName,
      pricingEffectiveAt:
          cloudEntitlement?.effectiveAt ?? base.pricingEffectiveAt,
      lastDataActivityAt: base.lastDataActivityAt,
      downgradeGraceEndsAt: base.downgradeGraceEndsAt,
      entitlements: base.entitlements,
    );
  }

  Future<SubscriptionSnapshot> _withLocalUsage(
    SubscriptionSnapshot base,
  ) async {
    final account = _currentAccount;
    if (account == null) return base;

    final resources = [
      TableNames.calendarEvents,
      TableNames.accountingDetail,
      TableNames.pointRecordDetail,
      TableNames.memoryTrace,
      'game_grammar',
      'game_sentence',
      'game_translation',
      TableNames.gameSocialScenarios,
    ];
    final counts = await LocalDataStore.instance.countByResources(
      owner: account,
      resources: resources,
    );
    int count(String resource) => counts[resource] ?? 0;
    final recommendedEventUsage = base['recommended_events'];
    final recommendedAttractionUsage = base['recommended_attractions'];
    final localUsage = <String, SubscriptionUsage>{
      'calendar_events': SubscriptionUsage(
        resource: 'calendar_events',
        used: count(TableNames.calendarEvents),
        quota: -1,
      ),
      'accounting_detail': SubscriptionUsage(
        resource: 'accounting_detail',
        used: count(TableNames.accountingDetail),
        quota: -1,
      ),
      'point_record_detail': SubscriptionUsage(
        resource: 'point_record_detail',
        used: count(TableNames.pointRecordDetail),
        quota: -1,
      ),
      'memory_trace': SubscriptionUsage(
        resource: 'memory_trace',
        used: count(TableNames.memoryTrace),
        quota: -1,
      ),
      'game_questions': SubscriptionUsage(
        resource: 'game_questions',
        used:
            count('game_grammar') +
            count('game_sentence') +
            count('game_translation') +
            count(TableNames.gameSocialScenarios),
        quota: -1,
      ),
      'recommended_events': ?recommendedEventUsage,
      'recommended_attractions': ?recommendedAttractionUsage,
    };

    final localEntitlements =
        base.entitlements
            .where((entitlement) => entitlement.storagePlan == 'local')
            .toList(growable: false)
          ..sort((a, b) => b.endsAt.compareTo(a.endsAt));
    final localEntitlement = localEntitlements.firstOrNull;
    final baseIsLocal = base.storagePlan == 'local';

    return SubscriptionSnapshot(
      plan: baseIsLocal || localEntitlement != null ? 'plus' : base.plan,
      usage: localUsage,
      status: baseIsLocal || localEntitlement != null ? 'active' : base.status,
      currentPeriodEnd:
          localEntitlement?.endsAt ??
          (baseIsLocal ? base.currentPeriodEnd : null),
      cancelAtPeriodEnd: baseIsLocal ? base.cancelAtPeriodEnd : false,
      storagePlan: 'local',
      quotaMultiplier:
          localEntitlement?.multiplier ??
          (baseIsLocal ? base.quotaMultiplier : 1),
      quarterlyPricePaidTwd:
          localEntitlement?.pricePaidTwd ??
          (baseIsLocal ? base.quarterlyPricePaidTwd : null),
      pricingVersionName:
          localEntitlement?.versionName ??
          (baseIsLocal ? base.pricingVersionName : null),
      pricingEffectiveAt:
          localEntitlement?.effectiveAt ??
          (baseIsLocal ? base.pricingEffectiveAt : null),
      lastDataActivityAt: base.lastDataActivityAt,
      downgradeGraceEndsAt: base.downgradeGraceEndsAt,
      entitlements: base.entitlements,
    );
  }

  Future<void> setPreferredStorage(DataStorageLocation location) async {
    final account = _currentAccount;
    if (account == null || _isAnonymous) return;
    await LocalDataStore.instance.setPreferredLocation(account, location);
    _preferredStorage = location;
    _hasStorageChoice = true;
    _personalDataRevision++;
    notifyListeners();
    await refreshSubscriptionUsage();
    modelDashboard?.switchAccount(account);
    controllerCalendar?.clearAll();
    try {
      await Future.wait<void>([
        if (modelDashboard != null) ...[
          modelDashboard!.loadEventCities(account),
          modelDashboard!.loadPlaceCities(account),
          modelDashboard!.refreshAll(account: account),
        ],
        if (controllerCalendar != null)
          controllerCalendar!.loadCalendarEvents(month: DateTime.now()),
      ]);
    } catch (error, stackTrace) {
      logger.e(
        'Failed to refresh data after changing storage location',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> refreshAfterPersonalDataCleanup() async {
    final account = _currentAccount;
    await refreshSubscriptionUsage(notify: false);
    _personalDataRevision++;
    modelDashboard?.switchAccount(account);
    controllerCalendar?.clearAll();
    notifyListeners();
    if (account == null) return;
    try {
      await Future.wait<void>([
        if (modelDashboard != null) ...[
          modelDashboard!.loadEventCities(account),
          modelDashboard!.loadPlaceCities(account),
          modelDashboard!.refreshAll(account: account),
        ],
        if (controllerCalendar != null)
          controllerCalendar!.loadCalendarEvents(month: DateTime.now()),
      ]);
    } catch (error, stackTrace) {
      logger.e(
        'Failed to refresh data after personal data cleanup',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  final Map<String, String> _registerMap = {AuthConstants.email: ''};

  Map<String, String> get registerMap => Map.unmodifiable(_registerMap);

  // =========================================================
  // 🔹 統一狀態更新入口
  void _update(VoidCallback fn, {bool notify = true}) {
    fn();
    if (notify) notifyListeners();
  }

  void _handleSignedOut() {
    final signedOutAccount = _currentAccount;
    if (_currentAccount != null && !_isAnonymous) {
      _registerMap[AuthConstants.email] = _currentAccount!;
    }

    _update(() {
      _isLoading = false;
      _isLoggedIn = false;
      _isAnonymous = false;
      _currentAccount = null;
      _accountType = 'personal';
      _subscription = SubscriptionSnapshot.free;
      _quotaFreePeriodActive = false;
      _quotaFreePeriodEndingInDays = null;
      _quotaFreePeriodEndsAt = null;
      _preferredStorage = DataStorageLocation.cloud;
      _hasStorageChoice = false;
      _currentPage = AuthPage.login;
      _lastAccountValidationAt = null;
    }, notify: false);

    modelDashboard?.switchAccount(null);
    controllerCalendar?.clearAll();
    _accountValidationTimer?.cancel();
    _accountValidationTimer = null;
    AppNavigator.returnToRoot();
    if (signedOutAccount != null) {
      LocalDataStore.instance.clearCreatePermission(signedOutAccount);
    }
    notifyListeners();
  }

  /// Verifies that the authenticated user still exists on the Auth server.
  ///
  /// Deleting a user in Supabase does not immediately remove the cached JWT
  /// from another open device or browser tab. A remote `getUser` request is
  /// therefore required before that stale screen can be dismissed. Temporary
  /// network failures deliberately keep the current screen and session.
  Future<AccountValidationResult> validateCurrentAccount({bool force = false}) {
    if (!_isLoggedIn || _isAnonymous) {
      return Future.value(AccountValidationResult.valid);
    }

    final inFlight = _accountValidationInFlight;
    if (inFlight != null) return inFlight;

    final now = DateTime.now();
    final lastValidation = _lastAccountValidationAt;
    if (!force &&
        lastValidation != null &&
        now.difference(lastValidation) < const Duration(seconds: 10)) {
      _accountValidationTimer ??= Timer(
        const Duration(seconds: 10) - now.difference(lastValidation),
        () {
          _accountValidationTimer = null;
          unawaited(validateCurrentAccount(force: true));
        },
      );
      return Future.value(AccountValidationResult.valid);
    }

    _accountValidationTimer?.cancel();
    _accountValidationTimer = null;
    final validation = _validateCurrentAccountRemotely();
    _accountValidationInFlight = validation;
    return validation.whenComplete(() {
      if (identical(_accountValidationInFlight, validation)) {
        _accountValidationInFlight = null;
      }
    });
  }

  Future<AccountValidationResult> _validateCurrentAccountRemotely() async {
    _lastAccountValidationAt = DateTime.now();
    final localUser = supabase.auth.currentUser;
    if (localUser == null) {
      _handleSignedOut();
      return AccountValidationResult.signedOut;
    }

    try {
      final response = await supabase.auth.getUser();
      final remoteUser = response.user;
      if (remoteUser == null || remoteUser.id != localUser.id) {
        await _signOutInvalidAccount();
        return AccountValidationResult.signedOut;
      }
      return AccountValidationResult.valid;
    } on AuthException catch (error, stackTrace) {
      if (_isInvalidRemoteAccount(error)) {
        logger.w(
          'The signed-in account no longer exists or its session is invalid.',
          error: error,
          stackTrace: stackTrace,
        );
        await _signOutInvalidAccount();
        return AccountValidationResult.signedOut;
      }
      logger.w(
        'Unable to validate the signed-in account right now.',
        error: error,
        stackTrace: stackTrace,
      );
      return AccountValidationResult.unavailable;
    } catch (error, stackTrace) {
      logger.w(
        'Unable to validate the signed-in account right now.',
        error: error,
        stackTrace: stackTrace,
      );
      return AccountValidationResult.unavailable;
    }
  }

  bool _isInvalidRemoteAccount(AuthException error) {
    final code = error.code?.toLowerCase();
    final statusCode = error.statusCode;
    final message = error.message.toLowerCase();
    return code == 'user_not_found' ||
        code == 'session_not_found' ||
        code == 'invalid_jwt' ||
        code == 'user_banned' ||
        statusCode == '401' ||
        message.contains('user from sub claim in jwt does not exist') ||
        message.contains('user not found') ||
        message.contains('session not found');
  }

  Future<void> _signOutInvalidAccount() async {
    try {
      await supabase.auth.signOut(scope: SignOutScope.local);
    } catch (error, stackTrace) {
      logger.w(
        'Failed to clear the invalid Supabase session normally.',
        error: error,
        stackTrace: stackTrace,
      );
    }
    if (_isLoggedIn || _currentAccount != null) {
      _handleSignedOut();
    }
  }

  // =========================================================
  // 🧩 檢查登入狀態
  Future<void> checkLoginStatus() async {
    _update(() => _isLoading = true, notify: false);

    try {
      final user = supabase.auth.currentUser;
      final oldAccount = _currentAccount; // 👈 比對用

      // 有時在剛登入／註冊完畢會延遲更新；
      _update(() {
        _isLoggedIn = user != null;
        _isAnonymous = user?.isAnonymous ?? false;
        _currentAccount = _isAnonymous ? AuthConstants.guest : user?.email;
        _accountType = user?.userMetadata?['account_type'] == 'vendor'
            ? 'vendor'
            : 'personal';
        if (_currentPage != AuthPage.resetPassword) {
          _currentPage = _isLoggedIn ? AuthPage.pageMain : AuthPage.login;
        }
      }, notify: false);

      if (_isLoggedIn && !_isAnonymous) {
        final storedLocation = await LocalDataStore.instance.preferredLocation(
          _currentAccount!,
        );
        _hasStorageChoice = storedLocation != null;
        _preferredStorage = storedLocation ?? DataStorageLocation.cloud;
        if (_preferredStorage == DataStorageLocation.local) {
          LocalDataStore.instance.setCreateAllowed(_currentAccount!, false);
        }
      }

      // 🧹 若帳號不同，清空並重新載入日曆資料
      if (!_isLoggedIn) {
        controllerCalendar?.clearAll();
        modelDashboard?.switchAccount(null);
      } else if (_currentAccount != oldAccount) {
        controllerCalendar?.clearAll();
        modelDashboard?.switchAccount(_currentAccount);
        if (_preferredStorage == DataStorageLocation.cloud) {
          await controllerCalendar?.syncCompletedEventReminders();
        }
        unawaited(_loadCalendarAfterLogin());
      }

      if (_isLoggedIn && !_isAnonymous) {
        unawaited(_refreshSubscriptionAfterStartup());
        unawaited(validateCurrentAccount(force: true));
      }
    } catch (error, stackTrace) {
      logger.e(
        'Failed to restore login state',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _update(() => _isLoading = false);
    }
  }

  Future<void> _loadCalendarAfterLogin() async {
    try {
      await controllerCalendar?.loadCalendarEvents(month: DateTime.now());
    } catch (error, stackTrace) {
      logger.e(
        'Failed to load calendar after restoring login state',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _refreshSubscriptionAfterStartup() async {
    try {
      final promotionActive = await _loadQuotaFreePeriodActive();
      if (notifierDisposed || !_isLoggedIn || _isAnonymous) return;
      _quotaFreePeriodActive = promotionActive;
      final loaded = await _loadSubscriptionUsage();
      if (notifierDisposed || !_isLoggedIn || _isAnonymous) return;
      _subscription = loaded;
      _syncLocalCreatePermission();
      notifyListeners();
    } catch (error, stackTrace) {
      logger.e(
        'Failed to load subscription usage after startup',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  // =========================================================
  // 🔐 通用登入邏輯（登入/匿名登入/註冊共用）
  Future<String?> _authenticate(Future<String?> Function() action) async {
    _update(() => _isLoading = true, notify: false);
    try {
      final error = await action();
      if (error != null) return error;
      await checkLoginStatus();
      return null;
    } catch (e, st) {
      logger.e('Auth Error: $e\n$st');
      return ErrorFields.loginError;
    } finally {
      _update(() => _isLoading = false, notify: false);
    }
  }

  // -------------------- 登入 --------------------
  Future<String?> login({required String email, required String password}) =>
      _authenticate(() => ServiceAuth.login(email: email, password: password));

  // -------------------- 註冊 --------------------
  Future<String?> register({required String email, required String password}) =>
      _authenticate(
        () => ServiceAuth.register(
          email: email,
          password: password,
          accountType: _registrationAccountType,
        ),
      );

  // -------------------- 登出 --------------------
  Future<String?> logout() async {
    _update(() => _isLoading = true, notify: false);

    final error = await ServiceAuth.logout();
    if (error != null) {
      _update(() => _isLoading = false);
      return error;
    }

    if (_currentAccount != null && !_isAnonymous) {
      _registerMap[AuthConstants.email] = _currentAccount!;
    }

    _update(() {
      _isLoggedIn = false;
      _isAnonymous = false;
      _currentAccount = null;
      _accountType = 'personal';
      _subscription = SubscriptionSnapshot.free;
      _quotaFreePeriodActive = false;
      _quotaFreePeriodEndingInDays = null;
      _quotaFreePeriodEndsAt = null;
      _preferredStorage = DataStorageLocation.cloud;
      _hasStorageChoice = false;
      _currentPage = AuthPage.login;
      _lastAccountValidationAt = null;
    }, notify: false);

    modelDashboard?.switchAccount(null);
    controllerCalendar?.clearAll(); // 🧹 登出也清除資料
    _accountValidationTimer?.cancel();
    _accountValidationTimer = null;

    _update(() => _isLoading = false);
    return null;
  }

  // -------------------- 忘記密碼 --------------------
  Future<String?> resetPassword({required String email}) =>
      ServiceAuth.resetPassword(email: email);

  // -------------------- 頁面切換 --------------------
  void goToPage(AuthPage page, {String? email}) {
    _update(() {
      if (email != null) _registerMap[AuthConstants.email] = email;
      _currentPage = page;
    });
  }

  void goToRegister({String? email, String accountType = 'personal'}) {
    _registrationAccountType = accountType == 'vendor' ? 'vendor' : 'personal';
    goToPage(AuthPage.register, email: email);
  }

  void goToResetPassword({String? email}) =>
      goToPage(AuthPage.resetPassword, email: email);
  void goBackToLogin({String? email}) => goToPage(AuthPage.login, email: email);

  @override
  void dispose() {
    _authSubscription?.cancel();
    _externalAuthAccountSubscription?.cancel();
    _passwordRecoveryLinkSubscription?.cancel();
    _quotaFreePeriodTimer?.cancel();
    _accountValidationTimer?.cancel();
    super.dispose();
  }
}
