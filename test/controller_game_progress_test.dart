import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/game/controller_game_progress.dart';
import 'package:life_pilot/game/model_game_user.dart';
import 'package:life_pilot/game/service_game.dart';

final _today = DateTime(2026, 10, 15);
ModelGameUser _row(
  String? id,
  DateTime date, {
  num score = 10,
  bool passed = true,
}) => ModelGameUser(id: id, createdAt: date, score: score, isPass: passed);

class _Service extends ServiceGame {
  List<ModelGameUser> page = [];
  List<ModelGameUser> older = [];
  bool more = false;
  bool fail = false;
  DateTime? latest;
  Completer<List<ModelGameUser>>? pendingPage;
  Completer<DateTime?>? pendingLatest;
  final ranges = <(DateTime, DateTime, bool)>[];
  final beforeDates = <DateTime>[];
  int latestReads = 0;

  @override
  Future<int> fetchHighestPassedLevel({
    required String userName,
    required String gameType,
    required String gameName,
  }) async => 2;
  @override
  Future<List<ModelGameUser>> fetchUserProgressPage({
    required String userName,
    required String gameType,
    required String gameName,
    required DateTime dateFrom,
    required DateTime dateTo,
    bool includeLatestFallback = false,
  }) async {
    ranges.add((dateFrom, dateTo, includeLatestFallback));
    if (fail) throw StateError('offline');
    if (pendingPage != null) return pendingPage!.future;
    return includeLatestFallback ? page : older;
  }

  @override
  Future<bool> hasUserProgressBefore({
    required String userName,
    required String gameType,
    required String gameName,
    required DateTime before,
  }) async {
    beforeDates.add(before);
    return more;
  }

  @override
  Future<DateTime?> latestUserProgressDateBefore({
    required String userName,
    required String gameType,
    required String gameName,
    required DateTime before,
  }) async {
    latestReads++;
    return pendingLatest?.future ?? Future.value(latest);
  }
}

ControllerGameProgress _controller(_Service service) => ControllerGameProgress(
  service: service,
  userName: 'reader@example.com',
  now: () => _today,
);

void main() {
  test(
    'record snapshot is stable, read-only and isolated from service list',
    () async {
      final service = _Service()..page = [_row('a', _today)];
      final c = _controller(service);
      addTearDown(c.dispose);
      await c.load(gameType: 'language', gameName: 'Speaking');
      final snapshot = c.records;
      expect(c.records, same(snapshot));
      expect(() => snapshot.clear(), throwsUnsupportedError);
      service.page.add(_row('external', _today));
      expect(c.records.length, 1);
      expect(c.summary.attempts, 1);
      service.page = [_row('new', _today)];
      await c.load(gameType: 'language', gameName: 'Speaking');
      expect(snapshot.single.id, 'a');
      expect(c.records.single.id, 'new');
    },
  );

  test(
    'superseded initial load does not start obsolete progress reads',
    () async {
      final service = _Service();
      final c = _controller(service);
      addTearDown(c.dispose);
      Future<bool?>? newer;
      var started = false;
      c.addListener(() {
        if (!started && c.isLoading) {
          started = true;
          newer = c.load(gameType: 'language', gameName: 'Other');
        }
      });
      expect(await c.load(gameType: 'language', gameName: 'Speaking'), isNull);
      expect(await newer, isTrue);
      expect(service.ranges.length, 1);
    },
  );

  test(
    'superseded load-more does not probe a new games history boundary',
    () async {
      final service = _Service()..more = true;
      final c = _controller(service);
      addTearDown(c.dispose);
      await c.load(gameType: 'language', gameName: 'Speaking');
      Future<bool?>? newer;
      var started = false;
      c.addListener(() {
        if (!started && c.isLoadingMore) {
          started = true;
          newer = c.load(gameType: 'language', gameName: 'Other');
        }
      });
      expect(await c.loadMore(), isNull);
      await newer;
      expect(service.latestReads, 0);
      expect(c.isLoadingMore, isFalse);
    },
  );

  test('loads 30-day inclusive window and caches summary', () async {
    final service = _Service()
      ..page = [
        _row('a', _today, score: 12.5),
        _row('b', _today, score: 30, passed: false),
      ];
    final c = _controller(service);
    addTearDown(c.dispose);
    expect(await c.load(gameType: 'language', gameName: 'Speaking'), true);
    expect(service.ranges.single, (
      _today.subtract(const Duration(days: 29)),
      _today,
      true,
    ));
    expect(c.unlockedMaxLevel, 3);
    expect(c.summary.attempts, 2);
    expect(c.summary.passed, 1);
    expect(c.summary.bestScore, 30);
    expect(identical(c.summary, c.summary), true);
  });
  test(
    'latest fallback moves older-data boundary to the actual record',
    () async {
      final fallback = DateTime(2026, 4, 15, 14, 30);
      final service = _Service()..page = [_row('old', fallback)];
      final c = _controller(service);
      addTearDown(c.dispose);
      await c.load(gameType: 'language', gameName: 'Speaking');
      expect(service.beforeDates, [
        _today.subtract(const Duration(days: 29)),
        fallback,
      ]);
      expect(c.records.single.id, 'old');
      expect(c.hasMore, false);
    },
  );
  test(
    'more skips empty months, deduplicates IDs and preserves rows without IDs',
    () async {
      final oldDate = DateTime(2026, 4, 15);
      final service = _Service()
        ..page = [_row('a', _today)]
        ..more = true;
      final c = _controller(service);
      addTearDown(c.dispose);
      await c.load(gameType: 'language', gameName: 'Speaking');
      service.latest = oldDate;
      service.more = false;
      service.older = [
        _row('a', _today),
        _row('b', oldDate),
        _row(null, oldDate),
        _row('', oldDate),
      ];
      expect(await c.loadMore(), true);
      expect(service.ranges.last, (
        oldDate.subtract(const Duration(days: 29)),
        oldDate,
        false,
      ));
      expect(c.records.length, 4);
      expect(c.summary.attempts, 4);
      expect(c.hasMore, false);
      expect(await c.loadMore(), isNull);
    },
  );
  test('older request cannot overwrite a new game selection', () async {
    final service = _Service()..pendingPage = Completer<List<ModelGameUser>>();
    final c = _controller(service);
    addTearDown(c.dispose);
    final pending = service.pendingPage!;
    final oldRequest = c.load(gameType: 'language', gameName: 'Old');
    service.pendingPage = null;
    service.page = [_row('new', _today)];
    await c.load(gameType: 'language', gameName: 'New');
    pending.complete([_row('old', _today)]);
    expect(await oldRequest, isNull);
    expect(c.records.single.id, 'new');
  });
  test(
    'same-game failure preserves data; switching game clears unrelated records',
    () async {
      final service = _Service()..page = [_row('a', _today)];
      final c = _controller(service);
      addTearDown(c.dispose);
      await c.load(gameType: 'language', gameName: 'Speaking');
      service.fail = true;
      expect(await c.load(gameType: 'language', gameName: 'Speaking'), false);
      expect(c.records.single.id, 'a');
      expect(c.loadError, isNotNull);
      expect(await c.load(gameType: 'language', gameName: 'Other'), false);
      expect(c.records, isEmpty);
      expect(c.isLoading, false);
      service.fail = false;
      expect(await c.load(gameType: 'language', gameName: 'Other'), true);
      expect(c.loadError, isNull);
    },
  );
  test(
    'duplicate more is ignored; late more cannot append into another game',
    () async {
      final service = _Service()
        ..more = true
        ..page = [_row('a', _today)];
      final c = _controller(service);
      addTearDown(c.dispose);
      await c.load(gameType: 'language', gameName: 'Speaking');
      service.pendingLatest = Completer<DateTime?>();
      final oldMore = c.loadMore();
      expect(await c.loadMore(), isNull);
      service.page = [_row('new', _today)];
      await c.load(gameType: 'language', gameName: 'Other');
      service.pendingLatest!.complete(DateTime(2026, 4, 15));
      expect(await oldMore, isNull);
      expect(c.records.single.id, 'new');
      expect(c.isLoadingMore, false);
    },
  );
  test('dispose ignores late completions and notifications', () async {
    final service = _Service()..pendingPage = Completer<List<ModelGameUser>>();
    final c = _controller(service);
    var notifications = 0;
    c.addListener(() => notifications++);
    final request = c.load(gameType: 'language', gameName: 'Speaking');
    final before = notifications;
    c.dispose();
    service.pendingPage!.complete([_row('late', _today)]);
    expect(await request, isNull);
    expect(notifications, before);
    expect(c.records, isEmpty);
  });
}
