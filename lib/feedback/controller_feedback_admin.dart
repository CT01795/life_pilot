import 'dart:async';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/feedback/model_feedback.dart';
import 'package:life_pilot/feedback/service_feedback.dart';
import 'package:life_pilot/utils/safe_change_notifier.dart';

class ControllerFeedbackAdmin extends SafeChangeNotifier {
  final ServiceFeedback _service;
  final ControllerAuth auth;

  ControllerFeedbackAdmin(ServiceFeedback service, this.auth)
      : _service = service;
  List<ModelFeedback> feedbackList = [];
  bool isLoading = false;
  Object? loadError;
  bool isLoadingMore = false;
  bool hasMore = false;
  DateTime? _loadedStartDate;
  final Set<String> selectedStatuses = {'pending', 'in_progress'};

  Future<void> loadFeedback() async {
    isLoading = true;
    loadError = null;
    notifyListeners();
    try {
      final now = DateTime.now();
      final dateTo = DateTime(now.year, now.month, now.day + 1);
      _loadedStartDate = dateTo.subtract(const Duration(days: 30));
      final res = await _service.loadFeedback(
        dateFrom: _loadedStartDate!,
        dateTo: dateTo,
      );
      feedbackList = (res as List<dynamic>?)?.map((e) {
            return ModelFeedback.fromMap(e as Map<String, dynamic>);
          }).toList() ??
          [];
      _sortAndDeduplicate();
      hasMore = await _service.hasFeedbackBefore(_loadedStartDate!);
    } catch (error) {
      loadError = error;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  List<ModelFeedback> get visibleFeedback => feedbackList
      .where((feedback) => selectedStatuses.contains(feedback.status))
      .toList();

  void toggleStatus(String status) {
    selectedStatuses.contains(status)
        ? selectedStatuses.remove(status)
        : selectedStatuses.add(status);
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (isLoadingMore || !hasMore || _loadedStartDate == null) return;
    isLoadingMore = true;
    notifyListeners();
    try {
      final latestOlder =
          await _service.latestFeedbackDateBefore(_loadedStartDate!);
      if (latestOlder == null) {
        hasMore = false;
        return;
      }
      final dateTo = DateTime(
        latestOlder.year,
        latestOlder.month,
        latestOlder.day + 1,
      );
      final dateFrom = dateTo.subtract(const Duration(days: 30));
      final rows = await _service.loadFeedback(
        dateFrom: dateFrom,
        dateTo: dateTo,
      );
      feedbackList.addAll(rows.map(
        (row) => ModelFeedback.fromMap(row as Map<String, dynamic>),
      ));
      _loadedStartDate = dateFrom;
      _sortAndDeduplicate();
      hasMore = await _service.hasFeedbackBefore(dateFrom);
    } finally {
      isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> updateStatus(
      ModelFeedback feedback, String status, String adminAccount) async {
    feedback.status = status;
    feedback.isOk = status == 'completed';
    feedback.dealBy = status == 'pending' ? null : adminAccount;
    feedback.dealAt = status == 'completed' ? DateTime.now().toUtc() : null;
    await _service.updateFeedback(feedback: feedback);
    _sortAndDeduplicate();
    notifyListeners();
  }

  void _sortAndDeduplicate() {
    final unique = <int, ModelFeedback>{
      for (final feedback in feedbackList) feedback.id: feedback,
    };
    int rank(String status) => switch (status) {
          'in_progress' => 0,
          'pending' => 1,
          _ => 2,
        };
    feedbackList = unique.values.toList()
      ..sort((a, b) {
        final statusOrder = rank(a.status).compareTo(rank(b.status));
        return statusOrder != 0
            ? statusOrder
            : b.createdAt.compareTo(a.createdAt);
      });
  }

  Future<void> markAsDone(ModelFeedback feedback, String adminAccount) async {
    final now = DateTime.now().toUtc();
    // 更新本地資料
    feedback.isOk = true;
    feedback.status = 'completed';
    feedback.dealBy = adminAccount;
    feedback.dealAt = now;
    await _service.updateFeedback(feedback: feedback);
    notifyListeners();
  }
}
