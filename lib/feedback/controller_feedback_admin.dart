import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/feedback/model_feedback.dart';
import 'package:life_pilot/feedback/model_feedback_list.dart';
import 'package:life_pilot/feedback/service_feedback.dart';
import 'package:life_pilot/utils/safe_change_notifier.dart';

class ControllerFeedbackAdmin extends SafeChangeNotifier {
  final ServiceFeedback _service;
  final ControllerAuth auth;

  ControllerFeedbackAdmin(
    ServiceFeedback service,
    this.auth, {
    this.requestTimeout = const Duration(seconds: 30),
    this.historyTimeout = const Duration(seconds: 10),
  }) : _service = service {
    _account = auth.currentAccount;
    auth.addListener(_onAccountChanged);
  }
  String? _account;
  final Duration requestTimeout;
  final Duration historyTimeout;
  int _revision = 0;
  final Set<int> _updating = {};
  List<ModelFeedback>? _visibleCache;

  bool _active(int revision) =>
      !notifierDisposed &&
      revision == _revision &&
      _account == auth.currentAccount;

  void _onAccountChanged() {
    if (_account == auth.currentAccount) return;
    _account = auth.currentAccount;
    _revision++;
    _feedbackList = const [];
    _visibleCache = null;
    _loadedStartDate = null;
    _updating.clear();
    isLoading = false;
    isLoadingMore = false;
    hasMore = false;
    loadError = null;
    historyError = null;
    loadMoreError = null;
    isCheckingHistory = false;
    _selectedStatuses
      ..clear()
      ..addAll({'pending', 'in_progress'});
    _selectedStatusesCache = null;
    notifyListeners();
  }

  @override
  void dispose() {
    auth.removeListener(_onAccountChanged);
    super.dispose();
  }

  List<ModelFeedback> _feedbackList = const [];
  List<ModelFeedback> get feedbackList => _feedbackList;
  bool isLoading = false;
  Object? loadError;
  Object? historyError;
  Object? loadMoreError;
  bool isCheckingHistory = false;
  bool isLoadingMore = false;
  bool hasMore = false;
  DateTime? _loadedStartDate;
  final Set<String> _selectedStatuses = {'pending', 'in_progress'};
  Set<String>? _selectedStatusesCache;
  Set<String> get selectedStatuses =>
      _selectedStatusesCache ??= Set.unmodifiable(_selectedStatuses);

  Future<void> loadFeedback() async {
    if (notifierDisposed || isLoading || _updating.isNotEmpty) return;
    final revision = ++_revision;
    isLoadingMore = false;
    isLoading = true;
    loadError = null;
    historyError = null;
    loadMoreError = null;
    isCheckingHistory = false;
    notifyListeners();
    try {
      final now = DateTime.now();
      final dateTo = DateTime(now.year, now.month, now.day + 1);
      final loadedStartDate = dateTo.subtract(const Duration(days: 30));
      if (!_active(revision)) return;
      final res = await _service
          .loadFeedback(dateFrom: loadedStartDate, dateTo: dateTo)
          .timeout(requestTimeout);
      if (!_active(revision)) return;
      final loadedFeedback = res
          .map((e) => ModelFeedback.fromMap(e as Map<String, dynamic>))
          .toList();
      _feedbackList = loadedFeedback;
      _loadedStartDate = loadedStartDate;
      _sortAndDeduplicate();
      isLoading = false;
      await _checkHistory(loadedStartDate, revision);
    } catch (error) {
      if (_active(revision)) loadError = error;
    } finally {
      if (_active(revision)) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> _checkHistory(DateTime before, int revision) async {
    if (!_active(revision)) return;
    isCheckingHistory = true;
    historyError = null;
    notifyListeners();
    try {
      if (!_active(revision)) return;
      final more = await _service
          .hasFeedbackBefore(before)
          .timeout(historyTimeout);
      if (_active(revision)) hasMore = more;
    } catch (error) {
      if (_active(revision)) historyError = error;
    } finally {
      if (_active(revision)) {
        isCheckingHistory = false;
        notifyListeners();
      }
    }
  }

  Future<void> retryHistory() async {
    final before = _loadedStartDate;
    if (notifierDisposed ||
        before == null ||
        isLoading ||
        isLoadingMore ||
        isCheckingHistory) {
      return;
    }
    await _checkHistory(before, _revision);
  }

  bool get hasHistoryAction =>
      hasMore ||
      isLoadingMore ||
      isCheckingHistory ||
      historyError != null ||
      loadMoreError != null;

  List<ModelFeedback> get visibleFeedback =>
      _visibleCache ??= List.unmodifiable(
        feedbackList.where(
          (feedback) => _selectedStatuses.contains(feedback.status),
        ),
      );

  void toggleStatus(String status) {
    if (notifierDisposed) return;
    _selectedStatuses.contains(status)
        ? _selectedStatuses.remove(status)
        : _selectedStatuses.add(status);
    _selectedStatusesCache = null;
    _visibleCache = null;
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (notifierDisposed ||
        isLoading ||
        isCheckingHistory ||
        isLoadingMore ||
        _updating.isNotEmpty ||
        !hasMore ||
        _loadedStartDate == null) {
      return;
    }
    final revision = _revision;
    final before = _loadedStartDate!;
    isLoadingMore = true;
    loadMoreError = null;
    historyError = null;
    notifyListeners();
    try {
      if (!_active(revision)) return;
      final latestOlder = await _service
          .latestFeedbackDateBefore(before)
          .timeout(requestTimeout);
      if (!_active(revision)) return;
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
      final rows = await _service
          .loadFeedback(dateFrom: dateFrom, dateTo: dateTo)
          .timeout(requestTimeout);
      if (!_active(revision)) return;
      _feedbackList = [
        ...feedbackList,
        ...rows.map(
          (row) => ModelFeedback.fromMap(row as Map<String, dynamic>),
        ),
      ];
      _loadedStartDate = dateFrom;
      _sortAndDeduplicate();
      isLoadingMore = false;
      await _checkHistory(dateFrom, revision);
    } catch (error) {
      if (_active(revision)) loadMoreError = error;
    } finally {
      if (_active(revision)) {
        isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  bool isUpdating(int id) => _updating.contains(id);

  /// Null means ignored/stale; false means persistence failed.
  Future<bool?> updateStatus(
    ModelFeedback feedback,
    String status,
    String adminAccount,
  ) async {
    if (notifierDisposed ||
        isLoading ||
        isLoadingMore ||
        _updating.contains(feedback.id)) {
      return null;
    }
    if (!_feedbackList.any((item) => identical(item, feedback))) return null;
    if (feedback.status == status) return true;
    final revision = _revision;
    _updating.add(feedback.id);
    notifyListeners();
    try {
      if (!_active(revision)) return null;
      final update = feedback.withStatus(status, adminAccount, DateTime.now());
      await _service.updateFeedback(feedback: update);
      if (!_active(revision)) return null;
      // Preserve screenshot decode caches on the displayed model.
      feedback.status = update.status;
      feedback.isOk = update.isOk;
      feedback.dealBy = update.dealBy;
      feedback.dealAt = update.dealAt;
      _sortAndDeduplicate();
      return true;
    } catch (_) {
      return _active(revision) ? false : null;
    } finally {
      if (_active(revision)) {
        _updating.remove(feedback.id);
        notifyListeners();
      }
    }
  }

  void _sortAndDeduplicate() {
    _visibleCache = null;
    _feedbackList = ModelFeedbackList.ordered(feedbackList);
  }

  Future<void> markAsDone(ModelFeedback feedback, String adminAccount) async {
    await updateStatus(feedback, 'completed', adminAccount);
  }
}
