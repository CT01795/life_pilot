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
  final ControllerAccountingAccount accountController;
  final String accountId;
  final String currentType = 'balance';
  num? currentExchangeRate;
  String? _currentCurrency;

  String? get currentCurrency {
    if (_currentCurrency != null) {
      return _currentCurrency;
    }
    final account = getAccount(accountId);
    return account.currency;
  }

  int totalValue(String? inputAccountId) {
    final account = getAccount(inputAccountId ?? accountId);
    return account.balance;
  }

  ModelAccountingAccount getAccount(String? inputAccountId) {
    return accountController.getAccountById(inputAccountId ?? accountId);
  }

  set currentCurrency(String? value) {
    _currentCurrency = value;
    notifyListeners();
  }

  ControllerAccounting(
      {required this.service,
      required this.accountController,
      required this.auth,
      required this.accountId,
      this.currentExchangeRate});

  int todayTotal = 0;

  List<ModelAccounting> todayRecords = [];

  Future<void> loadToday({String? inputAccountId}) async {
    todayRecords = await service.fetchTodayRecords(
      accountId: inputAccountId ?? accountId,
      type: currentType,
    );

    if (todayRecords.isNotEmpty) {
      currentCurrency = todayRecords.last.currency;
      currentExchangeRate = todayRecords.last.exchangeRate;
    } else {
      final account = getAccount(inputAccountId ?? accountId);
      currentCurrency = account.currency;
    }

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    todayTotal = todayRecords
        .where((r) =>
            r.currency == currentCurrency && r.localTime.isAfter(todayStart))
        .fold(0, (s, r) => s + r.value);
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

  Future<void> commitRecords(List<AccountingPreview> previews, String? currency,
      {String? inputAccountId}) async {
    await service.insertRecordsBatch(
        accountId: inputAccountId ?? accountId,
        type: currentType,
        records: previews,
        currency: currency,);

    await loadToday(inputAccountId: inputAccountId ?? accountId);
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
  }
}

class NLPService {
  // ① 加 / 扣 + 數字（阿拉伯 or 中文）
  static final regex = RegExp(
    r'([^，。,]*?)\s*(加|扣|\+|-)\s*(\d+|[一二三四五六七八九十兩]+)\s*(分|點|元)?',
  );
  static List<AccountingParsedResult> parseMulti(String text) {
    final results = <AccountingParsedResult>[];

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
