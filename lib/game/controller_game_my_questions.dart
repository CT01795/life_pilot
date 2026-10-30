import 'dart:async';

import 'package:life_pilot/game/model_question_bank.dart';
import 'package:life_pilot/game/service_game.dart' show ServiceGame;
import 'package:life_pilot/utils/logger.dart';
import 'package:life_pilot/utils/safe_change_notifier.dart';

enum QuestionStatusFilter { all, active, inactive }

typedef _QuestionQuery = ({
  String keyword,
  String? group,
  QuestionStatusFilter status,
});

typedef _QuestionRead = ({
  MyGameQuestionPage page,
  List<String> groups,
  _QuestionQuery query,
});

/// Owns question-list state and operations; navigation and messages stay in View.
class ControllerGameMyQuestions extends SafeChangeNotifier {
  ControllerGameMyQuestions({
    required ServiceGame service,
    required this.gameName,
    this.requestTimeout = const Duration(seconds: 30),
  }) : _service = service;

  final ServiceGame _service;
  final String gameName;
  final Duration requestTimeout;
  List<MyGameQuestion> _questions = const [];
  List<String> _groups = const [];
  int _totalCount = 0;
  bool? _pageHasMore;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasLoaded = false;
  bool _hasError = false;
  bool _hasGroupCache = false;
  bool _groupsDirty = false;
  int _groupRevision = 0;
  int _loadGeneration = 0;
  final Set<String> _deletingIds = {};
  final Set<String> _updatingIds = {};
  String _appliedKeyword = '';
  String? _selectedGroup;
  QuestionStatusFilter _statusFilter = QuestionStatusFilter.all;
  _QuestionQuery? _loadingQuery;
  _QuestionQuery? _loadedQuery;
  _QuestionQuery get _query =>
      (keyword: _appliedKeyword, group: _selectedGroup, status: _statusFilter);

  List<MyGameQuestion> get questions => _questions;
  List<String> get groups => _groups;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasLoaded => _hasLoaded;
  bool get hasError => _hasError;
  bool get hasMore => _pageHasMore ?? _questions.length < _totalCount;
  String get appliedKeyword => _appliedKeyword;
  String? get selectedGroup => _selectedGroup;
  QuestionStatusFilter get statusFilter => _statusFilter;
  bool isBusy(String id) =>
      _deletingIds.contains(id) || _updatingIds.contains(id);

  void applySearch(String keyword) {
    if (notifierDisposed) return;
    final next = keyword.trim();
    if (_appliedKeyword == next) return;
    _appliedKeyword = next;
    notifyListeners();
  }

  void selectGroup(String? group) {
    if (notifierDisposed) return;
    if (_selectedGroup == group) return;
    _selectedGroup = group;
    notifyListeners();
  }

  void selectStatus(QuestionStatusFilter status) {
    if (notifierDisposed) return;
    if (_statusFilter == status) return;
    _statusFilter = status;
    notifyListeners();
  }

  /// Null means the request was superseded or the controller was disposed.
  Future<bool?> load({bool append = false, bool refreshGroups = false}) async {
    if (notifierDisposed) return null;
    final query = _query;
    // Ordinary duplicate reads are ignored, but a requested classification
    // refresh must supersede the old response (for example after an edit).
    if (!append && _isLoading && _loadingQuery == query && !refreshGroups) {
      return true;
    }
    if (append &&
        (_isLoading || _isLoadingMore || !hasMore || _loadedQuery != query)) {
      return true;
    }
    final fetchGroups =
        !append && (refreshGroups || !_hasGroupCache || _groupsDirty);
    final groupRevision = _groupRevision;
    final generation = append ? _loadGeneration : ++_loadGeneration;
    final offset = append ? _questions.length : 0;
    if (append) {
      _isLoadingMore = true;
    } else {
      _loadingQuery = query;
      _isLoadingMore = false;
      _isLoading = true;
      _hasError = false;
    }
    notifyListeners();
    var reading = true;
    bool isCurrent() =>
        reading && !notifierDisposed && generation == _loadGeneration;
    try {
      if (!isCurrent()) return null;
      final result = await _readPage(
        query: query,
        offset: offset,
        append: append,
        fetchGroups: fetchGroups,
        isCurrent: isCurrent,
      ).timeout(requestTimeout);
      if (!isCurrent() || result == null) return null;
      final (:page, :groups, query: effectiveQuery) = result;
      _questions = List.unmodifiable(
        append ? _questions.followedBy(page.questions) : page.questions,
      );
      _totalCount = page.totalCount;
      _pageHasMore = page.hasMore;
      if (!identical(groups, _groups)) _groups = List.unmodifiable(groups);
      if (fetchGroups) {
        _hasGroupCache = true;
        _groupsDirty = groupRevision != _groupRevision;
      }
      _hasLoaded = true;
      _loadedQuery = effectiveQuery;
      return true;
    } catch (error, stackTrace) {
      if (notifierDisposed || generation != _loadGeneration) return null;
      logger.e(
        append
            ? 'Load more game questions failed'
            : 'Load game questions failed',
        error: error,
        stackTrace: stackTrace,
      );
      if (!notifierDisposed &&
          generation == _loadGeneration &&
          !append &&
          !_hasLoaded) {
        _hasError = true;
      }
      return false;
    } finally {
      // Timing out does not cancel HTTP. Prevent a late response from starting
      // a fallback query or publishing into a completed/replaced read.
      reading = false;
      if (!notifierDisposed && generation == _loadGeneration) {
        if (!append) _loadingQuery = null;
        _isLoading = false;
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  Future<_QuestionRead?> _readPage({
    required _QuestionQuery query,
    required int offset,
    required bool append,
    required bool fetchGroups,
    required bool Function() isCurrent,
  }) async {
    final results = await Future.wait<Object>([
      Future<MyGameQuestionPage>.sync(
        () => _service.fetchMyQuestions(
          gameName: gameName,
          keyword: query.keyword,
          group: query.group,
          status: query.status.name,
          offset: offset,
        ),
      ),
      fetchGroups
          ? Future<List<String>>.sync(
              () => _service.fetchMyQuestionGroupsForManagement(
                gameName: gameName,
              ),
            )
          : Future.value(_groups),
    ], eagerError: true);
    if (!isCurrent()) return null;
    var page = results[0] as MyGameQuestionPage;
    final groups = results[1] as List<String>;
    var effectiveQuery = query;
    if (!append && query.group != null && !groups.contains(query.group)) {
      if (_query == query) _selectedGroup = null;
      effectiveQuery = (
        keyword: query.keyword,
        group: null,
        status: query.status,
      );
      page = await _service.fetchMyQuestions(
        gameName: gameName,
        keyword: query.keyword,
        status: query.status.name,
      );
      if (!isCurrent()) return null;
    }
    return (page: page, groups: groups, query: effectiveQuery);
  }

  Future<void> deleteQuestion(String id) async {
    if (notifierDisposed || isBusy(id)) return;
    _deletingIds.add(id);
    notifyListeners();
    try {
      if (notifierDisposed) return;
      await _service.deleteMyQuestion(gameName: gameName, questionId: id);
      if (!notifierDisposed) {
        _groupsDirty = true;
        _groupRevision++;
      }
    } finally {
      _deletingIds.remove(id);
      notifyListeners();
    }
  }

  Future<void> setQuestionActive(String id, bool active) async {
    if (notifierDisposed || isBusy(id)) return;
    _updatingIds.add(id);
    notifyListeners();
    try {
      if (notifierDisposed) return;
      await _service.setMyQuestionActive(
        gameName: gameName,
        questionId: id,
        isActive: active,
      );
      if (!notifierDisposed) {
        _groupsDirty = true;
        _groupRevision++;
      }
    } finally {
      _updatingIds.remove(id);
      notifyListeners();
    }
  }
}
