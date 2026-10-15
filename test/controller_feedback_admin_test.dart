import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/feedback/controller_feedback_admin.dart';
import 'package:life_pilot/feedback/model_feedback.dart';
import 'package:life_pilot/feedback/service_feedback.dart';

class _Auth extends ControllerAuth {
  String account = 'a@example.com';
  @override
  String get currentAccount => account;
  void switchAccount() {
    account = 'b@example.com';
    notifyListeners();
  }
}

Map<String, dynamic> _row(int id, {String status = 'pending'}) => {
  'id': id,
  'subject': 'Feedback $id',
  'content': 'Content',
  'created_at': '2026-10-01T00:00:00Z',
  'status': status,
};

class _Service extends ServiceFeedback {
  List<dynamic> rows = [_row(1)];
  bool more = true;
  bool failUpdate = false;
  int loads = 0;
  int probes = 0;
  int updates = 0;
  ModelFeedback? proposed;
  Completer<List<dynamic>>? pendingLoad;
  Completer<DateTime?>? pendingOlder;
  Completer<void>? pendingUpdate;
  @override
  Future<List<dynamic>> loadFeedback({
    required DateTime dateFrom,
    required DateTime dateTo,
  }) async {
    loads++;
    return pendingLoad == null ? rows : pendingLoad!.future;
  }

  @override
  Future<bool> hasFeedbackBefore(DateTime before) async {
    probes++;
    return more;
  }

  @override
  Future<DateTime?> latestFeedbackDateBefore(DateTime before) async =>
      pendingOlder == null ? DateTime(2026, 1, 1) : pendingOlder!.future;
  @override
  Future<void> updateFeedback({required ModelFeedback feedback}) async {
    updates++;
    proposed = feedback;
    if (pendingUpdate != null) await pendingUpdate!.future;
    if (failUpdate) throw StateError('offline');
  }
}

void main() {
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

  test('filter cache is read-only and invalidated on filter changes', () async {
    await controller.loadFeedback();
    final cached = controller.visibleFeedback;
    expect(identical(cached, controller.visibleFeedback), isTrue);
    expect(() => cached.clear(), throwsUnsupportedError);
    expect(() => controller.feedbackList.clear(), throwsUnsupportedError);
    expect(() => controller.selectedStatuses.clear(), throwsUnsupportedError);
    controller.toggleStatus('pending');
    expect(controller.visibleFeedback, isEmpty);
  });

  test(
    'failed persistence leaves displayed fields and cache unchanged; retry succeeds',
    () async {
      await controller.loadFeedback();
      final feedback = controller.feedbackList.single;
      final cached = controller.visibleFeedback;
      service.failUpdate = true;
      expect(
        await controller.updateStatus(feedback, 'completed', auth.account),
        isFalse,
      );
      expect(feedback.status, 'pending');
      expect(feedback.dealAt, isNull);
      expect(identical(cached, controller.visibleFeedback), isTrue);
      expect(controller.isUpdating(1), isFalse);
      service.failUpdate = false;
      expect(
        await controller.updateStatus(feedback, 'completed', auth.account),
        isTrue,
      );
      expect(feedback.isOk, isTrue);
      expect(feedback.dealBy, auth.account);
      expect(feedback.dealAt!.isUtc, isTrue);
      expect(controller.visibleFeedback, isEmpty);
    },
  );

  test('duplicate update and refresh are blocked during persistence', () async {
    await controller.loadFeedback();
    service.pendingUpdate = Completer<void>();
    final feedback = controller.feedbackList.single;
    final pending = controller.updateStatus(
      feedback,
      'in_progress',
      auth.account,
    );
    expect(feedback.status, 'pending');
    expect(service.proposed!.status, 'in_progress');
    expect(controller.isUpdating(1), isTrue);
    expect(
      await controller.updateStatus(feedback, 'completed', auth.account),
      isNull,
    );
    await controller.loadFeedback();
    await controller.loadMore();
    expect(service.loads, 1);
    expect(service.updates, 1);
    service.pendingUpdate!.complete();
    expect(await pending, isTrue);
    expect(feedback.status, 'in_progress');
  });

  test(
    'switching accounts clears data and ignores a late initial load',
    () async {
      service.pendingLoad = Completer<List<dynamic>>();
      final pending = controller.loadFeedback();
      auth.switchAccount();
      service.pendingLoad!.complete([_row(9)]);
      await pending;
      expect(controller.feedbackList, isEmpty);
      expect(controller.isLoading, isFalse);
      expect(service.probes, 0);
    },
  );

  test(
    'account switch ignores late persistence and releases busy state',
    () async {
      await controller.loadFeedback();
      final old = controller.feedbackList.single;
      service.pendingUpdate = Completer<void>();
      final pending = controller.updateStatus(old, 'completed', auth.account);
      auth.switchAccount();
      service.pendingUpdate!.complete();
      expect(await pending, isNull);
      expect(old.status, 'pending');
      expect(controller.feedbackList, isEmpty);
      expect(controller.isUpdating(1), isFalse);
    },
  );

  test(
    'refresh supersedes older pagination without merging stale rows',
    () async {
      await controller.loadFeedback();
      service.pendingOlder = Completer<DateTime?>();
      final pagination = controller.loadMore();
      service.rows = [_row(2)];
      await controller.loadFeedback();
      service.pendingOlder!.complete(DateTime(2026, 1, 1));
      await pagination;
      expect(controller.feedbackList.single.id, 2);
      expect(service.loads, 2);
      expect(controller.isLoadingMore, isFalse);
    },
  );

  test('pagination deduplicates and retains status/date order', () async {
    service.rows = [_row(1), _row(2, status: 'in_progress')];
    await controller.loadFeedback();
    service.rows = [_row(1), _row(3, status: 'completed')];
    service.more = false;
    await controller.loadMore();
    expect(controller.feedbackList.map((row) => row.id), [2, 1, 3]);
    expect(controller.hasMore, isFalse);
  });

  test(
    'markAsDone uses guarded persistence; pending clears admin metadata',
    () async {
      await controller.loadFeedback();
      final feedback = controller.feedbackList.single;
      await controller.markAsDone(feedback, auth.account);
      expect(feedback.status, 'completed');
      await controller.updateStatus(feedback, 'pending', auth.account);
      expect(feedback.dealBy, isNull);
      expect(feedback.dealAt, isNull);
      expect(feedback.isOk, isFalse);
    },
  );

  test(
    'disposed controller ignores load completion without another query',
    () async {
      service.pendingLoad = Completer<List<dynamic>>();
      final pending = controller.loadFeedback();
      controller.dispose();
      service.pendingLoad!.complete([_row(1)]);
      await pending;
      expect(controller.feedbackList, isEmpty);
      expect(service.probes, 0);
    },
  );
}
