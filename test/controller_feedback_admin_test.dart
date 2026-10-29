import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/feedback/controller_feedback_admin.dart';
import 'package:life_pilot/feedback/model_feedback.dart';
import 'package:life_pilot/feedback/service_feedback.dart';
import 'package:life_pilot/feedback/page_feedback_admin.dart';
import 'package:life_pilot/l10n/app_localizations.dart';

class _Auth extends ControllerAuth {
  String account = 'a@example.com';
  @override
  String get currentAccount => account;
  @override
  bool get isSysAdmin => true;
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
  bool failProbe = false;
  bool failLoad = false, failOlder = false;
  final ranges = <({DateTime from, DateTime to})>[];
  final olderBoundaries = <DateTime>[];
  Completer<bool>? pendingProbe;
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
    ranges.add((from: dateFrom, to: dateTo));
    if (failLoad) throw StateError('page offline');
    return pendingLoad == null ? rows : pendingLoad!.future;
  }

  @override
  Future<bool> hasFeedbackBefore(DateTime before) async {
    probes++;
    if (failProbe) throw StateError('history offline');
    return pendingProbe?.future ?? more;
  }

  @override
  Future<DateTime?> latestFeedbackDateBefore(DateTime before) async {
    olderBoundaries.add(before);
    if (failOlder) throw StateError('older date offline');
    return pendingOlder == null ? DateTime(2026, 1, 1) : pendingOlder!.future;
  }

  @override
  Future<void> updateFeedback({required ModelFeedback feedback}) async {
    updates++;
    proposed = feedback;
    if (pendingUpdate != null) await pendingUpdate!.future;
    if (failUpdate) throw StateError('offline');
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
    'selecting the current feedback status does not write or invalidate cache',
    () async {
      await controller.loadFeedback();
      final feedback = controller.feedbackList.single;
      final visible = controller.visibleFeedback;
      expect(
        await controller.updateStatus(feedback, feedback.status, auth.account),
        isTrue,
      );
      expect(service.updates, 0);
      expect(controller.visibleFeedback, same(visible));
    },
  );

  test('a replaced feedback row cannot submit a stale status update', () async {
    await controller.loadFeedback();
    final old = controller.feedbackList.single;
    await controller.loadFeedback();
    expect(
      await controller.updateStatus(old, 'completed', auth.account),
      isNull,
    );
    expect(service.updates, 0);
  });

  test(
    'account change during busy notification prevents an obsolete status write',
    () async {
      await controller.loadFeedback();
      final feedback = controller.feedbackList.single;
      var changed = false;
      controller.addListener(() {
        if (changed || !controller.isUpdating(feedback.id)) return;
        changed = true;
        auth.switchAccount();
      });
      expect(
        await controller.updateStatus(feedback, 'completed', auth.account),
        isNull,
      );
      expect(service.updates, 0);
      expect(controller.feedbackList, isEmpty);
    },
  );

  test(
    'older page failure keeps data and retries exactly the same 30-day range',
    () async {
      await controller.loadFeedback();
      final first = controller.feedbackList.single;
      service.failLoad = true;
      await controller.loadMore();
      expect(controller.feedbackList.single, same(first));
      expect(controller.loadError, isNull);
      expect(controller.loadMoreError, isStateError);
      expect(controller.isLoadingMore, isFalse);
      final failedRange = service.ranges.last;
      service.failLoad = false;
      service.rows = [_row(2)];
      service.more = false;
      await controller.loadMore();
      expect(service.ranges.last, failedRange);
      expect(
        failedRange.to.difference(failedRange.from),
        const Duration(days: 30),
      );
      expect(service.olderBoundaries[0], service.olderBoundaries[1]);
      expect(controller.feedbackList.map((row) => row.id), containsAll([1, 2]));
      expect(controller.loadMoreError, isNull);
      expect(controller.hasHistoryAction, isFalse);
    },
  );

  test(
    'older date lookup failure is separate from initial loading failure',
    () async {
      await controller.loadFeedback();
      service.failOlder = true;
      await controller.loadMore();
      expect(service.loads, 1);
      expect(controller.loadMoreError, isStateError);
      expect(controller.loadError, isNull);
      service.failOlder = false;
      service.more = false;
      service.rows = [_row(2)];
      await controller.loadMore();
      expect(controller.loadMoreError, isNull);
      expect(controller.feedbackList, hasLength(2));
    },
  );

  test(
    'older feedback appears before its history check and retry retains models',
    () async {
      await controller.loadFeedback();
      service.rows = [_row(2)];
      service.pendingProbe = Completer<bool>();
      final more = controller.loadMore();
      await Future<void>.delayed(Duration.zero);
      expect(controller.feedbackList, hasLength(2));
      expect(controller.isLoadingMore, isFalse);
      expect(controller.isCheckingHistory, isTrue);
      final rows = controller.feedbackList;
      service.pendingProbe!.completeError(StateError('metadata offline'));
      await more;
      expect(controller.loadMoreError, isNull);
      expect(controller.historyError, isStateError);
      service.pendingProbe = null;
      service.more = false;
      await controller.retryHistory();
      expect(controller.feedbackList, same(rows));
      expect(service.loads, 2);
      expect(controller.hasHistoryAction, isFalse);
    },
  );

  test(
    'refresh cancels a late page failure without setting errors on new data',
    () async {
      await controller.loadFeedback();
      final old = Completer<List<dynamic>>();
      service.pendingLoad = old;
      final more = controller.loadMore();
      await Future<void>.delayed(Duration.zero);
      service.pendingLoad = null;
      service.rows = [_row(3)];
      await controller.loadFeedback();
      old.completeError(StateError('obsolete'));
      await more;
      expect(controller.feedbackList.single.id, 3);
      expect(controller.loadMoreError, isNull);
      expect(controller.loadError, isNull);
    },
  );

  test('late page response cannot mutate a disposed feedback list', () async {
    await controller.loadFeedback();
    final rows = controller.feedbackList;
    service.pendingLoad = Completer<List<dynamic>>();
    final more = controller.loadMore();
    await Future<void>.delayed(Duration.zero);
    controller.dispose();
    service.pendingLoad!.complete([_row(2)]);
    await more;
    expect(controller.feedbackList, same(rows));
    expect(service.probes, 1);
  });

  testWidgets('load-more failure retries the older page from its footer', (
    tester,
  ) async {
    service.failOlder = true;
    await tester.pumpWidget(
      ChangeNotifierProvider<ControllerAuth>.value(
        value: auth,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PageFeedbackAdmin(service: service),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final loc = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.ensureVisible(find.text(loc.clickHereToSeeMore));
    await tester.tap(find.text(loc.clickHereToSeeMore));
    await tester.pumpAndSettle();
    expect(find.text('Feedback 1'), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
    expect(service.loads, 1);
    service.failOlder = false;
    service.rows = [_row(2)];
    service.more = false;
    await tester.ensureVisible(find.byIcon(Icons.refresh));
    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();
    expect(find.text('Feedback 2'), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsNothing);
    expect(service.loads, 2);
    expect(tester.takeException(), isNull);
  });

  test('feedback becomes visible before history metadata completes', () async {
    service.pendingProbe = Completer<bool>();
    final load = controller.loadFeedback();
    await Future<void>.delayed(Duration.zero);
    expect(controller.feedbackList.single.subject, 'Feedback 1');
    expect(controller.isLoading, isFalse);
    expect(controller.isCheckingHistory, isTrue);
    service.pendingProbe!.complete(true);
    await load;
    expect(controller.hasMore, isTrue);
    expect(controller.isCheckingHistory, isFalse);
  });

  test(
    'history failure retains model and decoded cache; retry skips list download',
    () async {
      service.failProbe = true;
      await controller.loadFeedback();
      final model = controller.feedbackList.single;
      final decoded = [
        Uint8List.fromList([1, 2, 3]),
      ];
      model.screenshotDecodeRawData = decoded;
      final visible = controller.visibleFeedback;
      expect(controller.loadError, isNull);
      expect(controller.historyError, isStateError);
      expect(controller.hasHistoryAction, isTrue);
      service.failProbe = false;
      service.more = false;
      await controller.retryHistory();
      expect(service.loads, 1);
      expect(service.probes, 2);
      expect(controller.feedbackList.single, same(model));
      expect(
        controller.feedbackList.single.screenshotDecodeRawData,
        same(decoded),
      );
      expect(controller.visibleFeedback, same(visible));
      expect(controller.historyError, isNull);
      expect(controller.hasHistoryAction, isFalse);
    },
  );

  test(
    'duplicate history retries and load-more do not start extra reads',
    () async {
      service.pendingProbe = Completer<bool>();
      final load = controller.loadFeedback();
      await Future<void>.delayed(Duration.zero);
      await controller.retryHistory();
      await controller.loadMore();
      expect(service.loads, 1);
      expect(service.probes, 1);
      service.pendingProbe!.complete(false);
      await load;
    },
  );

  test('old-account metadata cannot overwrite a new account result', () async {
    final oldProbe = Completer<bool>();
    service.pendingProbe = oldProbe;
    final old = controller.loadFeedback();
    await Future<void>.delayed(Duration.zero);
    auth.switchAccount();
    service.rows = [_row(2)];
    service.pendingProbe = null;
    await controller.loadFeedback();
    oldProbe.complete(false);
    await old;
    expect(controller.feedbackList.single.id, 2);
    expect(controller.hasMore, isTrue);
    expect(controller.historyError, isNull);
  });

  test('late metadata failure does not publish after disposal', () async {
    service.pendingProbe = Completer<bool>();
    final load = controller.loadFeedback();
    await Future<void>.delayed(Duration.zero);
    var notices = 0;
    controller.addListener(() => notices++);
    controller.dispose();
    service.pendingProbe!.completeError(StateError('late'));
    await load;
    expect(controller.historyError, isNull);
    expect(notices, 0);
  });

  testWidgets(
    'admin page retains content during metadata loading and retries only history',
    (tester) async {
      service.pendingProbe = Completer<bool>();
      await tester.pumpWidget(
        ChangeNotifierProvider<ControllerAuth>.value(
          value: auth,
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PageFeedbackAdmin(service: service),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Feedback 1'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      service.pendingProbe!.completeError(StateError('offline'));
      await tester.pumpAndSettle();
      expect(find.text('Feedback 1'), findsOneWidget);
      service.pendingProbe = null;
      service.more = false;
      await tester.ensureVisible(find.byIcon(Icons.refresh));
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();
      expect(service.loads, 1);
      expect(service.probes, 2);
      expect(find.byIcon(Icons.refresh), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

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
