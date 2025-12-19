import 'package:flutter/foundation.dart';
import 'package:life_pilot/controllers/point_record/controller_point_record_account.dart';
import 'package:life_pilot/models/point_record/model_point_record.dart';
import 'package:life_pilot/models/point_record/model_point_record_account.dart';
import 'package:life_pilot/models/point_record/model_point_record_preview.dart';
import 'package:life_pilot/services/service_point_record.dart';

class ControllerPointRecord extends ChangeNotifier {
  final ServicePointRecord service;
  final String accountId;
  final ControllerPointRecordAccount accountController;

  ControllerPointRecord(
    this.service,
    this.accountId,
    this.accountController,
  );

  ModelPointRecordAccount get account =>
      accountController.getAccountById(accountId);

  String currentType = 'points'; // points | balance

  List<ModelPointRecord> todayRecords = [];

  Future<void> loadToday() async {
    todayRecords = await service.fetchTodayRecords(
      accountId: account.id,
      type: currentType,
    );
    notifyListeners();
  }

  Future<List<PointRecordPreview>> parseFromSpeech(String text) async {
    final results = NLPService.parseMulti(text);

    return results
        .map(
          (r) => PointRecordPreview(
            description: r.description,
            value: r.points,
          ),
        )
        .toList();
  }

  Future<void> commitRecords(List<PointRecordPreview> previews) async {
    await service.insertRecordsBatch(
      accountId: account.id,
      type: currentType,
      records: previews,
    );

    await loadToday();
  }

  Future<void> switchType(String type) async {
    currentType = type;
    await loadToday();
  }
}

class NLPService {
  static List<PointRecordParsedResult> parseMulti(String text) {
    final results = <PointRecordParsedResult>[];

    // ① 加 / 扣 + 數字（阿拉伯 or 中文）
    final regex = RegExp(
      r'([^，。,]*?)\s*(加|扣|\+|-)\s*(\d+|[一二三四五六七八九十]+)\s*(分|點)?',
    );

    for (final m in regex.allMatches(text)) {
      final action = m.group(1)?.trim().isNotEmpty == true
        ? m.group(1)!.trim()
        : 'Accounting';

      final op = m.group(2)!;
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
