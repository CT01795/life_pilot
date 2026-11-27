import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/point_record/model_point_record_detail.dart';
import 'package:life_pilot/point_record/model_point_record_account.dart';
import 'package:life_pilot/point_record/model_point_record_preview.dart';
import 'package:life_pilot/point_record/service_point_record.dart';
import 'package:life_pilot/utils/safe_change_notifier.dart';
import 'package:life_pilot/utils/refresh_request_coordinator.dart';
import 'package:life_pilot/utils/model_record_history.dart';
import 'package:life_pilot/utils/model_record_history_page.dart';
import 'package:life_pilot/utils/nlp.dart';
import 'package:life_pilot/utils/model_personal_data_scope.dart';
import 'package:life_pilot/utils/record_categories.dart';

class ControllerPointRecordDetail extends SafeChangeNotifier {
  final ServicePointRecord service;
  ControllerAuth? auth;
  ModelPersonalDataScope? _accountKey;
  int _accountGeneration = 0;
  int _requestId = 0;
  RefreshRequestCoordinator _loads = RefreshRequestCoordinator();
  String? _loadAccountId;
  final String accountId;
  final void Function()? onRecordsChanged;

  ControllerPointRecordDetail({
    required this.service,
    required this.auth,
    required this.accountId,
    this.onRecordsChanged,
  }) : _accountKey = _scopeKey(auth) {
    auth?.addListener(_onAuthChanged);
  }

  final String currentType = 'points';

  List<ModelPointRecordDetail> todayRecords = [];
  int todayTotal = 0;
  int? total;
  bool isLoading = false;
  bool isLoadingMore = false;
  bool hasMore = false;
  DateTime? _nextRecordDate;

  static ModelPersonalDataScope _scopeKey(ControllerAuth? auth) =>
      ModelPersonalDataScope(
        account: auth?.currentAccount,
        storage: auth?.preferredStorage,
        revision: auth?.personalDataRevision ?? 0,
      );

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
    _loads = RefreshRequestCoordinator();
    _loadAccountId = null;
    todayRecords = [];
    todayTotal = 0;
    total = null;
    isLoading = false;
    isLoadingMore = false;
    hasMore = false;
    _nextRecordDate = null;
    if (notify) notifyListeners();
  }

  Future<void> loadToday({String? inputAccountId, bool force = false}) {
    final generation = _accountGeneration;
    if (!_isCurrent(generation)) return Future<void>.value();
    final targetAccountId = inputAccountId ?? accountId;
    if (_loadAccountId != targetAccountId) {
      _loads = RefreshRequestCoordinator();
      _loadAccountId = targetAccountId;
    }
    final loads = _loads;
    if (force && loads.isRunning) _requestId++;
    return loads.run(() async {
      if (!_isCurrent(generation) || !identical(_loads, loads)) return;
      await _loadToday(generation, inputAccountId: inputAccountId);
    }, force: force);
  }

  Future<void> _loadToday(int generation, {String? inputAccountId}) async {
    final request = ++_requestId;
    isLoadingMore = false;
    isLoading = true;
    notifyListeners();
    final targetAccountId = inputAccountId ?? accountId;
    try {
      if (!_isCurrent(generation, request)) return;
      final window = ModelRecordHistory.windowEndingAt(DateTime.now());
      final page = await service.fetchRecordsPage(
        accountId: targetAccountId,
        type: currentType,
        dateFrom: window.start,
        dateTo: window.end,
        includeLatestFallback: true,
        includeReservedRecords: true,
      );
      if (!_isCurrent(generation, request)) return;
      todayRecords = page.rows;
      _nextRecordDate = page.nextDate;
      hasMore = page.hasMore;
      _sortAndDeduplicate();
      _calculateTotals(inputAccountId: inputAccountId);
    } catch (_) {
      // Read errors belong to the account/storage and request that started them.
      if (_isCurrent(generation, request)) rethrow;
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
        _nextRecordDate == null ||
        !_isCurrent(_accountGeneration)) {
      return;
    }
    final generation = _accountGeneration;
    final request = _requestId;
    final nextDate = _nextRecordDate!;
    isLoadingMore = true;
    notifyListeners();
    final targetAccountId = inputAccountId ?? accountId;
    try {
      if (!_isCurrent(generation, request)) return;
      final page = await readNextNonDuplicateHistoryPage(
        cursor: nextDate,
        existingIds: todayRecords.map((record) => record.id),
        idOf: (record) => record.id,
        shouldContinue: () => _isCurrent(generation, request),
        read: (cursor) {
          final window = ModelRecordHistory.windowEndingAt(cursor);
          return service.fetchRecordsPage(
            accountId: targetAccountId,
            type: currentType,
            dateFrom: window.start,
            dateTo: window.end,
            // Reserved point rows are already pinned on the first page.
            includeReservedRecords: false,
          );
        },
      );
      if (!_isCurrent(generation, request) || page == null) return;
      todayRecords = [...todayRecords, ...page.rows];
      _nextRecordDate = page.nextDate;
      _sortAndDeduplicate();
      hasMore = page.hasMore;
    } catch (_) {
      if (_isCurrent(generation, request)) rethrow;
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
      pinnedFirst: (record) =>
          record.primaryCategory == RecordCategories.reserved,
    );
  }

  void _calculateTotals({String? inputAccountId}) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    todayTotal = todayRecords
        .where((r) => r.localTime.isAfter(todayStart))
        .fold(0, (s, r) => s + r.value);
    total = todayRecords.isEmpty ? 0 : todayRecords.first.points;
  }

  Future<ModelPointRecordAccount?> findAccountByEventId({
    required String eventId,
  }) async {
    return await service.findAccountByEventId(
      eventId: eventId,
      user: auth?.currentAccount ?? '',
    );
  }

  List<PointRecordPreview> parseFromSpeech(String text) {
    final results = NLP.parseForSubmission(text, integersOnly: true);

    return results
        .map(
          (r) => PointRecordPreview(
            description: r.description,
            value: r.value.toInt(),
          ),
        )
        .toList();
  }

  Future<void> commitRecords(
    List<PointRecordPreview> previews, {
    String? inputAccountId,
  }) async {
    final generation = _accountGeneration;
    if (previews.isEmpty || !_isCurrent(generation)) return;
    await service.insertRecordsBatch(
      accountId: inputAccountId ?? accountId,
      type: currentType,
      records: previews,
    );

    if (!_isCurrent(generation)) return;
    if (inputAccountId == null || inputAccountId == accountId) {
      onRecordsChanged?.call();
    }
    await auth?.refreshSubscriptionUsage();
    if (!_isCurrent(generation)) return;

    await loadToday(inputAccountId: inputAccountId ?? accountId, force: true);
  }

  Future<void> updatePointRecordDetail(PointRecordPreview preview) async {
    final generation = _accountGeneration;
    if (!_isCurrent(generation) || preview.id == null) return;

    await service.updatePointRecordDetail(
      detailId: preview.id!,
      newValue: preview.value,
      newDescription: preview.description,
      newDate: preview.date ?? DateTime.now(),
      newPrimaryCategory: preview.primaryCategory,
      newSecondaryCategory: preview.secondaryCategory,
    );
    if (!_isCurrent(generation)) return;
    onRecordsChanged?.call();
    await loadToday(force: true);
  }

  Future<void> deletePointRecordDetail(String detailId) async {
    final generation = _accountGeneration;
    if (!_isCurrent(generation)) return;
    await service.deletePointRecordDetail(detailId: detailId);
    if (!_isCurrent(generation)) return;
    onRecordsChanged?.call();
    await auth?.refreshSubscriptionUsage();
    if (!_isCurrent(generation)) return;
    await loadToday(force: true);
  }
}
