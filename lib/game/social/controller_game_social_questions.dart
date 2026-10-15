import 'dart:collection';

import 'package:life_pilot/game/model_question_bank.dart';
import 'package:life_pilot/game/service_game.dart' show ServiceGame;
import 'package:life_pilot/utils/logger.dart';
import 'package:life_pilot/utils/safe_change_notifier.dart';

enum SocialQuestionStatusFilter { all, active, inactive }

/// Social question state and operations; navigation and messages remain in View.
class ControllerGameSocialQuestions extends SafeChangeNotifier {
  ControllerGameSocialQuestions({required ServiceGame service})
    : _service = service;

  final ServiceGame _service;
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

  List<MySocialQuestion> get questions => UnmodifiableListView(_questions);
  List<String> get categories => UnmodifiableListView(_categories);
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
    _keyword = keyword.trim();
  }

  void selectCategory(String? category) {
    _category = category;
  }

  void selectStatus(SocialQuestionStatusFilter status) {
    _status = status;
  }

  void invalidateCategories() {
    _categoriesDirty = true;
    _categoryRevision++;
  }

  /// Null denotes a stale/disposed request or an ignored duplicate page load.
  Future<bool?> load({
    bool append = false,
    bool refreshCategories = false,
  }) async {
    if (notifierDisposed) return null;
    if (append && (_loading || _loadingMore || !hasMore)) return null;
    final generation = append ? _generation : ++_generation;
    final revision = _categoryRevision;
    final fetchCategories =
        !append &&
        (refreshCategories || !_hasCategoryCache || _categoriesDirty);
    if (append) {
      _loadingMore = true;
    } else {
      _loading = true;
      _loadError = false;
    }
    notifyListeners();
    try {
      final results = await Future.wait<Object>([
        _service.fetchMySocialQuestions(
          keyword: _keyword,
          category: _category,
          status: _status.name,
          offset: append ? _questions.length : 0,
        ),
        fetchCategories
            ? _service.fetchMySocialQuestionCategories()
            : Future.value(_categories),
      ]);
      if (notifierDisposed || generation != _generation) return null;
      final page = results[0] as MySocialQuestionPage;
      _questions = append ? [..._questions, ...page.questions] : page.questions;
      _totalCount = page.totalCount;
      _pageHasMore = page.hasMore;
      _categories = results[1] as List<String>;
      if (fetchCategories) {
        _hasCategoryCache = true;
        _categoriesDirty = revision != _categoryRevision;
      }
      _loaded = true;
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
      await action();
      if (!notifierDisposed) invalidateCategories();
      return true;
    } finally {
      _busyIds.remove(id);
      notifyListeners();
    }
  }
}
