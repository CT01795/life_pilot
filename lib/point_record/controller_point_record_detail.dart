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
  final String accountId;

  ControllerPointRecordDetail({
    required this.service,
    required this.auth,
    required this.accountId,
  });

  final String currentType = 'points';

  List<ModelPointRecordDetail> todayRecords = [];
  int todayTotal = 0;
  int? total;
  bool isLoading = false;
  bool isLoadingMore = false;
  bool hasMore = false;
  DateTime? _loadedStartDate;

  Future<void> loadToday({String? inputAccountId}) async {
    if (isLoading) return;
    isLoading = true;
    notifyListeners();
    final targetAccountId = inputAccountId ?? accountId;
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      _loadedStartDate = today.subtract(const Duration(days: 29));
      todayRecords = await service.fetchRecordsPage(
        accountId: targetAccountId,
        type: currentType,
        dateFrom: _loadedStartDate!,
        dateTo: today,
        includeLatestFallback: true,
      );
      _sortAndDeduplicate();
      final regularRecords = todayRecords
          .where((record) => record.primaryCategory != 'reserved')
          .toList();
      if (regularRecords.isNotEmpty &&
          regularRecords.every(
            (record) => record.localTime.isBefore(_loadedStartDate!),
          )) {
        _loadedStartDate = regularRecords
            .map((record) => record.localTime)
            .reduce((a, b) => a.isAfter(b) ? a : b);
      }
      hasMore = await service.hasRecordsBefore(
        accountId: targetAccountId,
        type: currentType,
        before: _loadedStartDate!,
      );
      _calculateTotals(inputAccountId: inputAccountId);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore({String? inputAccountId}) async {
    if (isLoadingMore || !hasMore || _loadedStartDate == null) return;
    isLoadingMore = true;
    notifyListeners();
    final targetAccountId = inputAccountId ?? accountId;
    try {
      final latestOlder = await service.latestRecordDateBefore(
        accountId: targetAccountId,
        type: currentType,
        before: _loadedStartDate!,
      );
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
      todayRecords.addAll(await service.fetchRecordsPage(
        accountId: targetAccountId,
        type: currentType,
        dateFrom: dateFrom,
        dateTo: dateTo,
      ));
      _loadedStartDate = dateFrom;
      _sortAndDeduplicate();
      hasMore = await service.hasRecordsBefore(
        accountId: targetAccountId,
        type: currentType,
        before: dateFrom,
      );
    } finally {
      isLoadingMore = false;
      notifyListeners();
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
        .map(
          (r) => PointRecordPreview(
            description: r.description,
            value: r.value,
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
}
