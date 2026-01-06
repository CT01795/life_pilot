import 'dart:async';
import 'package:flutter/material.dart';
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
        .select()
        //.eq('is_ok', false)
        .order('is_ok', ascending: true)
        .order('created_at', ascending: true);

    feedbackList = (res as List<dynamic>?)
            ?.map((e) => ModelFeedback.fromMap(e as Map<String, dynamic>))
            .toList() ??
        [];

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
}
