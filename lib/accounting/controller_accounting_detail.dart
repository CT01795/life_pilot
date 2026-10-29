import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/accounting/model_accounting_detail.dart';
import 'package:life_pilot/accounting/model_accounting_account.dart';
import 'package:life_pilot/accounting/model_accounting_preview.dart';
import 'package:life_pilot/accounting/service_accounting.dart';
import 'package:life_pilot/utils/safe_change_notifier.dart';
import 'package:life_pilot/utils/model_record_history.dart';
import 'package:life_pilot/utils/nlp.dart';
import 'package:life_pilot/utils/text_normalization.dart';

class ControllerAccountingDetail extends SafeChangeNotifier {
  final ServiceAccounting _service;
  ControllerAuth? auth;
  String? _accountKey;
  int _accountGeneration = 0;
  int _requestId = 0;
  final String accountId;
  final bool loadAllRecords;
  num? currentExchangeRate;

  ControllerAccountingDetail({
    required ServiceAccounting service,
    required this.auth,
    required this.accountId,
    this.loadAllRecords = false,
    this.currentExchangeRate,
  }) : _service = service,
       _accountKey = _scopeKey(auth) {
    auth?.addListener(_onAuthChanged);
  }

  final String currentType = 'balance';

  List<ModelAccountingDetail> todayRecords = [];
  num todayTotal = 0;
  num? total;
  String? _currentCurrency;
  bool isLoading = false;
  bool isLoadingMore = false;
  bool hasMore = false;
  DateTime? _loadedStartDate;

  static String _scopeKey(ControllerAuth? auth) =>
      '${normalizeText(auth?.currentAccount)}|${auth?.preferredStorage.name ?? ''}';

  bool _isCurrent(int generation, [int? request]) =>
      !notifierDisposed &&
      generation == _accountGeneration &&
      _accountKey == _scopeKey(auth) &&
      (request == null || request == _requestId);

  void _onAuthChanged() {
    final current = auth;
    if (current != null) updateAuth(current);
  }

  @override
  void dispose() {
    auth?.removeListener(_onAuthChanged);
    super.dispose();
  }

  void updateAuth(ControllerAuth nextAuth, {bool notify = true}) {
    if (notifierDisposed) return;
    final nextAccount = _scopeKey(nextAuth);
    if (!identical(auth, nextAuth)) {
      auth?.removeListener(_onAuthChanged);
      nextAuth.addListener(_onAuthChanged);
    }
    auth = nextAuth;
    if (_accountKey == nextAccount) return;
    _accountKey = nextAccount;
    _accountGeneration++;
    _requestId++;
    todayRecords = [];
    todayTotal = 0;
    total = null;
    isLoading = false;
    isLoadingMore = false;
    hasMore = false;
    _loadedStartDate = null;
    if (notify) notifyListeners();
  }

  Future<void> loadToday({String? inputAccountId}) async {
    if (notifierDisposed || isLoading || !_isCurrent(_accountGeneration)) {
      return;
    }
    final generation = _accountGeneration;
    final request = ++_requestId;
    isLoadingMore = false;
    isLoading = true;
    notifyListeners();
    final targetAccountId = inputAccountId ?? accountId;
    try {
      if (!_isCurrent(generation, request)) return;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      var loadedStartDate = loadAllRecords
          ? DateTime.fromMillisecondsSinceEpoch(0)
          : today.subtract(const Duration(days: 29));
      final loadedRecords = await _service.fetchRecordsPage(
        accountId: targetAccountId,
        type: currentType,
        dateFrom: loadedStartDate,
        dateTo: today,
        includeLatestFallback: !loadAllRecords,
        includeReservedRecords: true,
      );
      if (!_isCurrent(generation, request)) return;
      loadedStartDate = ModelRecordHistory.fallbackStart(
        loadedRecords,
        start: loadedStartDate,
        categoryOf: (record) => record.primaryCategory,
        dateOf: (record) => record.localTime,
      );
      final loadedHasMore =
          !loadAllRecords &&
          await _service.hasRecordsBefore(
            accountId: targetAccountId,
            type: currentType,
            before: loadedStartDate,
          );
      if (!_isCurrent(generation, request)) return;
      todayRecords = loadedRecords;
      _loadedStartDate = loadedStartDate;
      hasMore = loadedHasMore;
      _sortAndDeduplicate();
      _calculateTotals(inputAccountId: inputAccountId);
    } finally {
      if (_isCurrent(generation, request)) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMore({String? inputAccountId}) async {
    if (notifierDisposed ||
        isLoading ||
        isLoadingMore ||
        !hasMore ||
        _loadedStartDate == null ||
        !_isCurrent(_accountGeneration)) {
      return;
    }
    final generation = _accountGeneration;
    final request = _requestId;
    final before = _loadedStartDate!;
    isLoadingMore = true;
    notifyListeners();
    final targetAccountId = inputAccountId ?? accountId;
    try {
      if (!_isCurrent(generation, request)) return;
      final latestOlder = await _service.latestRecordDateBefore(
        accountId: targetAccountId,
        type: currentType,
        before: before,
      );
      if (!_isCurrent(generation, request)) return;
      if (latestOlder == null) {
        hasMore = false;
        return;
      }
      final dateTo = DateTime(
        latestOlder.year,
        latestOlder.month,
        latestOlder.day,
      );
      final dateFrom = dateTo.subtract(const Duration(days: 29));
      final loadedRecords = await _service.fetchRecordsPage(
        accountId: targetAccountId,
        type: currentType,
        dateFrom: dateFrom,
        dateTo: dateTo,
      );
      if (!_isCurrent(generation, request)) return;
      final loadedHasMore = await _service.hasRecordsBefore(
        accountId: targetAccountId,
        type: currentType,
        before: dateFrom,
      );
      if (!_isCurrent(generation, request)) return;
      todayRecords = [...todayRecords, ...loadedRecords];
      _loadedStartDate = dateFrom;
      _sortAndDeduplicate();
      hasMore = loadedHasMore;
    } finally {
      if (_isCurrent(generation, request)) {
        isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  void _sortAndDeduplicate() {
    todayRecords = ModelRecordHistory.ordered(
      todayRecords,
      idOf: (record) => record.id,
      dateOf: (record) => record.localTime,
    );
  }

  Future<void> _calculateTotals({String? inputAccountId}) async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    todayTotal = todayRecords
        .where(
          (r) =>
              r.currency == _currentCurrency && r.localTime.isAfter(todayStart),
        )
        .fold(0, (s, r) => s + r.value);
    total = todayRecords.isEmpty ? 0 : todayRecords.first.balance;
  }

  Future<ModelAccountingAccount?> findAccountByEventId({
    required String eventId,
  }) async {
    return await _service.findAccountByEventId(
      eventId: eventId,
      user: auth?.currentAccount ?? '',
    );
  }

  String? get currentCurrency {
    return _currentCurrency;
  }

  set currentCurrency(String? value) {
    _currentCurrency = value;
    notifyListeners();
  }

  List<AccountingPreview> parseFromSpeech(
    String text,
    String? currency,
    num? exchangeRate,
  ) {
    final results = NLP.parseForSubmission(text);

    return results
        .map(
          (r) => AccountingPreview(
            description: r.description,
            value: r.value,
            currency: currency,
            exchangeRate: exchangeRate,
          ),
        )
        .toList();
  }

  Future<void> commitRecords(
    List<AccountingPreview> previews, {
    String? inputAccountId,
  }) async {
    final generation = _accountGeneration;
    if (previews.isEmpty || !_isCurrent(generation)) return;
    await _service.insertRecordsBatch(
      accountId: inputAccountId ?? accountId,
      type: currentType,
      records: previews,
      currency: previews.first.currency,
    );

    if (!_isCurrent(generation)) return;
    await auth?.refreshSubscriptionUsage();
    if (!_isCurrent(generation)) return;

    await loadToday(inputAccountId: inputAccountId ?? accountId);
  }

  // 更新單筆 accounting_detail
  Future<void> updateAccountingDetail(AccountingPreview preview) async {
    final generation = _accountGeneration;
    if (!_isCurrent(generation) ||
        preview.id == null ||
        preview.currency == null) {
      return;
    }
    // 呼叫後端 RPC
    await _service.updateAccountingDetail(
      detailId: preview.id!,
      newValue: preview.value,
      newCurrency: preview.currency!,
      newDescription: preview.description,
      newDate: preview.date ?? DateTime.now(),
      newPrimaryCategory: preview.primaryCategory,
      newSecondaryCategory: preview.secondaryCategory,
    );
    if (!_isCurrent(generation)) return;
    await loadToday();
  }

  Future<void> deleteAccountingDetail(String detailId) async {
    final generation = _accountGeneration;
    if (!_isCurrent(generation)) return;
    await _service.deleteAccountingDetail(detailId: detailId);
    if (!_isCurrent(generation)) return;
    await auth?.refreshSubscriptionUsage();
    if (!_isCurrent(generation)) return;
    await loadToday();
  }
}
