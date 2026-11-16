import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/business_plan/controller_business_plan.dart';
import 'package:life_pilot/business_plan/model_business_plan.dart';
import 'package:life_pilot/business_plan/model_business_plan_window.dart';
import 'package:life_pilot/business_plan/page_business_plan.dart';
import 'package:life_pilot/business_plan/service_business_plan.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class _Auth extends ControllerAuth {
  String account = 'a@example.com';
  @override
  String get currentAccount => account;
}

ModelBusinessPlan _plan(String id) => ModelBusinessPlan(
  id: id,
  title: id,
  createdAt: DateTime(2026, 10),
  sections: const [],
);

class _Service extends ServiceBusinessPlan {
  int calls = 0;
  bool fail = false;
  bool hasMore = true;
  List<ModelBusinessPlan> rows = [_plan('initial')];
  Completer<ModelBusinessPlanWindow>? pending;
  final requests = <({DateTime before, bool seekOlder})>[];

  @override
  Future<ModelBusinessPlanWindow> fetchPlanWindow({
    required DateTime before,
    bool seekOlder = false,
  }) async {
    calls++;
    requests.add((before: before, seekOlder: seekOlder));
    if (fail) throw StateError('offline');
    final active = pending;
    if (active != null) return active.future;
    return ModelBusinessPlanWindow(
      plans: List.of(rows),
      nextBefore: before.subtract(const Duration(days: 360)),
      hasMore: hasMore,
    );
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

  test('one window publishes rows cursor and history availability', () async {
    await controller.loadPlans();
    expect(controller.plans.single.id, 'initial');
    expect(controller.hasMorePlans, isTrue);
    expect(service.calls, 1);
    expect(service.requests.single.seekOlder, isFalse);
  });

  test('failed next page keeps data and retries the same cursor', () async {
    await controller.loadPlans();
    final initial = controller.plans;
    service.fail = true;
    await controller.loadMorePlans();
    final failedCursor = service.requests.last.before;
    expect(controller.loadMorePlansError, isStateError);
    expect(controller.plans, same(initial));

    service.fail = false;
    service.hasMore = false;
    service.rows = [_plan('older')];
    await controller.loadMorePlans();
    expect(service.requests.last.before, failedCursor);
    expect(service.requests.last.seekOlder, isTrue);
    expect(controller.plans.map((plan) => plan.id), ['initial', 'older']);
    expect(controller.hasMorePlans, isFalse);
    expect(controller.loadMorePlansError, isNull);
  });

  test('concurrent requests do not duplicate one pending page', () async {
    await controller.loadPlans();
    service.pending = Completer<ModelBusinessPlanWindow>();
    final more = controller.loadMorePlans();
    await _flush();
    await controller.loadMorePlans();
    await controller.loadPlans();
    expect(service.calls, 2);
    service.pending!.complete(
      ModelBusinessPlanWindow(
        plans: const [],
        nextBefore: service.requests.last.before,
        hasMore: false,
      ),
    );
    await more;
  });

  test('old account page cannot append to the new account', () async {
    await controller.loadPlans();
    final old = Completer<ModelBusinessPlanWindow>();
    service.pending = old;
    final more = controller.loadMorePlans();
    await _flush();
    auth.account = 'b@example.com';
    controller.updateAuth(auth);
    service.pending = null;
    service.rows = [_plan('new-account')];
    service.hasMore = false;
    await controller.loadPlans();
    old.complete(
      ModelBusinessPlanWindow(
        plans: [_plan('obsolete')],
        nextBefore: DateTime(2020),
        hasMore: false,
      ),
    );
    await more;
    expect(controller.plans.single.id, 'new-account');
  });

  testWidgets('load-more failure exposes one retry action', (tester) async {
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
    service.fail = true;
    await tester.tap(find.text(loc.clickHereToSeeMore));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.refresh), findsOneWidget);

    service.fail = false;
    service.hasMore = false;
    service.rows = const [];
    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.refresh), findsNothing);
    expect(find.text(loc.clickHereToSeeMore), findsNothing);
  });
}
