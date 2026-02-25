import 'package:flutter/foundation.dart';
import 'package:life_pilot/controllers/auth/controller_auth.dart';
import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/core/enum.dart';
import 'package:life_pilot/point_record/model_point_record_detail.dart';
import 'package:life_pilot/point_record/model_point_record_account.dart';
import 'package:life_pilot/point_record/model_point_record_preview.dart';
import 'package:life_pilot/point_record/service_point_record.dart';

class ControllerPointRecordDetail extends ChangeNotifier {
  final ServicePointRecord service;
  ControllerAuth? auth;
  final String accountId;

  ControllerPointRecordDetail(
      {required this.service,
      required this.auth,
      required this.accountId,});
  
  final String currentType = 'points';
  
  List<ModelPointRecordDetail> todayRecords = [];
  int todayTotal = 0;
  int? total;
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

  void _calculateTotals({String? inputAccountId}) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    todayTotal = todayRecords
        .where((r) =>
            r.localTime.isAfter(todayStart))
        .fold(0, (s, r) => s + r.value);
    total = todayRecords[0].points;
  }

  Future<ModelPointRecordAccount?> findAccountByEventId(
      {required String eventId}) async {
    // 或者直接從 Supabase 查詢
    return await service.findAccountByEventId(
      eventId: eventId,
      user: auth?.currentAccount ?? constEmpty,
    );
  }

  List<PointRecordPreview> parseFromSpeech(String text) {
    final results = NLPService.parseMulti(text);

    return results
        .map(
          (r) => PointRecordPreview(
              description: r.description,
              value: r.value,),
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

