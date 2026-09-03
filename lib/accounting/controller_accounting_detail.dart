import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/accounting/model_accounting_detail.dart';
import 'package:life_pilot/accounting/model_accounting_account.dart';
import 'package:life_pilot/accounting/model_accounting_preview.dart';
import 'package:life_pilot/accounting/service_accounting.dart';
import 'package:life_pilot/utils/safe_change_notifier.dart';
import 'package:life_pilot/utils/nlp.dart';

class ControllerAccountingDetail extends SafeChangeNotifier {
  final ServiceAccounting _service;
  ControllerAuth? auth;
  final String accountId;
  final bool loadAllRecords;
  num? currentExchangeRate;

  ControllerAccountingDetail(
      {required ServiceAccounting service,
      required this.auth,
      required this.accountId,
      this.loadAllRecords = false,
      this.currentExchangeRate})
      : _service = service;

  final String currentType = 'balance';

  List<ModelAccountingDetail> todayRecords = [];
  int todayTotal = 0;
  int? total;
  String? _currentCurrency;
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
      _loadedStartDate = loadAllRecords
          ? DateTime.fromMillisecondsSinceEpoch(0)
          : today.subtract(const Duration(days: 29));
      todayRecords = await _service.fetchRecordsPage(
        accountId: targetAccountId,
        type: currentType,
        dateFrom: _loadedStartDate!,
        dateTo: today,
        includeLatestFallback: !loadAllRecords,
        includeReservedRecords: true,
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
      hasMore = !loadAllRecords &&
          await _service.hasRecordsBefore(
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
      final latestOlder = await _service.latestRecordDateBefore(
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
      todayRecords.addAll(await _service.fetchRecordsPage(
        accountId: targetAccountId,
        type: currentType,
        dateFrom: dateFrom,
        dateTo: dateTo,
      ));
      _loadedStartDate = dateFrom;
      _sortAndDeduplicate();
      hasMore = await _service.hasRecordsBefore(
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
    final unique = <String, ModelAccountingDetail>{};
    for (final record in todayRecords) {
      unique[record.id] = record;
    }
    todayRecords = unique.values.toList()
      ..sort((a, b) => b.localTime.compareTo(a.localTime));
  }

  Future<void> _calculateTotals({String? inputAccountId}) async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    todayTotal = todayRecords
        .where((r) =>
            r.currency == _currentCurrency && r.localTime.isAfter(todayStart))
        .fold(0, (s, r) => s + r.value);
    total = todayRecords.isEmpty ? 0 : todayRecords.first.balance;
  }

  Future<ModelAccountingAccount?> findAccountByEventId(
      {required String eventId}) async {
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
      String text, String? currency, num? exchangeRate) {
    final results = NLP.parseMulti(text);

    return results
        .map(
          (r) => AccountingPreview(
              description: r.description,
              value: r.value,
              currency: currency,
              exchangeRate: exchangeRate),
        )
        .toList();
  }

  Future<void> commitRecords(List<AccountingPreview> previews,
      {String? inputAccountId}) async {
    await _service.insertRecordsBatch(
      accountId: inputAccountId ?? accountId,
      type: currentType,
      records: previews,
      currency: previews.first.currency,
    );

    await auth?.refreshSubscriptionUsage();

    await loadToday(inputAccountId: inputAccountId ?? accountId);
  }

  // 更新單筆 accounting_detail
  Future<void> updateAccountingDetail(AccountingPreview preview) async {
    if (preview.id == null || preview.currency == null) {
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
    await loadToday();
  }

  Future<void> deleteAccountingDetail(String detailId) async {
    await _service.deleteAccountingDetail(detailId: detailId);
    await auth?.refreshSubscriptionUsage();
    await loadToday();
  }
}
