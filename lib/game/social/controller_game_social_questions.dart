import 'dart:async';

import 'package:life_pilot/game/model_question_bank.dart';
import 'package:life_pilot/game/service_game.dart' show ServiceGame;
import 'package:life_pilot/utils/logger.dart';
import 'package:life_pilot/utils/safe_change_notifier.dart';

enum SocialQuestionStatusFilter { all, active, inactive }

typedef _SocialQuestionQuery = ({
  String keyword,
  String? category,
  SocialQuestionStatusFilter status,
});

/// Social question state and operations; navigation and messages remain in View.
class ControllerGameSocialQuestions extends SafeChangeNotifier {
  ControllerGameSocialQuestions({
    required ServiceGame service,
    this.requestTimeout = const Duration(seconds: 30),
  }) : _service = service;

  final ServiceGame _service;
  final Duration requestTimeout;
  List<MySocialQuestion> _questions = const [];
  List<String> _categories = const [];
  final Set<String> _busyIds = {};
  String _keyword = '';
  String? _category;
  SocialQuestionStatusFilter _status = SocialQuestionStatusFilter.all;
  int _totalCount = 0;
  bool? _pageHasMore;
  bool _loading = true;
  bool _loadingMore = false;
  bool _loaded = false;
  bool _loadError = false;
  bool _hasCategoryCache = false;
  bool _categoriesDirty = false;
  int _categoryRevision = 0;
  int _generation = 0;
  _SocialQuestionQuery? _loadingQuery, _loadedQuery;
  _SocialQuestionQuery get _query =>
      (keyword: _keyword, category: _category, status: _status);

  List<MySocialQuestion> get questions => _questions;
  List<String> get categories => _categories;
  int get totalCount => _totalCount;
  bool get isLoading => _loading;
  bool get isLoadingMore => _loadingMore;
  bool get hasLoaded => _loaded;
  bool get hasError => _loadError;
  bool get hasMore => _pageHasMore ?? _questions.length < _totalCount;
  String get appliedKeyword => _keyword;
  String? get selectedCategory => _category;
  SocialQuestionStatusFilter get status => _status;
  bool isBusy(String id) => _busyIds.contains(id);

  void applySearch(String keyword) {
    if (notifierDisposed) return;
    _keyword = keyword.trim();
  }

  void selectCategory(String? category) {
    if (notifierDisposed) return;
    _category = category;
  }

  void selectStatus(SocialQuestionStatusFilter status) {
    if (notifierDisposed) return;
    _status = status;
  }

  void invalidateCategories() {
    if (notifierDisposed) return;
    _categoriesDirty = true;
    _categoryRevision++;
  }

  /// Null denotes a stale/disposed request or an ignored duplicate read.
  Future<bool?> load({
    bool append = false,
    bool refreshCategories = false,
  }) async {
    if (notifierDisposed) return null;
    final query = _query;
    if (!append && _loading && _loadingQuery == query && !refreshCategories) {
      return null;
    }
    if (append &&
        (_loading || _loadingMore || !hasMore || _loadedQuery != query)) {
      return null;
    }
    final generation = append ? _generation : ++_generation;
    final offset = append ? _questions.length : 0;
    final revision = _categoryRevision;
    final fetchCategories =
        !append &&
        (refreshCategories || !_hasCategoryCache || _categoriesDirty);
    if (append) {
      _loadingMore = true;
    } else {
      _loadingQuery = query;
      _loadingMore = false;
      _loading = true;
      _loadError = false;
    }
    notifyListeners();
    try {
      if (notifierDisposed || generation != _generation) return null;
      final results = await Future.wait<Object>([
        Future<MySocialQuestionPage>.sync(
          () => _service.fetchMySocialQuestions(
            keyword: query.keyword,
            category: query.category,
            status: query.status.name,
            offset: offset,
          ),
        ),
        fetchCategories
            ? Future<List<String>>.sync(
                _service.fetchMySocialQuestionCategories,
              )
            : Future.value(_categories),
      ], eagerError: true).timeout(requestTimeout);
      if (notifierDisposed || generation != _generation) return null;
      final page = results[0] as MySocialQuestionPage;
      _questions = List.unmodifiable(
        append ? _questions.followedBy(page.questions) : page.questions,
      );
      _totalCount = page.totalCount;
      _pageHasMore = page.hasMore;
      final categories = results[1] as List<String>;
      if (!identical(categories, _categories)) {
        _categories = List.unmodifiable(categories);
      }
      if (fetchCategories) {
        _hasCategoryCache = true;
        _categoriesDirty = revision != _categoryRevision;
      }
      _loaded = true;
      _loadedQuery = query;
      return true;
    } catch (error, stackTrace) {
      if (notifierDisposed || generation != _generation) return null;
      logger.e(
        'Load Social questions failed',
        error: error,
        stackTrace: stackTrace,
      );
      if (!append && !_loaded) _loadError = true;
      return false;
    } finally {
      if (!notifierDisposed && generation == _generation) {
        if (!append) _loadingQuery = null;
        _loading = false;
        _loadingMore = false;
        notifyListeners();
      }
    }
  }

  Future<bool> deleteQuestion(String id) =>
      _write(id, () => _service.deleteMySocialQuestion(id));

  Future<bool> setQuestionActive(String id, bool active) => _write(
    id,
    () => _service.setMySocialQuestionActive(id: id, isActive: active),
  );

  Future<bool> _write(String id, Future<void> Function() action) async {
    if (notifierDisposed || !_busyIds.add(id)) return false;
    notifyListeners();
    try {
      if (notifierDisposed) return false;
      await action();
      if (!notifierDisposed) invalidateCategories();
      return true;
    } finally {
      _busyIds.remove(id);
      notifyListeners();
    }
  }
}
