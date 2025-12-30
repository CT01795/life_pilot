import 'package:flutter/foundation.dart';
import 'package:life_pilot/controllers/accounting/controller_accounting_account.dart';
import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/models/accounting/model_accounting.dart';
import 'package:life_pilot/models/accounting/model_accounting_account.dart';
import 'package:life_pilot/models/accounting/model_accounting_preview.dart';
import 'package:life_pilot/services/service_accounting.dart';

class ControllerAccounting extends ChangeNotifier {
  final ServiceAccounting service;
  final String accountId;
  final ControllerAccountingAccount accountController;

  ControllerAccounting(
    this.service,
    this.accountId,
    this.accountController,
  );

  int todayTotal = 0;

  void _recalculateTodayTotal() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    todayTotal = todayRecords
        .where((r) => r.localTime.isAfter(todayStart))
        .fold(0, (sum, r) => sum + r.value);
  }

  ModelAccountingAccount get account =>
      accountController.getAccountById(accountId);

  String currentType = 'balance'; // points | balance

  List<ModelAccounting> todayRecords = [];

  Future<void> loadToday() async {
    todayRecords = await service.fetchTodayRecords(
      accountId: account.id,
      type: currentType,
    );
    _recalculateTodayTotal();
    notifyListeners();
  }

  Future<List<AccountingPreview>> parseFromSpeech(String text) async {
    final results = NLPService.parseMulti(text);

    return results
        .map(
          (r) => AccountingPreview(
            description: r.description,
            value: r.points,
          ),
        )
        .toList();
  }

  Future<void> commitRecords(List<AccountingPreview> previews) async {
    await service.insertRecordsBatch(
      accountId: account.id,
      type: currentType,
      records: previews,
    );

    await loadToday();
  }

  Future<void> switchType(String type) async {
    if (currentType == type) return; 
    currentType = type;
    await loadToday();
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
      final action = m.group(1)?.trim() ?? constEmpty;
      if (action.isEmpty) continue;

      final op = m.group(2)!;
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
