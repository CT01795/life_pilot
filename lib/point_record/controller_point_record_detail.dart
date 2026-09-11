import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/point_record/model_point_record_detail.dart';
import 'package:life_pilot/point_record/model_point_record_account.dart';
import 'package:life_pilot/point_record/model_point_record_preview.dart';
import 'package:life_pilot/point_record/service_point_record.dart';
import 'package:life_pilot/utils/safe_change_notifier.dart';
import 'package:life_pilot/utils/nlp.dart';

class ControllerPointRecordDetail extends SafeChangeNotifier {
  final ServicePointRecord service;
  ControllerAuth? auth;
  String? _accountKey;
  int _accountGeneration = 0;
  final String accountId;

  ControllerPointRecordDetail({
    required this.service,
    required this.auth,
    required this.accountId,
  }) : _accountKey = auth?.currentAccount?.trim().toLowerCase();

  final String currentType = 'points';

  List<ModelPointRecordDetail> todayRecords = [];
  int todayTotal = 0;
  int? total;
  bool isLoading = false;
  bool isLoadingMore = false;
  bool hasMore = false;
  DateTime? _loadedStartDate;

  void updateAuth(ControllerAuth nextAuth, {bool notify = true}) {
    final nextAccount = nextAuth.currentAccount?.trim().toLowerCase();
    auth = nextAuth;
    if (_accountKey == nextAccount) return;
    _accountKey = nextAccount;
    _accountGeneration++;
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
    if (isLoading) return;
    final generation = _accountGeneration;
    isLoading = true;
    notifyListeners();
    final targetAccountId = inputAccountId ?? accountId;
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      var loadedStartDate = today.subtract(const Duration(days: 29));
      final loadedRecords = await service.fetchRecordsPage(
        accountId: targetAccountId,
        type: currentType,
        dateFrom: loadedStartDate,
        dateTo: today,
        includeLatestFallback: true,
      );
      if (generation != _accountGeneration) return;
      final regularRecords = loadedRecords
          .where((record) => record.primaryCategory != 'reserved')
          .toList();
      if (regularRecords.isNotEmpty &&
          regularRecords.every(
            (record) => record.localTime.isBefore(loadedStartDate),
          )) {
        loadedStartDate = regularRecords
            .map((record) => record.localTime)
            .reduce((a, b) => a.isAfter(b) ? a : b);
      }
      final loadedHasMore = await service.hasRecordsBefore(
        accountId: targetAccountId,
        type: currentType,
        before: loadedStartDate,
      );
      if (generation != _accountGeneration) return;
      todayRecords = loadedRecords;
      _loadedStartDate = loadedStartDate;
      hasMore = loadedHasMore;
      _sortAndDeduplicate();
      _calculateTotals(inputAccountId: inputAccountId);
    } finally {
      if (generation == _accountGeneration) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMore({String? inputAccountId}) async {
    if (isLoadingMore || !hasMore || _loadedStartDate == null) return;
    final generation = _accountGeneration;
    isLoadingMore = true;
    notifyListeners();
    final targetAccountId = inputAccountId ?? accountId;
    try {
      final latestOlder = await service.latestRecordDateBefore(
        accountId: targetAccountId,
        type: currentType,
        before: _loadedStartDate!,
      );
      if (generation != _accountGeneration) return;
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
      final loadedRecords = await service.fetchRecordsPage(
        accountId: targetAccountId,
        type: currentType,
        dateFrom: dateFrom,
        dateTo: dateTo,
      );
      if (generation != _accountGeneration) return;
      final loadedHasMore = await service.hasRecordsBefore(
        accountId: targetAccountId,
        type: currentType,
        before: dateFrom,
      );
      if (generation != _accountGeneration) return;
      todayRecords.addAll(loadedRecords);
      _loadedStartDate = dateFrom;
      _sortAndDeduplicate();
      hasMore = loadedHasMore;
    } finally {
      if (generation == _accountGeneration) {
        isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  void _sortAndDeduplicate() {
    final unique = <String, ModelPointRecordDetail>{};
    for (final record in todayRecords) {
      unique[record.id] = record;
    }
    todayRecords = unique.values.toList()
      ..sort((a, b) => b.localTime.compareTo(a.localTime));
  }

  void _calculateTotals({String? inputAccountId}) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    todayTotal = todayRecords
        .where((r) => r.localTime.isAfter(todayStart))
        .fold(0, (s, r) => s + r.value);
    total = todayRecords.isEmpty ? 0 : todayRecords.first.points;
  }

  Future<ModelPointRecordAccount?> findAccountByEventId(
      {required String eventId}) async {
    return await service.findAccountByEventId(
      eventId: eventId,
      user: auth?.currentAccount ?? '',
    );
  }

  List<PointRecordPreview> parseFromSpeech(String text) {
    final results = NLP.parseMulti(text);

    return results
        .where((result) => result.value == result.value.roundToDouble())
        .map(
          (r) => PointRecordPreview(
            description: r.description,
            value: r.value.toInt(),
          ),
        )
        .toList();
  }

  Future<void> commitRecords(List<PointRecordPreview> previews,
      {String? inputAccountId}) async {
    await service.insertRecordsBatch(
      accountId: inputAccountId ?? accountId,
      type: currentType,
      records: previews,
    );

    await auth?.refreshSubscriptionUsage();

    await loadToday(inputAccountId: inputAccountId ?? accountId);
  }

  Future<void> updatePointRecordDetail(PointRecordPreview preview) async {
    if (preview.id == null) return;

    await service.updatePointRecordDetail(
      detailId: preview.id!,
      newValue: preview.value,
      newDescription: preview.description,
      newDate: preview.date ?? DateTime.now(),
      newPrimaryCategory: preview.primaryCategory,
      newSecondaryCategory: preview.secondaryCategory,
    );
    await loadToday();
  }

  Future<void> deletePointRecordDetail(String detailId) async {
    await service.deletePointRecordDetail(detailId: detailId);
    await auth?.refreshSubscriptionUsage();
    await loadToday();
  }
}
