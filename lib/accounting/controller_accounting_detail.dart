import 'package:flutter/foundation.dart';
import 'package:life_pilot/controllers/auth/controller_auth.dart';
import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/accounting/model_accounting_detail.dart';
import 'package:life_pilot/accounting/model_accounting_account.dart';
import 'package:life_pilot/accounting/model_accounting_preview.dart';
import 'package:life_pilot/accounting/service_accounting.dart';
import 'package:life_pilot/core/enum.dart';

class ControllerAccountingDetail extends ChangeNotifier {
  final ServiceAccounting service;
  ControllerAuth? auth;
  final String accountId;
  num? currentExchangeRate;

  ControllerAccountingDetail(
      {required this.service,
      required this.auth,
      required this.accountId,
      this.currentExchangeRate});

  final String currentType = 'balance';

  List<ModelAccountingDetail> todayRecords = [];
  int todayTotal = 0;
  int? total;
  String? _currentCurrency;
  bool isLoading = false;

  Future<void> loadToday({String? inputAccountId}) async {
    if (isLoading) return;
    isLoading = true;
    notifyListeners();
    todayRecords = await service.fetchTodayRecords(
      accountId: inputAccountId ?? accountId,
      type: currentType,
    );

    _calculateTotals(inputAccountId: inputAccountId);

    isLoading = false;
    notifyListeners();
  }

  Future<void> _calculateTotals({String? inputAccountId}) async {
    if (todayRecords.isNotEmpty) {
      _currentCurrency = todayRecords.last.currency;
      currentExchangeRate = todayRecords.last.exchangeRate;
    }

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    todayTotal = todayRecords
        .where((r) =>
            r.currency == _currentCurrency && r.localTime.isAfter(todayStart))
        .fold(0, (s, r) => s + r.value);
    total = todayRecords[0].balance;
  }

  Future<ModelAccountingAccount?> findAccountByEventId(
      {required String eventId}) async {
    // 或者直接從 Supabase 查詢
    return await service.findAccountByEventId(
      eventId: eventId,
      user: auth?.currentAccount ?? constEmpty,
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
    final results = NLPService.parseMulti(text);

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
    await service.insertRecordsBatch(
      accountId: inputAccountId ?? accountId,
      type: currentType,
      records: previews,
      currency: previews.first.currency,
    );

    await loadToday(inputAccountId: inputAccountId ?? accountId);
  }

  // 更新單筆 accounting_detail
  Future<void> updateAccountingDetail(AccountingPreview preview) async {
    if (preview.id == null || preview.currency == null) {
      return;
    }
    // 呼叫後端 RPC
    await service.updateAccountingDetail(
      detailId: preview.id!,
      newValue: preview.value,
      newCurrency: preview.currency!,
      newDescription: preview.description,
    );
    await loadToday();
  }
}

