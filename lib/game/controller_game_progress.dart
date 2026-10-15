import 'dart:collection';

import 'package:life_pilot/game/model_game_user.dart';
import 'package:life_pilot/game/model_game_progress_summary.dart';
import 'package:life_pilot/game/service_game.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:life_pilot/utils/safe_change_notifier.dart';

/// Owns progress windows and derived statistics; contains no navigation or UI.
class ControllerGameProgress extends SafeChangeNotifier {
  ControllerGameProgress({
    required ServiceGame service,
    required this.userName,
    DateTime Function()? now,
  }) : _service = service,
       _now = now ?? DateTime.now;

  final ServiceGame _service;
  final String userName;
  final DateTime Function() _now;
  String? _gameType;
  String? _gameName;
  int _generation = 0;
  DateTime? _startDate;
  List<ModelGameUser> _records = const [];
  int _unlockedMaxLevel = 1;
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = false;
  Object? _loadError;
  ModelGameProgressSummary _summary = const ModelGameProgressSummary(
    attempts: 0,
    passed: 0,
    bestScore: null,
  );

  List<ModelGameUser> get records => UnmodifiableListView(_records);
  ModelGameProgressSummary get summary => _summary;
  int get unlockedMaxLevel => _unlockedMaxLevel;
  bool get isLoading => _loading;
  bool get isLoadingMore => _loadingMore;
  bool get hasMore => _hasMore;
  Object? get loadError => _loadError;

  bool _isCurrent(int generation) =>
      !notifierDisposed && generation == _generation;

  void _setRecords(List<ModelGameUser> records) {
    _records = records;
    _summary = ModelGameProgressSummary.from(records);
  }

  /// Null means a newer game selection or disposal superseded this request.
  Future<bool?> load({
    required String gameType,
    required String gameName,
  }) async {
    if (notifierDisposed) return null;
    final scopeChanged = gameType != _gameType || gameName != _gameName;
    final generation = ++_generation;
    _gameType = gameType;
    _gameName = gameName;
    if (scopeChanged) {
      _setRecords(const []);
      _unlockedMaxLevel = 1;
      _startDate = null;
      _hasMore = false;
    }
    _loading = true;
    _loadingMore = false;
    _loadError = null;
    _service.invalidateLocalProgress();
    notifyListeners();
    try {
      final now = _now();
      final today = DateTime(now.year, now.month, now.day);
      var start = today.subtract(const Duration(days: 29));
      final results = await Future.wait<Object>([
        _service.fetchHighestPassedLevel(
          userName: userName,
          gameType: gameType,
          gameName: gameName,
        ),
        _service.fetchUserProgressPage(
          userName: userName,
          gameType: gameType,
          gameName: gameName,
          dateFrom: start,
          dateTo: today,
          includeLatestFallback: true,
        ),
        _service.hasUserProgressBefore(
          userName: userName,
          gameType: gameType,
          gameName: gameName,
          before: start,
        ),
      ]);
      if (!_isCurrent(generation)) return null;
      final records = results[1] as List<ModelGameUser>;
      var more = results[2] as bool;
      final fallbackDates = records
          .map((record) => record.createdAt)
          .whereType<DateTime>()
          .where((date) => date.isBefore(start))
          .toList();
      if (records.isNotEmpty && fallbackDates.length == records.length) {
        start = fallbackDates.reduce((a, b) => a.isAfter(b) ? a : b);
        more = await _service.hasUserProgressBefore(
          userName: userName,
          gameType: gameType,
          gameName: gameName,
          before: start,
        );
        if (!_isCurrent(generation)) return null;
      }
      _unlockedMaxLevel = (results[0] as int) + 1;
      _setRecords(records);
      _startDate = start;
      _hasMore = more;
      return true;
    } catch (error, stackTrace) {
      if (!_isCurrent(generation)) return null;
      _loadError = error;
      logger.e(
        'Load game progress failed',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    } finally {
      if (_isCurrent(generation)) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<bool?> loadMore() async {
    if (notifierDisposed ||
        _loading ||
        _loadingMore ||
        !_hasMore ||
        _startDate == null) {
      return null;
    }
    final generation = _generation;
    final gameType = _gameType!;
    final gameName = _gameName!;
    _loadingMore = true;
    _loadError = null;
    notifyListeners();
    try {
      final latest = await _service.latestUserProgressDateBefore(
        userName: userName,
        gameType: gameType,
        gameName: gameName,
        before: _startDate!,
      );
      if (!_isCurrent(generation)) return null;
      if (latest == null) {
        _hasMore = false;
        return true;
      }
      final end = DateTime(latest.year, latest.month, latest.day);
      final start = end.subtract(const Duration(days: 29));
      final results = await Future.wait<Object>([
        _service.fetchUserProgressPage(
          userName: userName,
          gameType: gameType,
          gameName: gameName,
          dateFrom: start,
          dateTo: end,
        ),
        _service.hasUserProgressBefore(
          userName: userName,
          gameType: gameType,
          gameName: gameName,
          before: start,
        ),
      ]);
      if (!_isCurrent(generation)) return null;
      final identified = <String, ModelGameUser>{};
      final unidentified = <ModelGameUser>[];
      for (final row in [..._records, ...results[0] as List<ModelGameUser>]) {
        final id = row.id;
        if (id == null || id.isEmpty) {
          unidentified.add(row);
        } else {
          identified[id] = row;
        }
      }
      final records = [...identified.values, ...unidentified]
        ..sort(
          (a, b) => (b.createdAt ?? DateTime(0)).compareTo(
            a.createdAt ?? DateTime(0),
          ),
        );
      _setRecords(records);
      _startDate = start;
      _hasMore = results[1] as bool;
      return true;
    } catch (error, stackTrace) {
      if (!_isCurrent(generation)) return null;
      _loadError = error;
      logger.e(
        'Load more game progress failed',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    } finally {
      if (_isCurrent(generation)) {
        _loadingMore = false;
        notifyListeners();
      }
    }
  }
}
