import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/event/model_content_performance.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/vendor/controller_vendor_dashboard.dart';
import 'package:life_pilot/vendor/model_vendor_account.dart';
import 'package:life_pilot/vendor/model_vendor_dashboard.dart';
import 'package:life_pilot/vendor/page_vendor_dashboard.dart';
import 'package:life_pilot/vendor/service_vendor_account.dart';
import 'package:provider/provider.dart';

VendorPricingPlan _plan(String code, int month) => VendorPricingPlan(
  id: '$code-$month',
  code: code,
  versionName: '$month',
  effectiveAt: DateTime(2026, month),
  quarterlyPriceTwd: 129,
  eventQuota: 50,
  attractionQuota: 15,
  imageMegabytes: 25,
  analyticsDays: 365,
);

final _status = VendorSubscriptionStatus(
  plan: _plan('partner', 10),
  status: 'active',
  eventUsed: 1,
  attractionUsed: 0,
  imageBytesUsed: 0,
);
final _metrics = VendorContentMetrics(
  published: 1,
  pending: 0,
  activeEvents: 1,
  activeAttractions: 0,
  recentSubmissions: const [],
  performance: ModelContentPerformance(const []),
);

ModelVendorDashboard _dashboard() => ModelVendorDashboard(
  status: _status,
  metrics: _metrics,
  plans: [_plan('growth', 10), _plan('free', 10)],
);

class _Auth extends ControllerAuth {
  String? account = 'a';
  int revision = 0;

  @override
  String? get currentAccount => account;
  @override
  bool get isSysAdmin => false;
  @override
  int get personalDataRevision => revision;

  void change(String? value) {
    account = value;
    notifyListeners();
  }
}

class _Service extends ServiceVendorAccount {
  final reads = <Completer<ModelVendorDashboard>>[];
  final owners = <String>[];
  final recentReads = <Completer<ModelVendorDashboard?>>[];
  final forces = <bool>[];
  ModelVendorDashboard? cached;

  @override
  Future<ModelVendorDashboard> fetchDashboard(
    String account, {
    bool force = false,
  }) {
    owners.add(account);
    forces.add(force);
    final done = Completer<ModelVendorDashboard>();
    reads.add(done);
    return done.future;
  }

  void complete(int index) => reads[index].complete(_dashboard());

  @override
  void cacheDashboard(ModelVendorDashboard value) => cached = value;

  @override
  Future<ModelVendorDashboard?> refreshRecentSubmissions() {
    final done = Completer<ModelVendorDashboard?>();
    recentReads.add(done);
    return done.future;
  }
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  late _Auth auth;
  late _Service service;
  late ControllerVendorDashboard controller;

  setUp(() {
    auth = _Auth();
    service = _Service();
    controller = ControllerVendorDashboard(auth: auth, service: service);
  });
  tearDown(() {
    if (!controller.notifierDisposed) controller.dispose();
    auth.dispose();
  });

  test('concurrent loads share one combined dashboard request', () async {
    final first = controller.load();
    expect(controller.load(), same(first));
    expect(service.reads, hasLength(1));
    expect(service.owners, ['a']);
    service.complete(0);
    await first;
    expect(controller.error, isNull);
    expect(controller.data!.metrics, same(_metrics));
    expect(controller.data!.plans.map((plan) => plan.code), ['free', 'growth']);
  });

  test('failed combined request retains data and remains retryable', () async {
    final first = controller.load();
    service.complete(0);
    await first;
    final snapshot = controller.data;

    final failed = controller.load();
    service.reads.last.completeError(StateError('offline'));
    await failed;
    expect(controller.data, same(snapshot));
    expect(controller.error, isA<StateError>());

    final retry = controller.load();
    service.complete(2);
    await retry;
    expect(controller.error, isNull);
    expect(controller.data, isNotNull);
  });

  testWidgets('visible refresh keeps current dashboard while forcing reload', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<ControllerAuth>.value(
        value: auth,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PageVendorDashboard(service: service),
        ),
      ),
    );
    service.complete(0);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('vendor-dashboard-refresh')));
    await tester.pump();

    expect(service.forces, [true, true]);
    expect(find.byIcon(Icons.storefront_outlined), findsOneWidget);
    expect(
      find.byKey(const ValueKey('vendor-dashboard-refresh-progress')),
      findsOneWidget,
    );

    service.complete(1);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('vendor-dashboard-refresh-progress')),
      findsNothing,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('timeout releases loading and ignores the late response', (
    tester,
  ) async {
    controller.dispose();
    controller = ControllerVendorDashboard(
      auth: auth,
      service: service,
      requestTimeout: const Duration(milliseconds: 20),
    );
    final old = controller.load();
    await tester.pump(const Duration(milliseconds: 21));
    await old;
    expect(controller.error, isA<TimeoutException>());
    expect(controller.loading, isFalse);

    final retry = controller.load();
    service.complete(1);
    await retry;
    final current = controller.data;
    service.complete(0);
    await tester.pump();
    expect(controller.data, same(current));
  });

  test('account round trip ignores the old account result', () async {
    final old = controller.load();
    auth.change('b');
    auth.change('a');
    final fresh = controller.load();
    expect(service.owners, ['a', 'a']);
    service.complete(1);
    await fresh;
    final current = controller.data;
    service.complete(0);
    await old;
    expect(controller.data, same(current));
    expect(controller.error, isNull);
  });

  test('sign-out clears data and blocks further reads', () async {
    final pending = controller.load();
    service.complete(0);
    await pending;
    expect(controller.data, isNotNull);
    auth.change(null);
    expect(controller.data, isNull);
    await controller.load();
    expect(service.reads, hasLength(1));
  });

  test('personal-data revision starts a fresh dashboard request', () async {
    final first = controller.load();
    service.complete(0);
    await first;
    auth.revision++;
    auth.notifyListeners();
    await _flush();
    expect(controller.data, isNull);
    expect(service.reads, hasLength(2));
    service.complete(1);
    await controller.load();
    expect(controller.data, isNotNull);
  });

  test('dispose prevents an in-flight response from publishing', () async {
    final pending = controller.load();
    controller.dispose();
    service.complete(0);
    await pending;
    expect(controller.data, isNull);
  });

  test(
    'saved submission updates immediately and refreshes only preview',
    () async {
      final first = controller.load();
      service.complete(0);
      await first;

      controller.applySubmissionSaved(
        previous: null,
        current: EventItem(
          id: 'new',
          name: 'New event',
          endDate: DateTime.now().add(const Duration(days: 1)),
        ),
        attraction: false,
      );

      expect(controller.data!.metrics.pending, 1);
      expect(controller.data!.status.eventUsed, 2);
      expect(service.cached, same(controller.data));
      expect(service.reads, hasLength(1));
      expect(service.recentReads, hasLength(1));

      final refreshed = controller.data!.withRecentSubmissions([
        VendorRecentSubmission(
          id: 'new',
          name: 'New event',
          city: 'Taipei',
          isActivity: true,
          isApproved: false,
        ),
      ]);
      service.recentReads.single.complete(refreshed);
      await _flush();
      expect(controller.data, same(refreshed));
      expect(controller.data!.metrics.recentSubmissions.single.id, 'new');
    },
  );

  test('model sorts without changing source and exposes read-only plans', () {
    final source = [
      _plan('partner', 1),
      _plan('growth', 2),
      _plan('free', 1),
      _plan('partner', 10),
    ];
    final data = ModelVendorDashboard(
      metrics: _metrics,
      status: _status,
      plans: source,
    );
    expect(data.plans.map((plan) => plan.id), [
      'free-1',
      'partner-10',
      'partner-1',
      'growth-2',
    ]);
    expect(source.first.id, 'partner-1');
    expect(() => data.plans.clear(), throwsUnsupportedError);
  });

  for (final language in ['en', 'zh', 'ja', 'ko']) {
    testWidgets('dashboard retries and renders on a narrow $language screen', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(360, 740));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ChangeNotifierProvider<ControllerAuth>.value(
          value: auth,
          child: MaterialApp(
            locale: Locale(language),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PageVendorDashboard(service: service),
          ),
        ),
      );
      service.reads.single.completeError(StateError('offline'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();
      service.complete(1);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.cloud_off_outlined), findsNothing);
      expect(find.byIcon(Icons.storefront_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
