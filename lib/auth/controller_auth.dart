import 'package:flutter/material.dart';
import 'package:life_pilot/calendar/controller_calendar.dart';
import 'package:life_pilot/pages/home/controller_dashboard.dart';
import 'package:life_pilot/utils/supabase.dart';
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
import 'package:life_pilot/auth/auth_session_guard.dart';
import 'package:life_pilot/utils/text_normalization.dart';

enum AccountValidationResult { valid, unavailable, signedOut }

class ControllerAuth extends SafeChangeNotifier {
  ControllerCalendar? controllerCalendar;
  final ControllerDashboard? dashboardController;
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<String?>? _externalAuthAccountSubscription;
  StreamSubscription<void>? _passwordRecoveryLinkSubscription;
  StreamSubscription<AuthSessionFailure>? _invalidSessionSubscription;
  Timer? _quotaFreePeriodTimer;
  Timer? _accountValidationTimer;
  DateTime? _lastAccountValidationAt;
  AccountValidationResult? _lastAccountValidationResult;
  bool get accountVerificationBlocked =>
      _lastAccountValidationResult != AccountValidationResult.valid;
  bool get accountVerificationFailed =>
      _lastAccountValidationResult == AccountValidationResult.unavailable;
  Future<AccountValidationResult>? _accountValidationInFlight;
  Future<AccountValidationResult>? _queuedAccountValidation;
  int _accountValidationScope = 0;
  int _subscriptionRequest = 0;
  Future<void>? _invalidAccountSignOutInFlight;
  final LocalDataStore _localStore;
  ControllerAuth({
    this.controllerCalendar,
    this.dashboardController,
    LocalDataStore? localStore,
  }) : _localStore = localStore ?? LocalDataStore.instance;

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;
    _listenAuthState();
    _listenExternalAuthAccount();
    _invalidSessionSubscription = AuthSessionGuard.failures.listen((failure) {
      if (!_isLoggedIn || _isAnonymous) return;
      logger.w(
        'Authentication failure reported by ${failure.source} '
        '(HTTP ${failure.statusCode}, code ${failure.code}).',
      );
      unawaited(_signOutInvalidAccount());
    });
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
  bool get subscriptionConfigurationMissing =>
      !isSysAdmin && _subscription.configurationMissing;
  bool get quotaFreePeriodActive => _quotaFreePeriodActive;
  int? get quotaFreePeriodEndingInDays => _quotaFreePeriodEndingInDays;
  DateTime? get quotaFreePeriodEndsAt => _quotaFreePeriodEndsAt;
  bool get isPlus => isSysAdmin || _subscription.isPlus;
  bool get hasActiveLocalSubscription {
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

  bool get hasLocalFreePlan =>
      _accountType != 'vendor' && _subscription.localFreeVersionName != null;

  bool get canUseLocalStorage =>
      isSysAdmin ||
      _quotaFreePeriodActive ||
      hasActiveLocalSubscription ||
      hasLocalFreePlan;

  void _syncLocalCreatePermission() {
    final account = _currentAccount;
    if (account == null) return;
    final localConfigured =
        !subscriptionConfigurationMissing || hasActiveLocalSubscription;
    _localStore.setCreateAllowed(
      account,
      localConfigured && canUseLocalStorage,
    );
    _localStore.setDeleteAllowed(account, localConfigured);
    _localStore.setWriteCheck(account, () => canUseLocalStorage);
  }

  DataStorageLocation get preferredStorage => _preferredStorage;
  bool get storesNewDataLocally =>
      _preferredStorage == DataStorageLocation.local;
  int get personalDataRevision => _personalDataRevision;
  bool get hasServerAdminRole =>
      supabase.auth.currentUser?.appMetadata['role'] == AuthConstants.adminRole;
  bool get isSysAdmin => hasServerAdminRole;
  AuthPage get currentPage => _currentPage;

  Future<void> refreshSubscriptionUsage({bool notify = true}) async {
    if (!_isLoggedIn || _isAnonymous || notifierDisposed) return;
    final request = ++_subscriptionRequest;
    final owner = _currentAccount;
    final storage = _preferredStorage;
    final userId = supabase.auth.currentUser?.id;
    bool current() =>
        !notifierDisposed &&
        request == _subscriptionRequest &&
        _isLoggedIn &&
        !_isAnonymous &&
        owner == _currentAccount &&
        storage == _preferredStorage &&
        userId == supabase.auth.currentUser?.id;
    try {
      final loaded = await _loadSubscriptionUsage(current);
      if (!current()) return;
      _quotaFreePeriodActive = _applyQuotaFreePeriods(loaded.periods);
      _subscription =
          (isSysAdmin ||
              (_quotaFreePeriodActive && !loaded.snapshot.configurationMissing))
          ? _withUnlimitedUsage(loaded.snapshot)
          : loaded.snapshot;
      _syncLocalCreatePermission();
      if (notify) notifyListeners();
    } catch (error, stackTrace) {
      if (!current()) return;
      _markSubscriptionUnverified();
      if (notify) notifyListeners();
      logger.e(
        'Failed to refresh subscription usage',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<({SubscriptionSnapshot snapshot, List<QuotaFreePeriod> periods})>
  _loadSubscriptionUsage(bool Function() current) async {
    final loadingAccount = _currentAccount;
    final loadingStorage = _preferredStorage;
    final selectedStoragePlan = _preferredStorage == DataStorageLocation.local
        ? 'local'
        : 'cloud';
    final base = await ServiceSubscription().fetchMyUsage(
      storagePlan: selectedStoragePlan,
    );
    if (!current()) {
      throw StateError('Subscription request scope changed');
    }
    if (base.configurationMissing && !isSysAdmin) {
      return (snapshot: base, periods: base.promotionPeriods!);
    }
    var presented = base;
    if (loadingStorage != DataStorageLocation.local || loadingAccount == null) {
      presented = _withCloudPresentation(base);
    } else {
      try {
        presented = await _withLocalUsage(base);
      } catch (error, stackTrace) {
        // Usage counts are presentation data. A local counting failure must
        // not discard a successfully verified subscription entitlement.
        logger.e(
          'Failed to calculate local subscription usage',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
    return (snapshot: presented, periods: base.promotionPeriods!);
  }

  bool _applyQuotaFreePeriods(List<QuotaFreePeriod> periods) {
    _scheduleQuotaFreePeriodRefresh(periods);
    final account = normalizeText(_currentAccount);
    final activePeriod = periods
        .where(
          (period) =>
              period.isActive &&
              (period.targetAccounts.isEmpty ||
                  (account.isNotEmpty &&
                      period.targetAccounts.contains(account))),
        )
        .firstOrNull;
    _quotaFreePeriodEndsAt = activePeriod?.endsAt;
    _quotaFreePeriodEndingInDays = null;
    if (activePeriod?.reminderDays case final reminderDays?) {
      final seconds = activePeriod!.endsAt.difference(DateTime.now()).inSeconds;
      final remainingDays = (seconds / Duration.secondsPerDay).ceil();
      if (remainingDays <= reminderDays) {
        _quotaFreePeriodEndingInDays = remainingDays.clamp(0, reminderDays);
      }
    }
    return activePeriod != null;
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
        localFreeVersionName: base.localFreeVersionName,
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
      localFreeVersionName: base.localFreeVersionName,
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
    final counts = await _localStore.countByResources(
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
      'calendar_shares': ?base['calendar_shares'],
      'image_bytes': ?base['image_bytes'],
    };

    final now = DateTime.now();
    final localEntitlements =
        base.entitlements
            .where(
              (entitlement) =>
                  entitlement.storagePlan == 'local' &&
                  entitlement.endsAt.isAfter(now),
            )
            .toList(growable: false)
          ..sort((a, b) => b.endsAt.compareTo(a.endsAt));
    final localEntitlement = localEntitlements.firstOrNull;
    final basePeriodEnd = base.currentPeriodEnd;
    final baseIsActiveLocal =
        base.isPlus &&
        base.storagePlan == 'local' &&
        (basePeriodEnd == null || basePeriodEnd.isAfter(now));

    if (!baseIsActiveLocal && localEntitlement == null) {
      final freeVersion = base.localFreeVersionName;
      if (freeVersion != null) {
        return SubscriptionSnapshot(
          plan: 'free',
          status: 'active',
          storagePlan: 'local',
          pricingVersionName: freeVersion,
          localFreeVersionName: freeVersion,
          usage: localUsage,
          lastDataActivityAt: base.lastDataActivityAt,
          downgradeGraceEndsAt: base.downgradeGraceEndsAt,
          entitlements: base.entitlements,
        );
      }
      return SubscriptionSnapshot(
        plan: 'free',
        usage: {
          for (final entry in localUsage.entries)
            entry.key:
                entry.value.isUnlimited &&
                    const {
                      'calendar_events',
                      'accounting_detail',
                      'point_record_detail',
                      'memory_trace',
                      'game_questions',
                    }.contains(entry.key)
                ? SubscriptionUsage(
                    resource: entry.value.resource,
                    used: entry.value.used,
                    quota: 0,
                  )
                : entry.value,
        },
        status: 'inactive',
        storagePlan: 'local',
        lastDataActivityAt: base.lastDataActivityAt,
        downgradeGraceEndsAt: base.downgradeGraceEndsAt,
        entitlements: base.entitlements,
      );
    }

    return SubscriptionSnapshot(
      plan: 'plus',
      usage: localUsage,
      status: baseIsActiveLocal ? base.status : 'active',
      currentPeriodEnd:
          localEntitlement?.endsAt ??
          (baseIsActiveLocal ? basePeriodEnd : null),
      cancelAtPeriodEnd: baseIsActiveLocal ? base.cancelAtPeriodEnd : false,
      storagePlan: 'local',
      quotaMultiplier:
          localEntitlement?.multiplier ??
          (baseIsActiveLocal ? base.quotaMultiplier : 1),
      quarterlyPricePaidTwd:
          localEntitlement?.pricePaidTwd ??
          (baseIsActiveLocal ? base.quarterlyPricePaidTwd : null),
      pricingVersionName:
          localEntitlement?.versionName ??
          (baseIsActiveLocal ? base.pricingVersionName : null),
      pricingEffectiveAt:
          localEntitlement?.effectiveAt ??
          (baseIsActiveLocal ? base.pricingEffectiveAt : null),
      lastDataActivityAt: base.lastDataActivityAt,
      downgradeGraceEndsAt: base.downgradeGraceEndsAt,
      entitlements: base.entitlements,
      localFreeVersionName: base.localFreeVersionName,
    );
  }

  Future<void> setPreferredStorage(DataStorageLocation location) async {
    final account = _currentAccount;
    if (account == null || _isAnonymous) return;
    await _localStore.setPreferredLocation(account, location);
    _preferredStorage = location;
    _personalDataRevision++;
    _markSubscriptionUnverified(pending: true);
    dashboardController?.switchAccount(
      account,
      includeCloudShares: location == DataStorageLocation.cloud,
    );
    notifyListeners();
    await refreshSubscriptionUsage();
    controllerCalendar?.clearAll();
    try {
      await Future.wait<void>([
        if (dashboardController != null) ...[
          dashboardController!.loadRecommendationCities(account),
          dashboardController!.refreshAll(account: account),
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
    dashboardController?.switchAccount(
      account,
      includeCloudShares: _preferredStorage == DataStorageLocation.cloud,
    );
    controllerCalendar?.clearAll();
    notifyListeners();
    if (account == null) return;
    try {
      await Future.wait<void>([
        if (dashboardController != null) ...[
          dashboardController!.loadRecommendationCities(account),
          dashboardController!.refreshAll(account: account),
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
    if (!_isLoggedIn && _currentAccount == null && !_isLoading) return;
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
      _currentPage = AuthPage.login;
      _lastAccountValidationAt = null;
      _lastAccountValidationResult = null;
      _accountValidationInFlight = null;
      _queuedAccountValidation = null;
      _accountValidationScope++;
      _subscriptionRequest++;
    }, notify: false);

    dashboardController?.switchAccount(null);
    controllerCalendar?.clearAll();
    _accountValidationTimer?.cancel();
    _accountValidationTimer = null;
    AppNavigator.returnToRoot();
    if (signedOutAccount != null) {
      _localStore.clearCreatePermission(signedOutAccount);
    }
    notifyListeners();
  }

  /// Verifies that the authenticated user still exists on the Auth server.
  ///
  /// Deleting a user in Supabase does not immediately remove the cached JWT
  /// from another open device or browser tab. A remote `getUser` request is
  /// therefore required before access is allowed. Temporary failures retain
  /// the session, but do not count as successful validation.
  Future<AccountValidationResult> validateCurrentAccount({bool force = false}) {
    if (notifierDisposed) {
      return Future.value(AccountValidationResult.unavailable);
    }
    if (!_isLoggedIn || _isAnonymous) {
      return Future.value(AccountValidationResult.valid);
    }

    final queued = _queuedAccountValidation;
    if (queued != null) return queued;
    final inFlight = _accountValidationInFlight;
    final scope = _accountValidationScope;
    if (inFlight != null) {
      if (!force) return inFlight;
      final userId = supabase.auth.currentUser?.id;
      late final Future<AccountValidationResult> followUp;
      followUp = inFlight.then<AccountValidationResult>((result) {
        if (identical(_queuedAccountValidation, followUp)) {
          _queuedAccountValidation = null;
        }
        if (result == AccountValidationResult.signedOut) return result;
        if (notifierDisposed ||
            scope != _accountValidationScope ||
            userId != supabase.auth.currentUser?.id) {
          return AccountValidationResult.unavailable;
        }
        return validateCurrentAccount(force: true);
      });
      _queuedAccountValidation = followUp;
      return followUp;
    }

    final now = DateTime.now();
    final lastValidation = _lastAccountValidationAt;
    if (!force &&
        lastValidation != null &&
        now.difference(lastValidation) < const Duration(hours: 2)) {
      _accountValidationTimer ??= Timer(
        const Duration(hours: 2) - now.difference(lastValidation),
        () {
          _accountValidationTimer = null;
          unawaited(validateCurrentAccount(force: true));
        },
      );
      return Future.value(
        _lastAccountValidationResult ?? AccountValidationResult.unavailable,
      );
    }

    _accountValidationTimer?.cancel();
    _accountValidationTimer = null;
    final userId = supabase.auth.currentUser?.id;
    final retrying = accountVerificationFailed;
    if (retrying) _lastAccountValidationResult = null;
    bool current() =>
        !notifierDisposed &&
        scope == _accountValidationScope &&
        userId == supabase.auth.currentUser?.id;
    final validation = _validateCurrentAccountRemotely(current).then((result) {
      if (result != AccountValidationResult.signedOut && !current()) {
        return AccountValidationResult.unavailable;
      }
      if (result != AccountValidationResult.signedOut &&
          _queuedAccountValidation == null) {
        final changed = _lastAccountValidationResult != result;
        _lastAccountValidationResult = result;
        if (changed) notifyListeners();
      }
      return result;
    });
    late final Future<AccountValidationResult> tracked;
    tracked = validation.whenComplete(() {
      if (identical(_accountValidationInFlight, tracked)) {
        _accountValidationInFlight = null;
      }
    });
    _accountValidationInFlight = tracked;
    if (retrying) notifyListeners();
    return tracked.then<AccountValidationResult>((result) {
      if (result == AccountValidationResult.signedOut || !current()) {
        return result;
      }
      // Initial session restoration must also wait for the queued check,
      // rather than opening protected views on the superseded response.
      final next = _queuedAccountValidation;
      if (next != null) return next;
      return result;
    });
  }

  Future<AccountValidationResult> _validateCurrentAccountRemotely(
    bool Function() current,
  ) async {
    _lastAccountValidationAt = DateTime.now();
    final localUser = supabase.auth.currentUser;
    if (localUser == null) {
      _handleSignedOut();
      return AccountValidationResult.signedOut;
    }

    try {
      final recoveredSession = supabase.auth.currentSession;
      if (recoveredSession?.isExpired ?? false) {
        await supabase.auth.refreshSession();
        if (!current()) {
          return AccountValidationResult.unavailable;
        }
      }
      final response = await supabase.auth.getUser();
      if (!current()) {
        return AccountValidationResult.unavailable;
      }
      final remoteUser = response.user;
      if (remoteUser == null || remoteUser.id != localUser.id) {
        await _signOutInvalidAccount();
        return AccountValidationResult.signedOut;
      }
      try {
        final disabled = await supabase.rpc(
          'is_my_life_pilot_account_disabled',
        );
        if (!current()) {
          return AccountValidationResult.unavailable;
        }
        if (disabled == true) {
          await _signOutInvalidAccount();
          return AccountValidationResult.signedOut;
        }
        if (disabled != false) {
          throw const FormatException('Invalid account verification response');
        }
      } on PostgrestException catch (error) {
        if (error.code == 'PT401' && error.message == 'user_banned') {
          if (!current()) {
            return AccountValidationResult.unavailable;
          }
          await _signOutInvalidAccount();
          return AccountValidationResult.signedOut;
        }
        rethrow;
      }
      return AccountValidationResult.valid;
    } on AuthException catch (error, stackTrace) {
      if (!current()) {
        return AccountValidationResult.unavailable;
      }
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

  Future<void> _signOutInvalidAccount() {
    final inFlight = _invalidAccountSignOutInFlight;
    if (inFlight != null) return inFlight;

    final future = _performInvalidAccountSignOut();
    _invalidAccountSignOutInFlight = future;
    return future.whenComplete(() {
      if (identical(_invalidAccountSignOutInFlight, future)) {
        _invalidAccountSignOutInFlight = null;
      }
    });
  }

  Future<void> _performInvalidAccountSignOut() async {
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
        if (oldAccount != _currentAccount) {
          _lastAccountValidationAt = null;
          _lastAccountValidationResult = null;
          _accountValidationInFlight = null;
          _queuedAccountValidation = null;
          _accountValidationScope++;
          _subscriptionRequest++;
        }
        _accountType = user?.userMetadata?['account_type'] == 'vendor'
            ? 'vendor'
            : 'personal';
        if (_currentPage != AuthPage.resetPassword) {
          _currentPage = _isLoggedIn ? AuthPage.pageMain : AuthPage.login;
        }
      }, notify: false);

      if (_isLoggedIn && !_isAnonymous) {
        final storedLocation = await _localStore.preferredLocation(
          _currentAccount!,
        );
        _preferredStorage =
            storedLocation ??
            (_accountType == 'personal' &&
                    user?.appMetadata['default_storage'] == 'local'
                ? DataStorageLocation.local
                : DataStorageLocation.cloud);
        if (_preferredStorage == DataStorageLocation.local) {
          _localStore.setCreateAllowed(_currentAccount!, false);
        }
      }

      final accountChanged = _currentAccount != oldAccount;

      // Change the local scope immediately, but do not start protected reads
      // until the recovered session has been verified.
      if (!_isLoggedIn) {
        controllerCalendar?.clearAll();
        dashboardController?.switchAccount(null);
      } else if (accountChanged) {
        controllerCalendar?.clearAll();
        dashboardController?.switchAccount(
          _currentAccount,
          includeCloudShares: _preferredStorage == DataStorageLocation.cloud,
        );
      }

      if (_isLoggedIn && !_isAnonymous) {
        if (accountChanged) {
          _markSubscriptionUnverified(pending: true);
        }
        final validation = await validateCurrentAccount(force: true);
        if (validation != AccountValidationResult.valid) return;
      }

      if (_isLoggedIn && accountChanged) {
        if (_preferredStorage == DataStorageLocation.cloud) {
          await controllerCalendar?.syncCompletedEventReminders();
        }
        unawaited(_loadCalendarAfterLogin());
      }

      if (_isLoggedIn && !_isAnonymous) {
        unawaited(_refreshSubscriptionAfterStartup());
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

  Future<void> _refreshSubscriptionAfterStartup() => refreshSubscriptionUsage();

  void _markSubscriptionUnverified({bool pending = false}) {
    _subscription = SubscriptionSnapshot(
      plan: 'unverified',
      usage: const {},
      status: pending ? 'verification_pending' : 'verification_unavailable',
      storagePlan: _preferredStorage.name,
    );
    _quotaFreePeriodActive = false;
    _quotaFreePeriodEndingInDays = null;
    _quotaFreePeriodEndsAt = null;
    _syncLocalCreatePermission();
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

  // -------------------- 登出 --------------------
  Future<String?> logout() async {
    _update(() => _isLoading = true, notify: false);

    final error = await ServiceAuth.logout();
    if (error != null) {
      _update(() => _isLoading = false);
      return error;
    }

    // Supabase normally emits signedOut before signOut() completes. Let that
    // event perform the single shared teardown. If a platform omits the event,
    // fall back to the same idempotent path here instead of clearing the
    // Provider tree a second time.
    if (_isLoggedIn || _currentAccount != null || _isLoading) {
      _handleSignedOut();
    }
    return null;
  }

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
    _invalidSessionSubscription?.cancel();
    _quotaFreePeriodTimer?.cancel();
    _accountValidationTimer?.cancel();
    super.dispose();
  }
}
