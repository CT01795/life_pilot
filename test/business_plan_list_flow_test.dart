import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/business_plan/controller_business_plan.dart';
import 'package:life_pilot/business_plan/model_business_plan.dart';
import 'package:life_pilot/business_plan/page_business_plan.dart';
import 'package:life_pilot/business_plan/service_business_plan.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class _Auth extends ControllerAuth {
  String account = 'a@example.com';
  @override
  String get currentAccount => account;
}

class _Service extends ServiceBusinessPlan {
  int listCalls = 0, historyCalls = 0, latestCalls = 0;
  bool failList = false, failHistory = false;
  bool failLatest = false, hasHistory = true;
  DateTime? latestDate = DateTime(2024, 10, 1, 17);
  Completer<DateTime?>? pendingLatest;
  List<ModelBusinessPlan>? nextRows;
  final ranges = <({DateTime from, DateTime to})>[];
  final historyBoundaries = <DateTime>[];
  Completer<List<ModelBusinessPlan>>? pendingList;
  Completer<bool>? pendingHistory;
  final users = <String>[];
  @override
  Future<List<ModelBusinessPlan>> fetchPlans({
    required String user,
    required DateTime dateFrom,
    required DateTime dateTo,
  }) async {
    listCalls++;
    ranges.add((from: dateFrom, to: dateTo));
    users.add(user);
    if (failList) throw StateError('list offline');
    return pendingList?.future ??
        nextRows ??
        [
          ModelBusinessPlan(
            id: user,
            title: 'Plan',
            createdAt: DateTime(2026, 10, 28),
            sections: [],
          ),
        ];
  }

  @override
  Future<bool> hasPlansBefore({
    required String user,
    required DateTime before,
  }) async {
    historyCalls++;
    if (failHistory) throw StateError('history offline');
    return pendingHistory?.future ?? hasHistory;
  }

  @override
  Future<DateTime?> latestPlanDateBefore({
    required String user,
    required DateTime before,
  }) async {
    latestCalls++;
    historyBoundaries.add(before);
    if (failLatest) throw StateError('latest date offline');
    return pendingLatest?.future ?? latestDate;
  }
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Auth auth;
  late _Service service;
  late ControllerBusinessPlan controller;
  setUp(() {
    auth = _Auth();
    service = _Service();
    controller = ControllerBusinessPlan(service: service, auth: auth);
  });
  tearDown(() {
    if (!controller.notifierDisposed) controller.dispose();
    auth.dispose();
  });

  test(
    'failed older-page read retains data and retries the same date range',
    () async {
      await controller.loadPlans();
      final initial = controller.plans;
      service.failList = true;
      await controller.loadMorePlans();
      expect(controller.loadMorePlansError, isStateError);
      expect(controller.plans, same(initial));
      expect(controller.hasPlanHistoryAction, isTrue);
      expect(controller.isLoadingMorePlans, isFalse);
      final failedRange = service.ranges.last;
      service.failList = false;
      service.hasHistory = false;
      service.nextRows = [
        ModelBusinessPlan(
          id: 'older',
          title: 'Older',
          createdAt: service.latestDate!,
          sections: [],
        ),
      ];
      await controller.loadMorePlans();
      expect(service.ranges.last, failedRange);
      expect(service.historyBoundaries[0], service.historyBoundaries[1]);
      expect(
        failedRange.to.difference(failedRange.from),
        const Duration(days: 360),
      );
      expect(
        controller.plans.map((p) => p.id),
        containsAll(['a@example.com', 'older']),
      );
      expect(controller.loadMorePlansError, isNull);
      expect(controller.hasPlanHistoryAction, isFalse);
    },
  );

  test(
    'latest-date lookup failure can retry without losing the loaded list',
    () async {
      await controller.loadPlans();
      service.failLatest = true;
      await controller.loadMorePlans();
      expect(controller.loadMorePlansError, isStateError);
      expect(service.listCalls, 1);
      service.failLatest = false;
      service.latestDate = null;
      await controller.loadMorePlans();
      expect(controller.plans, hasLength(1));
      expect(controller.loadMorePlansError, isNull);
      expect(controller.hasMorePlans, isFalse);
      expect(service.listCalls, 1);
    },
  );

  test(
    'older page appears before its metadata and metadata retries do not redownload it',
    () async {
      await controller.loadPlans();
      service.nextRows = [
        ModelBusinessPlan(
          id: 'older',
          title: 'Older',
          createdAt: service.latestDate!,
          sections: [],
        ),
      ];
      service.pendingHistory = Completer<bool>();
      final more = controller.loadMorePlans();
      await _flush();
      expect(controller.plans, hasLength(2));
      expect(controller.isLoadingMorePlans, isFalse);
      expect(controller.isCheckingPlanHistory, isTrue);
      service.pendingHistory!.completeError(StateError('metadata offline'));
      await more;
      expect(controller.planHistoryError, isStateError);
      expect(controller.loadMorePlansError, isNull);
      service.pendingHistory = null;
      service.hasHistory = false;
      await controller.retryPlanHistory();
      expect(service.listCalls, 2);
      expect(service.latestCalls, 1);
      expect(controller.plans, hasLength(2));
      expect(controller.hasPlanHistoryAction, isFalse);
    },
  );

  test(
    'concurrent more and initial loads cannot duplicate pending pagination',
    () async {
      await controller.loadPlans();
      service.pendingLatest = Completer<DateTime?>();
      final more = controller.loadMorePlans();
      await controller.loadMorePlans();
      await controller.loadPlans();
      expect(service.latestCalls, 1);
      expect(service.listCalls, 1);
      service.pendingLatest!.complete(null);
      await more;
    },
  );

  test(
    'old-account pagination cannot append to the new-account list',
    () async {
      await controller.loadPlans();
      final oldPage = Completer<List<ModelBusinessPlan>>();
      service.pendingList = oldPage;
      final more = controller.loadMorePlans();
      await _flush();
      auth.account = 'b@example.com';
      controller.updateAuth(auth);
      service.pendingList = null;
      await controller.loadPlans();
      oldPage.complete([
        ModelBusinessPlan(
          id: 'obsolete',
          title: 'Obsolete',
          createdAt: DateTime(2024),
          sections: [],
        ),
      ]);
      await more;
      expect(controller.plans.single.id, 'b@example.com');
      expect(controller.loadMorePlansError, isNull);
    },
  );

  test(
    'late older page does not mutate data or notify after disposal',
    () async {
      await controller.loadPlans();
      final old = controller.plans;
      service.pendingList = Completer<List<ModelBusinessPlan>>();
      var notices = 0;
      controller.addListener(() => notices++);
      final more = controller.loadMorePlans();
      await _flush();
      controller.dispose();
      final before = notices;
      service.pendingList!.complete([]);
      await more;
      expect(controller.plans, same(old));
      expect(notices, before);
      expect(service.historyCalls, 1);
    },
  );

  test('list content is published before history metadata finishes', () async {
    service.pendingHistory = Completer<bool>();
    final load = controller.loadPlans();
    await _flush();
    expect(controller.plans.single.title, 'Plan');
    expect(controller.isPlansLoading, isFalse);
    expect(controller.isCheckingPlanHistory, isTrue);
    service.pendingHistory!.complete(true);
    await load;
    expect(controller.hasMorePlans, isTrue);
    expect(controller.isCheckingPlanHistory, isFalse);
  });

  test('metadata failure retains content and retries only metadata', () async {
    service.failHistory = true;
    await controller.loadPlans();
    expect(controller.plans, hasLength(1));
    expect(controller.plansLoadError, isNull);
    expect(controller.planHistoryError, isStateError);
    expect(controller.isPlansLoading, isFalse);
    service.failHistory = false;
    await controller.retryPlanHistory();
    expect(service.listCalls, 1);
    expect(service.historyCalls, 2);
    expect(controller.planHistoryError, isNull);
    expect(controller.hasMorePlans, isTrue);
  });

  test(
    'list failure has retryable state and does not query metadata',
    () async {
      service.failList = true;
      await controller.loadPlans();
      expect(controller.plansLoadError, isStateError);
      expect(controller.isPlansLoading, isFalse);
      expect(service.historyCalls, 0);
      service.failList = false;
      await controller.loadPlans();
      expect(controller.plansLoadError, isNull);
      expect(controller.plans, hasLength(1));
      expect(service.listCalls, 2);
    },
  );

  test('concurrent list and metadata loads do not duplicate queries', () async {
    service.pendingList = Completer<List<ModelBusinessPlan>>();
    service.pendingHistory = Completer<bool>();
    final load = controller.loadPlans();
    await controller.loadPlans();
    expect(service.listCalls, 1);
    service.pendingList!.complete([]);
    await _flush();
    await controller.loadPlans();
    await controller.retryPlanHistory();
    expect(service.historyCalls, 1);
    service.pendingHistory!.complete(false);
    await load;
  });

  test('old account metadata cannot overwrite the new account state', () async {
    final oldHistory = Completer<bool>();
    service.pendingHistory = oldHistory;
    final oldLoad = controller.loadPlans();
    await _flush();
    auth.account = 'b@example.com';
    controller.updateAuth(auth);
    service.pendingHistory = null;
    await controller.loadPlans();
    oldHistory.complete(false);
    await oldLoad;
    expect(controller.plans.single.id, 'b@example.com');
    expect(controller.hasMorePlans, isTrue);
    expect(controller.planHistoryError, isNull);
  });

  test('late metadata does not publish after disposal', () async {
    service.pendingHistory = Completer<bool>();
    var notices = 0;
    controller.addListener(() => notices++);
    final load = controller.loadPlans();
    await _flush();
    controller.dispose();
    final before = notices;
    service.pendingHistory!.completeError(StateError('late'));
    await load;
    expect(notices, before);
    expect(controller.planHistoryError, isNull);
  });

  testWidgets(
    'failed load-more button retries pagination rather than only metadata',
    (tester) async {
      service.failLatest = true;
      await tester.pumpWidget(
        ChangeNotifierProvider<ControllerAuth>.value(
          value: auth,
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PageBusinessPlan(service: service),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final loc = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.tap(find.text(loc.clickHereToSeeMore));
      await tester.pumpAndSettle();
      expect(find.text('Plan'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
      expect(service.latestCalls, 1);
      expect(service.listCalls, 1);
      service.failLatest = false;
      service.latestDate = null;
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();
      expect(service.latestCalls, 2);
      expect(service.listCalls, 1);
      expect(find.byIcon(Icons.refresh), findsNothing);
      expect(find.text(loc.clickHereToSeeMore), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('page shows plans while history is loading, then offers retry', (
    tester,
  ) async {
    service.pendingHistory = Completer<bool>();
    await tester.pumpWidget(
      ChangeNotifierProvider<ControllerAuth>.value(
        value: auth,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PageBusinessPlan(service: service),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Plan'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    service.pendingHistory!.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(find.text('Plan'), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
    service.pendingHistory = null;
    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();
    expect(service.listCalls, 1);
    expect(service.historyCalls, 2);
    expect(find.byIcon(Icons.refresh), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
