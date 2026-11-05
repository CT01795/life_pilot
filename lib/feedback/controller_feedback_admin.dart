import 'dart:async';
import 'package:life_pilot/feedback/model_feedback_page.dart';
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
    FeedbackPageLoader? pageLoader,
  }) : _service = service,
       _pageLoader = pageLoader ?? service.loadFeedbackPage {
    _account = auth.currentAccount;
    auth.addListener(_onAccountChanged);
  }
  String? _account;
  final Duration requestTimeout;
  final FeedbackPageLoader _pageLoader;
  FeedbackCursor? _cursor;
  int _revision = 0;
  final Set<int> _updating = {};
  final _imageLoads = <int, Future<void>>{};

  /// A retained dialog must not load a row from a previous account or list.
  bool canReadScreenshots(ModelFeedback feedback) =>
      _active(_revision) &&
      _feedbackList.any((row) => identical(row, feedback));

  Future<void> loadScreenshots(ModelFeedback feedback) {
    if (!canReadScreenshots(feedback)) {
      return Future.error(StateError('Feedback request changed'));
    }
    if (feedback.screenshotsLoaded) return Future.value();
    final active = _imageLoads[feedback.id];
    if (active != null) return active;
    final revision = _revision;
    late Future<void> request;
    request =
        Future<void>.sync(() async {
          final images = await _service
              .loadScreenshots(feedback.id)
              .timeout(requestTimeout);
          if (!_active(revision) || !canReadScreenshots(feedback)) {
            throw StateError('Feedback request changed');
          }
          feedback.screenshot = List.unmodifiable(images);
          feedback.screenshotsLoaded = true;
        }).whenComplete(() {
          if (identical(_imageLoads[feedback.id], request)) {
            _imageLoads.remove(feedback.id);
          }
        });
    _imageLoads[feedback.id] = request;
    return request;
  }

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
    _cursor = null;
    _updating.clear();
    _imageLoads.clear();
    isLoading = false;
    isLoadingMore = false;
    hasMore = false;
    loadError = null;
    loadMoreError = null;
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
  Object? loadMoreError;
  bool isLoadingMore = false;
  bool hasMore = false;
  final Set<String> _selectedStatuses = {'pending', 'in_progress'};
  Set<String>? _selectedStatusesCache;
  Set<String> get selectedStatuses =>
      _selectedStatusesCache ??= Set.unmodifiable(_selectedStatuses);

  Future<void> loadFeedback() async {
    if (notifierDisposed || isLoading || _updating.isNotEmpty) return;
    return _loadPaged(replace: true);
  }

  bool get hasHistoryAction =>
      hasMore || isLoadingMore || loadMoreError != null;

  List<ModelFeedback> get visibleFeedback =>
      _visibleCache ??= List.unmodifiable(
        feedbackList.where(
          (feedback) => _selectedStatuses.contains(feedback.status),
        ),
      );

  void toggleStatus(String status) {
    if (notifierDisposed) return;
    if (_updating.isNotEmpty) return;
    _selectedStatuses.contains(status)
        ? _selectedStatuses.remove(status)
        : _selectedStatuses.add(status);
    _selectedStatusesCache = null;
    _visibleCache = null;
    notifyListeners();
    unawaited(_loadPaged(replace: true));
  }

  Future<void> loadMore() => _loadPaged(replace: false);

  bool isUpdating(int id) => _updating.contains(id);

  Future<void> _loadPaged({required bool replace}) async {
    if (notifierDisposed ||
        _updating.isNotEmpty ||
        (!replace && (isLoading || isLoadingMore || !hasMore))) {
      return;
    }
    final revision = replace ? ++_revision : _revision;
    final statuses = Set<String>.of(_selectedStatuses);
    if (replace) {
      _cursor = null;
      hasMore = false;
      _imageLoads.clear();
      isLoadingMore = false;
      loadError = null;
      loadMoreError = null;
    }
    if (statuses.isEmpty) {
      _feedbackList = const [];
      _visibleCache = null;
      hasMore = false;
      isLoading = false;
      notifyListeners();
      return;
    }
    if (replace) {
      isLoading = true;
    } else {
      isLoadingMore = true;
      loadMoreError = null;
    }
    notifyListeners();
    try {
      final page = await _pageLoader(
        statuses: statuses,
        before: replace ? null : _cursor,
      ).timeout(requestTimeout);
      if (!_active(revision)) return;
      if (page.hasMore && page.cursor == null) {
        throw const FormatException('Missing feedback cursor');
      }
      _feedbackList = replace ? page.rows : [..._feedbackList, ...page.rows];
      _sortAndDeduplicate();
      _cursor = page.cursor;
      hasMore = page.hasMore;
    } catch (error) {
      if (_active(revision)) {
        if (replace) {
          loadError = error;
        } else {
          loadMoreError = error;
        }
      }
    } finally {
      if (_active(revision)) {
        isLoading = false;
        isLoadingMore = false;
        notifyListeners();
      }
    }
  }

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
