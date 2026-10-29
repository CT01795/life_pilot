import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/game/controller_game_my_questions.dart';
import 'package:life_pilot/game/service_game.dart';

void main() {
  test(
    'new full query clears obsolete load-more state and ignores its result',
    () async {
      final service = _QuestionService();
      final c = ControllerGameMyQuestions(
        service: service,
        gameName: 'Speaking',
      );
      addTearDown(c.dispose);
      await c.load();
      final old = Completer<MyGameQuestionPage>(),
          fresh = Completer<MyGameQuestionPage>();
      service.pendingPage = old;
      final more = c.load(append: true);
      expect(c.isLoadingMore, isTrue);
      c.applySearch('new');
      service.pendingPage = fresh;
      final search = c.load();
      expect(c.isLoadingMore, isFalse);
      expect(c.isLoading, isTrue);
      fresh.complete(_page(9));
      await search;
      old.complete(_page(8));
      expect(await more, isNull);
      expect(c.questions.single.id, '9');
    },
  );

  for (final oldFails in [false, true]) {
    test(
      'new keyword supersedes active loaded search (old failure: $oldFails)',
      () async {
        final service = _QuestionService();
        final c = ControllerGameMyQuestions(
          service: service,
          gameName: 'Speaking',
        );
        addTearDown(c.dispose);
        await c.load();
        final old = Completer<MyGameQuestionPage>(),
            fresh = Completer<MyGameQuestionPage>();
        service.pendingPage = old;
        c.applySearch('old');
        final a = c.load();
        service.pendingPage = fresh;
        c.applySearch('new');
        final b = c.load();
        expect(service.calls.map((call) => call.$1), ['', 'old', 'new']);
        fresh.complete(_page(9));
        expect(await b, isTrue);
        if (oldFails) {
          old.completeError(StateError('old'));
        } else {
          old.complete(_page(8));
        }
        expect(await a, isNull);
        expect(c.questions.single.id, '9');
        expect(c.hasError, isFalse);
        expect(c.isLoading, isFalse);
      },
    );
  }
  for (final groupChange in [true, false]) {
    test(
      'group/status change supersedes pending query (group: $groupChange)',
      () async {
        final service = _QuestionService()..groupData.add('other');
        final c = ControllerGameMyQuestions(
          service: service,
          gameName: 'Speaking',
        );
        addTearDown(c.dispose);
        await c.load();
        final old = Completer<MyGameQuestionPage>(),
            fresh = Completer<MyGameQuestionPage>();
        service.pendingPage = old;
        final a = c.load();
        if (groupChange) {
          c.selectGroup('other');
        } else {
          c.selectStatus(QuestionStatusFilter.inactive);
        }
        service.pendingPage = fresh;
        final b = c.load();
        expect(service.calls.length, 3);
        expect(service.calls.last.$2, groupChange ? 'other' : null);
        expect(service.calls.last.$3, groupChange ? 'all' : 'inactive');
        fresh.complete(_page(9));
        await b;
        old.complete(_page(8));
        await a;
        expect(c.questions.single.id, '9');
      },
    );
  }
  for (final hasLoaded in [false, true]) {
    test(
      'same active query does not send duplicate read (loaded: $hasLoaded)',
      () async {
        final service = _QuestionService();
        final c = ControllerGameMyQuestions(
          service: service,
          gameName: 'Speaking',
        );
        addTearDown(c.dispose);
        if (hasLoaded) await c.load();
        final pending = Completer<MyGameQuestionPage>();
        service.pendingPage = pending;
        final first = c.load();
        await c.load();
        expect(service.calls.length, hasLoaded ? 2 : 1);
        pending.complete(_page(0));
        await first;
      },
    );
  }
  test(
    'changed filters cannot append into the previously loaded query',
    () async {
      final service = _QuestionService();
      final c = ControllerGameMyQuestions(
        service: service,
        gameName: 'Speaking',
      );
      addTearDown(c.dispose);
      await c.load();
      c.applySearch('new');
      await c.load(append: true);
      expect(service.calls.length, 1);
      expect(c.questions.single.id, '0');
      await c.load();
      expect(service.calls.last.$1, 'new');
      await c.load(append: true);
      expect(service.calls.last.$4, 1);
    },
  );

  test(
    'question snapshots keep identity and do not alias service lists',
    () async {
      final page = _page(0);
      final service = _QuestionService()..suppliedPage = page;
      final c = ControllerGameMyQuestions(
        service: service,
        gameName: 'Speaking',
      );
      addTearDown(c.dispose);
      await c.load();
      final snapshot = c.questions;
      expect(c.questions, same(snapshot));
      expect(() => snapshot.clear(), throwsUnsupportedError);
      page.questions.clear();
      expect(c.questions.length, 1);
      expect(c.hasMore, isTrue);
    },
  );
  test(
    'group snapshots do not alias service lists and remain cached across search',
    () async {
      final service = _QuestionService();
      final c = ControllerGameMyQuestions(
        service: service,
        gameName: 'Speaking',
      );
      addTearDown(c.dispose);
      await c.load();
      final groups = c.groups;
      expect(c.groups, same(groups));
      expect(() => groups.clear(), throwsUnsupportedError);
      service.groupData.add('external');
      expect(c.groups, ['grammar']);
      c.applySearch('new');
      await c.load();
      expect(c.groups, same(groups));
      expect(service.groupCalls, 1);
    },
  );
  test(
    'appending replaces the snapshot without altering prior views',
    () async {
      final service = _QuestionService();
      final c = ControllerGameMyQuestions(
        service: service,
        gameName: 'Speaking',
      );
      addTearDown(c.dispose);
      await c.load();
      final first = c.questions, groups = c.groups;
      await c.load(append: true);
      expect(first.map((q) => q.id), ['0']);
      expect(c.questions.map((q) => q.id), ['0', '1']);
      expect(c.groups, same(groups));
      expect(c.hasMore, isFalse);
    },
  );
  test(
    'reentrant new search prevents obsolete initial question/group reads',
    () async {
      final service = _QuestionService();
      final c = ControllerGameMyQuestions(
        service: service,
        gameName: 'Speaking',
      );
      addTearDown(c.dispose);
      Future<bool?>? fresh;
      var changed = false;
      c.addListener(() {
        if (!changed && c.isLoading) {
          changed = true;
          c.applySearch('new');
          fresh = c.load();
        }
      });
      expect(await c.load(), isNull);
      expect(await fresh, isTrue);
      expect(service.calls.length, 1);
      expect(service.calls.single.$1, 'new');
      expect(service.groupCalls, 1);
    },
  );

  test('a write during loading leaves the group cache invalidated', () async {
    final service = _QuestionService();
    final controller = ControllerGameMyQuestions(
      service: service,
      gameName: 'Speaking',
    );
    addTearDown(controller.dispose);
    await controller.load();
    final pending = Completer<MyGameQuestionPage>();
    service.pendingPage = pending;
    final refresh = controller.load(refreshGroups: true);
    await controller.setQuestionActive('q1', false);
    pending.complete(_page(0));
    await refresh;
    service.pendingPage = null;
    await controller.load();
    expect(service.groupCalls, 3);
  });

  test(
    'search and filter changes reuse cached groups until explicit refresh',
    () async {
      final service = _QuestionService();
      final controller = ControllerGameMyQuestions(
        service: service,
        gameName: 'Speaking',
      );
      addTearDown(controller.dispose);
      await controller.load();
      controller.applySearch('new');
      await controller.load();
      controller.selectGroup('grammar');
      await controller.load();
      controller.selectStatus(QuestionStatusFilter.inactive);
      await controller.load();
      expect(service.calls, hasLength(4));
      expect(service.groupCalls, 1);
      await controller.load(refreshGroups: true);
      expect(service.groupCalls, 2);
    },
  );

  test(
    'successful writes invalidate the group cache for the next load',
    () async {
      final service = _QuestionService();
      final controller = ControllerGameMyQuestions(
        service: service,
        gameName: 'Speaking',
      );
      addTearDown(controller.dispose);
      await controller.load();
      await controller.deleteQuestion('q1');
      await controller.load();
      expect(service.groupCalls, 2);
      await controller.setQuestionActive('q2', false);
      await controller.load();
      expect(service.groupCalls, 3);
    },
  );

  test('pagination is suppressed while a full refresh is pending', () async {
    final service = _QuestionService();
    final controller = ControllerGameMyQuestions(
      service: service,
      gameName: 'Speaking',
    );
    addTearDown(controller.dispose);
    await controller.load();
    final pending = Completer<MyGameQuestionPage>();
    service.pendingPage = pending;
    final refresh = controller.load(refreshGroups: true);
    final callsBefore = service.calls.length;
    await controller.load(append: true);
    expect(service.calls.length, callsBefore);
    pending.complete(_page(0));
    await refresh;
  });

  test('unchanged filter values do not notify the View again', () {
    final controller = ControllerGameMyQuestions(
      service: _QuestionService(),
      gameName: 'Speaking',
    );
    addTearDown(controller.dispose);
    var notifications = 0;
    controller.addListener(() => notifications++);
    controller.applySearch(' ');
    controller.selectGroup(null);
    controller.selectStatus(QuestionStatusFilter.all);
    expect(notifications, 0);
    controller.applySearch('new');
    expect(notifications, 1);
  });

  test(
    'a newer request cannot be overwritten by an older completion',
    () async {
      final oldPage = Completer<MyGameQuestionPage>();
      final newPage = Completer<MyGameQuestionPage>();
      final service = _QuestionService()..pendingPage = oldPage;
      final controller = ControllerGameMyQuestions(
        service: service,
        gameName: 'Speaking',
      );
      addTearDown(controller.dispose);
      final oldRequest = controller.load();
      service.pendingPage = newPage;
      controller.applySearch('new');
      final newRequest = controller.load();
      newPage.complete(_page(1));
      expect(await newRequest, isTrue);
      oldPage.complete(_page(0));
      expect(await oldRequest, isNull);
      expect(controller.questions.single.id, '1');
    },
  );

  test(
    'controller applies filters and appends pages without refetching groups',
    () async {
      final service = _QuestionService();
      final controller = ControllerGameMyQuestions(
        service: service,
        gameName: 'Speaking',
      );
      addTearDown(controller.dispose);
      controller.applySearch('  hello  ');
      controller.selectGroup('grammar');
      controller.selectStatus(QuestionStatusFilter.active);
      expect(await controller.load(), isTrue);
      expect(service.calls.single, ('hello', 'grammar', 'active', 0));
      expect(controller.hasMore, isTrue);
      expect(await controller.load(append: true), isTrue);
      expect(service.calls.last.$4, 1);
      expect(service.groupCalls, 1);
      expect(controller.questions.map((q) => q.id), ['0', '1']);
      expect(controller.hasMore, isFalse);
      expect(() => controller.questions.clear(), throwsUnsupportedError);
    },
  );

  test('missing selected group triggers an unfiltered reload', () async {
    final service = _QuestionService();
    final controller = ControllerGameMyQuestions(
      service: service,
      gameName: 'Speaking',
    );
    addTearDown(controller.dispose);
    controller.selectGroup('removed');
    await controller.load();
    expect(controller.selectedGroup, isNull);
    expect(service.calls.map((c) => c.$2), ['removed', null]);
  });

  test(
    'initial failure exposes retry state and a successful retry clears it',
    () async {
      final service = _QuestionService()..failLoad = true;
      final controller = ControllerGameMyQuestions(
        service: service,
        gameName: 'Speaking',
      );
      addTearDown(controller.dispose);
      expect(await controller.load(), isFalse);
      expect(controller.hasError, isTrue);
      expect(controller.isLoading, isFalse);
      service.failLoad = false;
      expect(await controller.load(), isTrue);
      expect(controller.hasError, isFalse);
      expect(controller.hasLoaded, isTrue);
    },
  );

  test(
    'pending completion after disposal does not change list or notify',
    () async {
      final pending = Completer<MyGameQuestionPage>();
      final service = _QuestionService()..pendingPage = pending;
      final controller = ControllerGameMyQuestions(
        service: service,
        gameName: 'Speaking',
      );
      var notifications = 0;
      controller.addListener(() => notifications++);
      final request = controller.load();
      controller.dispose();
      final count = notifications;
      pending.complete(_page(0));
      expect(await request, isNull);
      expect(controller.questions, isEmpty);
      expect(notifications, count);
    },
  );

  test(
    'failed delete releases busy state and keeps the error for View',
    () async {
      final service = _QuestionService()..failDelete = true;
      final controller = ControllerGameMyQuestions(
        service: service,
        gameName: 'Speaking',
      );
      addTearDown(controller.dispose);
      final operation = controller.deleteQuestion('q1');
      expect(controller.isBusy('q1'), isTrue);
      await expectLater(operation, throwsStateError);
      expect(controller.isBusy('q1'), isFalse);
    },
  );

  test(
    'active-state changes reach the service and release busy state',
    () async {
      final service = _QuestionService();
      final controller = ControllerGameMyQuestions(
        service: service,
        gameName: 'Speaking',
      );
      addTearDown(controller.dispose);
      await controller.setQuestionActive('q1', false);
      expect(service.updated, ('q1', false));
      expect(controller.isBusy('q1'), isFalse);
    },
  );
}

MyGameQuestionPage _page(int offset) => MyGameQuestionPage(
  questions: [
    MyGameQuestion(
      id: '$offset',
      question: 'Q',
      answer: 'A',
      group: 'grammar',
      level: 1,
      isActive: true,
    ),
  ],
  totalCount: 2,
);

class _QuestionService extends ServiceGame {
  final calls = <(String, String?, String, int)>[];
  int groupCalls = 0;
  bool failLoad = false;
  bool failDelete = false;
  MyGameQuestionPage? suppliedPage;
  final groupData = <String>['grammar'];
  Completer<MyGameQuestionPage>? pendingPage;
  (String, bool)? updated;

  @override
  Future<MyGameQuestionPage> fetchMyQuestions({
    required String gameName,
    String keyword = '',
    String? group,
    String status = 'all',
    int offset = 0,
    int limit = 20,
  }) async {
    calls.add((keyword, group, status, offset));
    if (failLoad) throw StateError('load failed');
    if (pendingPage != null) return pendingPage!.future;
    return suppliedPage ?? _page(offset);
  }

  @override
  Future<List<String>> fetchMyQuestionGroupsForManagement({
    required String gameName,
  }) async {
    groupCalls++;
    return groupData;
  }

  @override
  Future<void> deleteMyQuestion({
    required String gameName,
    required String questionId,
  }) async {
    if (failDelete) throw StateError('delete failed');
  }

  @override
  Future<void> setMyQuestionActive({
    required String gameName,
    required String questionId,
    required bool isActive,
  }) async {
    updated = (questionId, isActive);
  }
}
