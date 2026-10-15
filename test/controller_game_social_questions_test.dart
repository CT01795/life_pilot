import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/game/service_game.dart';
import 'package:life_pilot/game/social/controller_game_social_questions.dart';

MySocialQuestionPage _page(String id, {bool more = true}) =>
    MySocialQuestionPage(
      questions: [
        MySocialQuestion(
          id: id,
          title: id,
          scene: '',
          category: 'friends',
          isActive: true,
          choices: const [],
        ),
      ],
      totalCount: 2,
      hasMore: more,
    );

class _Service extends ServiceGame {
  int categoriesCalls = 0;
  int writes = 0;
  bool fail = false;
  final requests = <(String, String?, String, int)>[];
  Completer<MySocialQuestionPage>? pending;
  Completer<void>? pendingWrite;

  @override
  Future<MySocialQuestionPage> fetchMySocialQuestions({
    String keyword = '',
    String? category,
    String status = 'all',
    int offset = 0,
    int limit = 20,
  }) async {
    requests.add((keyword, category, status, offset));
    if (fail) throw StateError('offline');
    return pending?.future ?? Future.value(_page('$offset', more: offset == 0));
  }

  @override
  Future<List<String>> fetchMySocialQuestionCategories() async {
    categoriesCalls++;
    return ['friends'];
  }

  @override
  Future<void> deleteMySocialQuestion(String id) async {
    writes++;
    if (pendingWrite != null) await pendingWrite!.future;
  }

  @override
  Future<void> setMySocialQuestionActive({
    required String id,
    required bool isActive,
  }) async {
    writes++;
    if (pendingWrite != null) await pendingWrite!.future;
  }
}

void main() {
  test('search and filters reuse category cache; refresh reloads it', () async {
    final service = _Service();
    final c = ControllerGameSocialQuestions(service: service);
    addTearDown(c.dispose);
    await c.load();
    c.applySearch('  hello  ');
    c.selectCategory('friends');
    c.selectStatus(SocialQuestionStatusFilter.inactive);
    await c.load();
    expect(service.requests.last, ('hello', 'friends', 'inactive', 0));
    expect(service.categoriesCalls, 1);
    await c.load(refreshCategories: true);
    expect(service.categoriesCalls, 2);
  });
  test('append uses loaded offset and explicit more state', () async {
    final service = _Service();
    final c = ControllerGameSocialQuestions(service: service);
    addTearDown(c.dispose);
    await c.load();
    await c.load(append: true);
    expect(service.requests.last.$4, 1);
    expect(c.questions.map((q) => q.id), ['0', '1']);
    expect(c.hasMore, false);
    expect(service.categoriesCalls, 1);
  });
  test('old request cannot overwrite a newer search', () async {
    final service = _Service()..pending = Completer<MySocialQuestionPage>();
    final c = ControllerGameSocialQuestions(service: service);
    addTearDown(c.dispose);
    final pending = service.pending!;
    final oldLoad = c.load();
    service.pending = null;
    c.applySearch('new');
    await c.load();
    pending.complete(_page('old'));
    expect(await oldLoad, isNull);
    expect(c.questions.single.id, '0');
  });
  test('append cannot run during refresh or another append', () async {
    final service = _Service();
    final c = ControllerGameSocialQuestions(service: service);
    addTearDown(c.dispose);
    await c.load();
    service.pending = Completer<MySocialQuestionPage>();
    final request = c.load(append: true);
    expect(await c.load(append: true), isNull);
    service.pending!.complete(_page('next', more: false));
    await request;
    expect(service.requests.length, 2);
    service.pending = Completer<MySocialQuestionPage>();
    final refresh = c.load();
    expect(await c.load(append: true), isNull);
    service.pending!.complete(_page('refresh'));
    await refresh;
  });
  test('failure preserves loaded questions; retry succeeds', () async {
    final service = _Service()..fail = true;
    final c = ControllerGameSocialQuestions(service: service);
    addTearDown(c.dispose);
    expect(await c.load(), false);
    expect(c.hasError, true);
    service.fail = false;
    await c.load();
    expect(c.hasError, false);
    service.fail = true;
    expect(await c.load(), false);
    expect(c.questions.single.id, '0');
    expect(c.isLoading, false);
  });
  test(
    'duplicate writes are blocked and successful writes invalidate cache',
    () async {
      final service = _Service();
      final c = ControllerGameSocialQuestions(service: service);
      addTearDown(c.dispose);
      await c.load();
      service.pendingWrite = Completer<void>();
      final write = c.deleteQuestion('0');
      expect(c.isBusy('0'), true);
      expect(await c.setQuestionActive('0', false), false);
      service.pendingWrite!.complete();
      await write;
      expect(c.isBusy('0'), false);
      expect(service.writes, 1);
      await c.load();
      expect(service.categoriesCalls, 2);
    },
  );
  test('dispose ignores late load completion and notifications', () async {
    final service = _Service()..pending = Completer<MySocialQuestionPage>();
    final c = ControllerGameSocialQuestions(service: service);
    var notifications = 0;
    c.addListener(() => notifications++);
    final request = c.load();
    final before = notifications;
    c.dispose();
    service.pending!.complete(_page('late'));
    expect(await request, isNull);
    expect(notifications, before);
    expect(c.questions, isEmpty);
  });
}
