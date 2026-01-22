import 'package:flutter/foundation.dart';
import 'package:life_pilot/controllers/accounting/controller_accounting_account.dart';
import 'package:life_pilot/controllers/auth/controller_auth.dart';
import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/models/accounting/model_accounting.dart';
import 'package:life_pilot/models/accounting/model_accounting_account.dart';
import 'package:life_pilot/models/accounting/model_accounting_preview.dart';
import 'package:life_pilot/services/service_accounting.dart';

class ControllerAccounting extends ChangeNotifier {
  final ServiceAccounting service;
  ControllerAuth? auth;
  final String accountId;
  final ControllerAccountingAccount accountController;
  num? currentExchangeRate;
  String? _currentCurrency;

  String get currentType => accountController.currentType;

  String? get currentCurrency =>
      _currentCurrency ?? accountController.mainCurrency;

  set currentCurrency(String? value) {
    _currentCurrency = value;
    notifyListeners();
  }

  ControllerAccounting(
      {required this.service,
      required this.auth,
      required this.accountId,
      required this.accountController,
      this.currentExchangeRate});

  int todayTotal = 0;

  void _recalculateTodayTotal(String? currency) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    todayTotal = todayRecords
        .where((r) => r.localTime.isAfter(todayStart) && r.currency == currency)
        .fold(0, (sum, r) => sum + r.value);
  }

  ModelAccountingAccount get account =>
      accountController.getAccountById(accountId);

  List<ModelAccounting> todayRecords = [];

  Future<void> loadToday() async {
    todayRecords = await service.fetchTodayRecords(
      accountId: account.id,
      type: currentType,
    );

    if (todayRecords.isNotEmpty) {
      currentCurrency = todayRecords.last.currency;
      currentExchangeRate = todayRecords.last.exchangeRate;
    } else {
      currentCurrency = accountController.mainCurrency;
    }

    _recalculateTodayTotal(account.currency);
    notifyListeners();
  }

  Future<List<AccountingPreview>> parseFromSpeech(
      String text, String? currency, num? exchangeRate) async {
    final results = NLPService.parseMulti(text);

    return results
        .map(
          (r) => AccountingPreview(
              description: r.description,
              value: r.points,
              currency: currency,
              exchangeRate: exchangeRate),
        )
        .toList();
  }

  Future<void> commitRecords(
      List<AccountingPreview> previews, String? currency) async {
    await service.insertRecordsBatch(
        accountId: account.id,
        type: currentType,
        records: previews,
        currency: currency,
        currentType: currentType);

    await loadToday();
  }

  // 更新單筆 accounting_detail
  Future<void> updateAccountingDetail({
    required String? recordId,
    required int newValue,
    required String? newCurrency,
    required String newDescription,
  }) async {
    if (recordId == null || newCurrency == null) {
      return;
    }
    // 呼叫後端 RPC
    await service.updateAccountingDetail(
      detailId: recordId,
      newValue: newValue,
      newCurrency: newCurrency,
      newDescription: newDescription,
    );

    // 更新本地 todayRecords
    /*final index = todayRecords.indexWhere((r) => r.id == recordId);
    if (index != -1) {
      todayRecords[index] = todayRecords[index].copyWith(
        value: newValue,
        currency: newCurrency,
        description: newDescription,
      );
      notifyListeners();
    }*/
  }
}

class NLPService {
  static List<AccountingParsedResult> parseMulti(String text) {
    final results = <AccountingParsedResult>[];

    // ① 加 / 扣 + 數字（阿拉伯 or 中文）
    final regex = RegExp(
      r'([^，。,]*?)\s*(加|扣|\+|-)\s*(\d+|[一二三四五六七八九十兩]+)\s*(分|點|元)?',
    );

    for (final m in regex.allMatches(text)) {
      String action = m.group(1)?.trim() ?? constEmpty;
      final op = m.group(2)!;
      if (action.isEmpty) {
        action = op == "加" || op == "+" ? "Save" : "Spend";
      }

      final rawNumber = m.group(3)!;

      int? value = int.tryParse(rawNumber) ?? ChineseNumber.parse(rawNumber);

      if (value == null) continue;

      final isAdd = op == '加' || op == '+';

      results.add(
        AccountingParsedResult(
          action,
          isAdd ? value : -value,
        ),
      );
    }

    return results;
  }
}

class AccountingParsedResult {
  final String description;
  final int points;

  AccountingParsedResult(this.description, this.points);
}
