import 'dart:collection';

import 'package:life_pilot/game/model_question_bank.dart';
import 'package:life_pilot/game/service_game.dart' show ServiceGame;
import 'package:life_pilot/utils/logger.dart';
import 'package:life_pilot/utils/safe_change_notifier.dart';

enum QuestionStatusFilter { all, active, inactive }

/// Owns question-list state and operations; navigation and messages stay in View.
class ControllerGameMyQuestions extends SafeChangeNotifier {
  ControllerGameMyQuestions({
    required ServiceGame service,
    required this.gameName,
  }) : _service = service;

  final ServiceGame _service;
  final String gameName;
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

  List<MyGameQuestion> get questions => UnmodifiableListView(_questions);
  List<String> get groups => UnmodifiableListView(_groups);
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
    final next = keyword.trim();
    if (_appliedKeyword == next) return;
    _appliedKeyword = next;
    notifyListeners();
  }

  void selectGroup(String? group) {
    if (_selectedGroup == group) return;
    _selectedGroup = group;
    notifyListeners();
  }

  void selectStatus(QuestionStatusFilter status) {
    if (_statusFilter == status) return;
    _statusFilter = status;
    notifyListeners();
  }

  /// Null means the request was superseded or the controller was disposed.
  Future<bool?> load({bool append = false, bool refreshGroups = false}) async {
    if (notifierDisposed) return null;
    if (!append && _isLoading && _hasLoaded) return true;
    if (append && (_isLoading || _isLoadingMore || !hasMore)) return true;
    final fetchGroups =
        !append && (refreshGroups || !_hasGroupCache || _groupsDirty);
    final groupRevision = _groupRevision;
    final generation = append ? _loadGeneration : ++_loadGeneration;
    if (append) {
      _isLoadingMore = true;
    } else {
      _isLoading = true;
      _hasError = false;
    }
    notifyListeners();
    try {
      final results = await Future.wait<Object>([
        _service.fetchMyQuestions(
          gameName: gameName,
          keyword: _appliedKeyword,
          group: _selectedGroup,
          status: _statusFilter.name,
          offset: append ? _questions.length : 0,
        ),
        fetchGroups
            ? _service.fetchMyQuestionGroupsForManagement(gameName: gameName)
            : Future.value(_groups),
      ]);
      if (notifierDisposed || generation != _loadGeneration) return null;
      var page = results[0] as MyGameQuestionPage;
      final groups = results[1] as List<String>;
      if (!append &&
          _selectedGroup != null &&
          !groups.contains(_selectedGroup)) {
        _selectedGroup = null;
        page = await _service.fetchMyQuestions(
          gameName: gameName,
          keyword: _appliedKeyword,
          status: _statusFilter.name,
        );
        if (notifierDisposed || generation != _loadGeneration) return null;
      }
      _questions = append ? [..._questions, ...page.questions] : page.questions;
      _totalCount = page.totalCount;
      _pageHasMore = page.hasMore;
      _groups = groups;
      if (fetchGroups) {
        _hasGroupCache = true;
        _groupsDirty = groupRevision != _groupRevision;
      }
      _hasLoaded = true;
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
      if (!notifierDisposed && generation == _loadGeneration) {
        _isLoading = false;
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  Future<void> deleteQuestion(String id) async {
    if (notifierDisposed || isBusy(id)) return;
    _deletingIds.add(id);
    notifyListeners();
    try {
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
