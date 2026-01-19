import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:life_pilot/models/model_feedback.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ControllerFeedbackAdmin extends ChangeNotifier {
  final supabase = Supabase.instance.client;
  ControllerFeedbackAdmin();

  List<ModelFeedback> feedbackList = [];
  bool isLoading = false;

  Future<void> loadFeedback() async {
    isLoading = true;
    notifyListeners();

    final res = await supabase
        .from('feedback')
        .select('id, subject, content, is_ok, created_at, deal_by, deal_at')
        //.eq('is_ok', false)
        .order('is_ok,created_at', ascending: true);

    feedbackList = (res as List<dynamic>?)
            ?.map((e) {
              return ModelFeedback.fromMap(e as Map<String, dynamic>);
            }).toList() ?? [];

    isLoading = false;
    notifyListeners();
  }

  Future<void> markAsDone(ModelFeedback feedback, String adminAccount) async {
    final now = DateTime.now().toUtc();

    await supabase.from('feedback').update({
      'is_ok': true,
      'deal_by': adminAccount,
      'deal_at': now.toIso8601String(),
    }).eq('id', feedback.id);

    // 更新本地資料
    feedback.isOk = true;
    feedback.dealBy = adminAccount;
    feedback.dealAt = now;

    notifyListeners();
  }

  Future<void> loadFeedbackScreenshots(ModelFeedback feedback) async {
    if (feedback.screenshot != null) return; // 已經載過

    final res = await supabase
        .from('feedback')
        .select('screenshot')
        .eq('id', feedback.id)
        .single();

    feedback.screenshot =
        (res['screenshot'] as List<dynamic>?)?.map((e) => e.toString()).toList();
  }
}
