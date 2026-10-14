import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/game/controller_game_my_questions.dart';
import 'package:life_pilot/game/service_game.dart';

void main() {
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
    return _page(offset);
  }

  @override
  Future<List<String>> fetchMyQuestionGroupsForManagement({
    required String gameName,
  }) async {
    groupCalls++;
    return ['grammar'];
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
