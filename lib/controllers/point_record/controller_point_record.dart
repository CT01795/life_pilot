import 'package:flutter/foundation.dart';
import 'package:life_pilot/controllers/auth/controller_auth.dart';
import 'package:life_pilot/controllers/point_record/controller_point_record_account.dart';
import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/models/point_record/model_point_record.dart';
import 'package:life_pilot/models/point_record/model_point_record_account.dart';
import 'package:life_pilot/models/point_record/model_point_record_preview.dart';
import 'package:life_pilot/services/service_point_record.dart';

class ControllerPointRecord extends ChangeNotifier {
  final ServicePointRecord service;
  ControllerAuth? auth;
  final ControllerPointRecordAccount accountController;
  final String accountId;
  final String currentType = 'points';

  int totalValue(String? inputAccountId) {
    final account = getAccount(inputAccountId ?? accountId);
    return account.points;
  }

  ModelPointRecordAccount getAccount(String? inputAccountId) {
    return accountController.getAccountById(inputAccountId ?? accountId);
  }

  ControllerPointRecord(
      {required this.service,
      required this.accountController,
      required this.auth,
      required this.accountId,});

  int todayTotal = 0;

  List<ModelPointRecord> todayRecords = [];

  Future<void> loadToday({String? inputAccountId}) async {
    todayRecords = await service.fetchTodayRecords(
      accountId: inputAccountId ?? accountId,
      type: currentType,
    );

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    todayTotal = todayRecords
        .where((r) =>
            r.localTime.isAfter(todayStart))
        .fold(0, (s, r) => s + r.value);
    notifyListeners();
  }

  Future<List<PointRecordPreview>> parseFromSpeech(
      String text, String? currency, num? exchangeRate) async {
    final results = NLPService.parseMulti(text);

    return results
        .map(
          (r) => PointRecordPreview(
              description: r.description,
              value: r.points,),
        )
        .toList();
  }

  Future<void> commitRecords(List<PointRecordPreview> previews,
      {String? inputAccountId}) async {
    await service.insertRecordsBatch(
        accountId: inputAccountId ?? accountId,
        type: currentType,
        records: previews,);

    await loadToday(inputAccountId: inputAccountId ?? accountId);
  }
}

class NLPService {
  // ① 加 / 扣 + 數字（阿拉伯 or 中文）
  static final regex = RegExp(
    r'([^，。,]*?)\s*(加|減|扣|\+|-)\s*(\d+|[一二三四五六七八九十兩]+)\s*(分|點|元)?',
  );
  static List<PointRecordParsedResult> parseMulti(String text) {
    final results = <PointRecordParsedResult>[];

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
        PointRecordParsedResult(
          action,
          isAdd ? value : -value,
        ),
      );
    }

    return results;
  }
}

class PointRecordParsedResult {
  final String description;
  final int points;

  PointRecordParsedResult(this.description, this.points);
}
