import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/feedback/model_feedback.dart';
import 'package:life_pilot/feedback/service_feedback.dart';

class ControllerFeedbackAdmin extends ChangeNotifier {
  final ServiceFeedback _service;
  final ControllerAuth auth;

  ControllerFeedbackAdmin(ServiceFeedback service, this.auth): _service = service;
  List<ModelFeedback> feedbackList = [];
  bool isLoading = false;

  Future<void> loadFeedback() async {
    isLoading = true;
    notifyListeners();

    final res = await _service.loadFeedback();
    feedbackList = (res as List<dynamic>?)
            ?.map((e) {
              return ModelFeedback.fromMap(e as Map<String, dynamic>);
            }).toList() ?? [];

    isLoading = false;
    notifyListeners();
  }

  Future<void> markAsDone(ModelFeedback feedback, String adminAccount) async {
    final now = DateTime.now().toUtc();
    // 更新本地資料
    feedback.isOk = true;
    feedback.dealBy = adminAccount;
    feedback.dealAt = now;
    await _service.updateFeedback(feedback: feedback);
    notifyListeners();
  }
}
