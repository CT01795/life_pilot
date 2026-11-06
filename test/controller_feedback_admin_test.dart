import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/feedback/controller_feedback_admin.dart';
import 'package:life_pilot/feedback/model_feedback.dart';
import 'package:life_pilot/feedback/model_feedback_page.dart';
import 'package:life_pilot/feedback/service_feedback.dart';

class _Auth extends ControllerAuth {
  String account = 'admin@example.com';
  @override
  String get currentAccount => account;
  @override
  bool get isSysAdmin => true;
  void switchAccount() {
    account = 'other@example.com';
    notifyListeners();
  }
}

Map<String, dynamic> row(int id, {String status = 'pending'}) => {
  'id': id,
  'subject': 'Feedback $id',
  'content': 'Content',
  'created_at': '2026-11-01T00:00:00Z',
  'status': status,
};

class _Service extends ServiceFeedback {
  List<Map<String, dynamic>> rows = [row(1)];
  bool more = false, failLoad = false, failUpdate = false, failImages = false;
  int loads = 0, updates = 0, imageReads = 0;
  final cursors = <FeedbackCursor?>[];
  final filters = <Set<String>>[];
  Completer<FeedbackPage>? pending;
  Completer<void>? updating;
  Completer<List<String>>? images;
  @override
  Future<FeedbackPage> loadFeedbackPage({
    required Set<String> statuses,
    FeedbackCursor? before,
  }) async {
    loads++;
    cursors.add(before);
    filters.add(Set.of(statuses));
    if (failLoad) throw StateError('offline');
    if (pending != null) return pending!.future;
    final page = FeedbackPage.fromRows(rows);
    return FeedbackPage(rows: page.rows, hasMore: more, cursor: page.cursor);
  }

  @override
  Future<void> updateFeedback({required ModelFeedback feedback}) async {
    updates++;
    if (updating != null) await updating!.future;
    if (failUpdate) throw StateError('write failed');
  }

  @override
  Future<List<String>> loadScreenshots(int id) async {
    imageReads++;
    if (failImages) throw StateError('image failed');
    return images?.future ?? ['encoded'];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Auth auth;
  late _Service service;
  late ControllerFeedbackAdmin controller;
  setUp(() {
    auth = _Auth();
    service = _Service();
    controller = ControllerFeedbackAdmin(service, auth);
  });
  tearDown(() {
    if (!controller.notifierDisposed) controller.dispose();
    auth.dispose();
  });

  test(
    'initial load uses paged service and never fetches screenshots',
    () async {
      await controller.loadFeedback();
      expect(controller.feedbackList.single.id, 1);
      expect(service.cursors.single, isNull);
      expect(service.filters.single, {'pending', 'in_progress'});
      expect(service.imageReads, 0);
    },
  );
  test('empty result has no continuation action', () async {
    service.rows = [];
    await controller.loadFeedback();
    expect(controller.feedbackList, isEmpty);
    expect(controller.hasMore, isFalse);
    expect(controller.isLoadingMore, isFalse);
    expect(controller.loadMoreError, isNull);
  });
  test(
    'initial failure is retryable and refresh failure retains records',
    () async {
      service.failLoad = true;
      await controller.loadFeedback();
      expect(controller.loadError, isStateError);
      service.failLoad = false;
      await controller.loadFeedback();
      final saved = controller.feedbackList;
      service.failLoad = true;
      await controller.loadFeedback();
      expect(controller.feedbackList, same(saved));
      expect(controller.isLoading, isFalse);
    },
  );
  test(
    'append failure retries the same cursor and preserves loaded models',
    () async {
      service.more = true;
      await controller.loadFeedback();
      final first = controller.feedbackList.single;
      service.failLoad = true;
      await controller.loadMore();
      expect(controller.loadMoreError, isStateError);
      expect(controller.feedbackList.single, same(first));
      final failedCursor = service.cursors.last;
      service.failLoad = false;
      service.more = false;
      service.rows = [row(2)];
      await controller.loadMore();
      expect(service.cursors.last, same(failedCursor));
      expect(controller.feedbackList.map((r) => r.id), containsAll([1, 2]));
      expect(controller.loadMoreError, isNull);
      expect(controller.hasMore, isFalse);
    },
  );
  test(
    'filter change queries server from first page with immutable filters',
    () async {
      await controller.loadFeedback();
      final previous = controller.selectedStatuses;
      controller.toggleStatus('completed');
      await Future<void>.delayed(Duration.zero);
      expect(service.cursors.last, isNull);
      expect(service.filters.last, contains('completed'));
      expect(previous, isNot(contains('completed')));
      expect(() => controller.selectedStatuses.clear(), throwsUnsupportedError);
      expect(() => controller.visibleFeedback.clear(), throwsUnsupportedError);
    },
  );
  test('empty filter performs no request and cancels existing page', () async {
    service.pending = Completer<FeedbackPage>();
    final load = controller.loadFeedback();
    controller.toggleStatus('pending');
    controller.toggleStatus('in_progress');
    service.pending!.complete(FeedbackPage.fromRows([row(1)]));
    await load;
    expect(controller.feedbackList, isEmpty);
    expect(controller.isLoading, isFalse);
  });
  for (final dispose in [false, true]) {
    test(
      'late page cannot publish after scope change (dispose=$dispose)',
      () async {
        service.pending = Completer<FeedbackPage>();
        final load = controller.loadFeedback();
        if (dispose) {
          controller.dispose();
        } else {
          auth.switchAccount();
        }
        service.pending!.complete(FeedbackPage.fromRows([row(9)]));
        await load;
        expect(controller.feedbackList, isEmpty);
      },
    );
  }
  for (final lateFailure in [false, true]) {
    test(
      'timeout releases request and ignores late page (error=$lateFailure)',
      () async {
        controller.dispose();
        controller = ControllerFeedbackAdmin(
          service,
          auth,
          requestTimeout: const Duration(milliseconds: 20),
        );
        final delayed = service.pending = Completer<FeedbackPage>();
        await controller.loadFeedback();
        expect(controller.loadError, isA<TimeoutException>());
        service.pending = null;
        service.rows = [row(2)];
        await controller.loadFeedback();
        if (lateFailure) {
          delayed.completeError(StateError('late'));
        } else {
          delayed.complete(FeedbackPage.fromRows([row(99)]));
        }
        await Future<void>.delayed(Duration.zero);
        expect(controller.feedbackList.single.id, 2);
        expect(controller.loadError, isNull);
      },
    );
  }
  test(
    'refresh supersedes an old append and ignores its late failure',
    () async {
      service.more = true;
      await controller.loadFeedback();
      final old = service.pending = Completer<FeedbackPage>();
      final append = controller.loadMore();
      service.pending = null;
      service.rows = [row(3)];
      service.more = false;
      await controller.loadFeedback();
      old.completeError(StateError('obsolete'));
      await append;
      expect(controller.feedbackList.single.id, 3);
      expect(controller.loadMoreError, isNull);
    },
  );
  test('append deduplicates and retains status ordering', () async {
    service.rows = [row(1), row(2, status: 'in_progress')];
    service.more = true;
    await controller.loadFeedback();
    service.rows = [row(1), row(3)];
    service.more = false;
    await controller.loadMore();
    expect(controller.feedbackList.map((r) => r.id), [2, 1, 3]);
  });
  test('failed status update preserves fields; retry succeeds', () async {
    await controller.loadFeedback();
    final item = controller.feedbackList.single;
    service.failUpdate = true;
    expect(
      await controller.updateStatus(item, 'completed', auth.account),
      isFalse,
    );
    expect(item.status, 'pending');
    expect(item.dealAt, isNull);
    service.failUpdate = false;
    expect(
      await controller.updateStatus(item, 'completed', auth.account),
      isTrue,
    );
    expect(item.status, 'completed');
    expect(item.dealAt!.isUtc, isTrue);
  });
  test(
    'duplicate writes, filtering and refresh blocked during a status write',
    () async {
      await controller.loadFeedback();
      final item = controller.feedbackList.single;
      service.updating = Completer<void>();
      final write = controller.updateStatus(item, 'in_progress', auth.account);
      expect(
        await controller.updateStatus(item, 'completed', auth.account),
        isNull,
      );
      controller.toggleStatus('completed');
      await controller.loadFeedback();
      await controller.loadMore();
      expect(service.loads, 1);
      expect(service.updates, 1);
      expect(controller.selectedStatuses, isNot(contains('completed')));
      service.updating!.complete();
      expect(await write, isTrue);
    },
  );
  test(
    'same status is a no-op; replaced models cannot submit writes',
    () async {
      await controller.loadFeedback();
      final old = controller.feedbackList.single;
      expect(
        await controller.updateStatus(old, 'pending', auth.account),
        isTrue,
      );
      await controller.loadFeedback();
      expect(
        await controller.updateStatus(old, 'completed', auth.account),
        isNull,
      );
      expect(service.updates, 0);
    },
  );
  test(
    'late successful write cannot mutate a model from an old account',
    () async {
      await controller.loadFeedback();
      final item = controller.feedbackList.single;
      service.updating = Completer<void>();
      final write = controller.updateStatus(item, 'completed', auth.account);
      auth.switchAccount();
      service.updating!.complete();
      expect(await write, isNull);
      expect(item.status, 'pending');
      expect(controller.feedbackList, isEmpty);
    },
  );
  test('screenshots remain lazy, coalesced and retryable', () async {
    await controller.loadFeedback();
    final item = controller.feedbackList.single;
    service.failImages = true;
    await expectLater(controller.loadScreenshots(item), throwsStateError);
    service.failImages = false;
    service.images = Completer<List<String>>();
    final a = controller.loadScreenshots(item),
        b = controller.loadScreenshots(item);
    service.images!.complete(['encoded']);
    await Future.wait([a, b]);
    await controller.loadScreenshots(item);
    expect(service.imageReads, 2);
    expect(item.screenshot, ['encoded']);
  });
  test('late private screenshots are discarded after account change', () async {
    await controller.loadFeedback();
    final item = controller.feedbackList.single;
    service.images = Completer<List<String>>();
    final checked = expectLater(
      controller.loadScreenshots(item),
      throwsStateError,
    );
    auth.switchAccount();
    service.images!.complete(['private']);
    await checked;
    expect(item.screenshot, isNull);
  });
}
