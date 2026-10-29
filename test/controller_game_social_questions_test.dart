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
  bool failCategories = false;
  final categoryRows = <String>['friends'];
  MySocialQuestionPage? supplied;
  Completer<List<String>>? pendingCategories;
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
  }) {
    requests.add((keyword, category, status, offset));
    if (fail) throw StateError('offline');
    return pending?.future ??
        Future.value(supplied ?? _page('$offset', more: offset == 0));
  }

  @override
  Future<List<String>> fetchMySocialQuestionCategories() {
    categoriesCalls++;
    if (failCategories) throw StateError('categories offline');
    return pendingCategories?.future ?? Future.value(categoryRows);
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
  for (final filter in ['keyword', 'category', 'status']) {
    test('changed $filter cannot append using an old query offset', () async {
      final service = _Service();
      final c = ControllerGameSocialQuestions(service: service);
      addTearDown(c.dispose);
      await c.load();
      if (filter == 'keyword') {
        c.applySearch('new');
      } else if (filter == 'category') {
        c.selectCategory('family');
      } else {
        c.selectStatus(SocialQuestionStatusFilter.inactive);
      }
      expect(await c.load(append: true), isNull);
      expect(service.requests.length, 1);
      await c.load();
      expect(service.requests.last.$4, 0);
      expect(service.categoriesCalls, 1);
    });
  }
  test(
    'identical active queries are ignored; explicit category refresh still starts a fresh read',
    () async {
      final service = _Service()..pending = Completer<MySocialQuestionPage>();
      final c = ControllerGameSocialQuestions(service: service);
      addTearDown(c.dispose);
      final first = c.load();
      final old = service.pending!;
      expect(await c.load(), isNull);
      expect(service.requests.length, 1);
      service.pending = Completer<MySocialQuestionPage>();
      final fresh = c.load(refreshCategories: true);
      expect(service.categoriesCalls, 2);
      service.pending!.complete(_page('fresh'));
      await fresh;
      old.complete(_page('old'));
      expect(await first, isNull);
      expect(c.questions.single.id, 'fresh');
    },
  );
  test(
    'reentrant search notification skips the superseded unsent query',
    () async {
      final service = _Service();
      final c = ControllerGameSocialQuestions(service: service);
      addTearDown(c.dispose);
      Future<bool?>? newer;
      var started = false;
      c.addListener(() {
        if (started || !c.isLoading) return;
        started = true;
        c.applySearch('latest');
        newer = c.load();
      });
      expect(await c.load(), isNull);
      expect(await newer, isTrue);
      expect(service.requests.single, ('latest', null, 'all', 0));
      expect(service.categoriesCalls, 1);
    },
  );
  test(
    'question and category snapshots are stable and isolated from service lists',
    () async {
      final supplied = _page('one');
      final service = _Service()..supplied = supplied;
      final c = ControllerGameSocialQuestions(service: service);
      addTearDown(c.dispose);
      await c.load();
      final questions = c.questions, categories = c.categories;
      expect(c.questions, same(questions));
      expect(c.categories, same(categories));
      supplied.questions.clear();
      service.categoryRows.add('family');
      expect(questions.single.id, 'one');
      expect(categories, ['friends']);
      expect(() => questions.clear(), throwsUnsupportedError);
      expect(() => categories.clear(), throwsUnsupportedError);
      service.supplied = _page('two');
      c.applySearch('new');
      await c.load();
      expect(c.categories, same(categories));
      expect(questions.single.id, 'one');
      await c.load(refreshCategories: true);
      expect(c.categories, ['friends', 'family']);
      expect(categories, ['friends']);
    },
  );
  for (final fails in [false, true]) {
    test(
      'full reload clears obsolete paging state and ignores its ${fails ? 'error' : 'result'}',
      () async {
        final service = _Service();
        final c = ControllerGameSocialQuestions(service: service);
        addTearDown(c.dispose);
        await c.load();
        final old = Completer<MySocialQuestionPage>();
        service.pending = old;
        final more = c.load(append: true);
        expect(c.isLoadingMore, isTrue);
        final fresh = Completer<MySocialQuestionPage>();
        service.pending = fresh;
        c.applySearch('new');
        final reload = c.load();
        expect(c.isLoadingMore, isFalse);
        if (fails) {
          old.completeError(StateError('obsolete'));
        } else {
          old.complete(_page('obsolete'));
        }
        expect(await more, isNull);
        expect(c.isLoading, isTrue);
        fresh.complete(_page('fresh'));
        await reload;
        expect(c.questions.single.id, 'fresh');
        service.pending = null;
        await c.load(append: true);
        expect(service.requests.last.$4, 1);
        expect(c.questions.map((q) => q.id), ['fresh', '1']);
      },
    );
  }
  for (final synchronous in [false, true]) {
    for (final questionsFail in [false, true]) {
      test(
        'fail-fast questions=$questionsFail, synchronous=$synchronous observes late sibling failures',
        () async {
          final service = _Service()
            ..pending = Completer<MySocialQuestionPage>()
            ..pendingCategories = Completer<List<String>>();
          if (synchronous) {
            service.fail = questionsFail;
            service.failCategories = !questionsFail;
          }
          final c = ControllerGameSocialQuestions(service: service);
          addTearDown(c.dispose);
          final pending = c.load();
          if (!synchronous) {
            if (questionsFail) {
              service.pending!.completeError(StateError('questions'));
            } else {
              service.pendingCategories!.completeError(
                StateError('categories'),
              );
            }
          }
          expect(await pending, isFalse);
          expect(c.isLoading, isFalse);
          expect(c.hasError, isTrue);
          if (questionsFail) {
            service.pendingCategories!.completeError(
              StateError('late categories'),
            );
          } else {
            service.pending!.completeError(StateError('late questions'));
          }
          await Future<void>.delayed(Duration.zero);
          service.pending = null;
          service.pendingCategories = null;
          service.fail = service.failCategories = false;
          expect(await c.load(), isTrue);
          expect(c.hasError, isFalse);
        },
      );
    }
  }
  for (final categoriesWait in [false, true]) {
    testWidgets(
      'timeout waiting for ${categoriesWait ? 'categories' : 'questions'} is retryable and ignores late results',
      (tester) async {
        final service = _Service();
        if (categoriesWait) {
          service.pendingCategories = Completer<List<String>>();
        } else {
          service.pending = Completer<MySocialQuestionPage>();
        }
        final c = ControllerGameSocialQuestions(
          service: service,
          requestTimeout: const Duration(milliseconds: 20),
        );
        addTearDown(c.dispose);
        final pending = c.load();
        await tester.pump(const Duration(milliseconds: 21));
        expect(await pending, isFalse);
        expect(c.hasError, isTrue);
        service.pending?.complete(_page('old'));
        service.pendingCategories?.complete(['old']);
        await tester.pump();
        expect(c.questions, isEmpty);
        expect(c.categories, isEmpty);
        service.pending = null;
        service.pendingCategories = null;
        final retry = c.load();
        await tester.pump();
        expect(await retry, isTrue);
        expect(c.questions.single.id, '0');
        expect(c.categories, ['friends']);
      },
    );
  }
  test('disposed controller ignores filter edits', () {
    final c = ControllerGameSocialQuestions(service: _Service());
    c.dispose();
    c.applySearch('new');
    c.selectCategory('family');
    c.selectStatus(SocialQuestionStatusFilter.inactive);
    expect(c.appliedKeyword, '');
    expect(c.selectedCategory, isNull);
    expect(c.status, SocialQuestionStatusFilter.all);
  });

  testWidgets('paging timeout preserves rows and retries the same offset', (
    tester,
  ) async {
    final service = _Service();
    final c = ControllerGameSocialQuestions(
      service: service,
      requestTimeout: const Duration(milliseconds: 20),
    );
    addTearDown(c.dispose);
    final initial = c.load();
    await tester.pump();
    await initial;
    final snapshot = c.questions;
    final old = Completer<MySocialQuestionPage>();
    service.pending = old;
    final more = c.load(append: true);
    await tester.pump(const Duration(milliseconds: 21));
    expect(await more, isFalse);
    expect(c.questions, same(snapshot));
    expect(c.isLoadingMore, isFalse);
    expect(c.hasMore, isTrue);
    service.pending = null;
    final retry = c.load(append: true);
    await tester.pump();
    expect(await retry, isTrue);
    expect(service.requests.map((r) => r.$4), [0, 1, 1]);
    old.complete(_page('late'));
    await tester.pump();
    expect(c.questions.map((q) => q.id), ['0', '1']);
    expect(service.categoriesCalls, 1);
  });

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
