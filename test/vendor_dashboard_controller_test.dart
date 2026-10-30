import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/event/model_content_performance.dart';
import 'package:life_pilot/vendor/controller_vendor_dashboard.dart';
import 'package:life_pilot/vendor/model_vendor_account.dart';
import 'package:life_pilot/vendor/model_vendor_dashboard.dart';
import 'package:life_pilot/vendor/service_vendor_account.dart';
import 'package:life_pilot/vendor/page_vendor_dashboard.dart';
import 'package:life_pilot/l10n/app_localizations.dart';

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
  recentSubmissions: [],
  performance: ModelContentPerformance([]),
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
  final setups = <Completer<void>>[];
  final statuses = <Completer<VendorSubscriptionStatus>>[];
  final metrics = <Completer<VendorContentMetrics>>[];
  final pricing = <Completer<List<VendorPricingPlan>>>[];
  final owners = <String>[];
  @override
  Future<void> ensureVendorAccount() {
    final done = Completer<void>();
    setups.add(done);
    return done.future;
  }

  @override
  Future<VendorSubscriptionStatus> fetchMyStatus() {
    final done = Completer<VendorSubscriptionStatus>();
    statuses.add(done);
    return done.future;
  }

  @override
  Future<VendorContentMetrics> fetchMetrics(String account) {
    owners.add(account);
    final done = Completer<VendorContentMetrics>();
    metrics.add(done);
    return done.future;
  }

  @override
  Future<List<VendorPricingPlan>> fetchPricingPlans() {
    final done = Completer<List<VendorPricingPlan>>();
    pricing.add(done);
    return done.future;
  }

  void complete(int index) {
    statuses[index].complete(_status);
    metrics[index].complete(_metrics);
    pricing[index].complete([_plan('growth', 10), _plan('free', 10)]);
  }
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  late _Auth auth;
  late _Service service;
  late ControllerVendorDashboard c;
  setUp(() {
    auth = _Auth();
    service = _Service();
    c = ControllerVendorDashboard(auth: auth, service: service);
  });
  tearDown(() {
    if (!c.notifierDisposed) c.dispose();
    auth.dispose();
  });
  test(
    'sign-out clears loaded vendor data and original sign-in reloads',
    () async {
      final first = c.load();
      service.setups[0].complete();
      await _flush();
      service.complete(0);
      await first;
      expect(c.data, isNotNull);
      auth.change(null);
      expect(c.data, isNull);
      expect(c.loading, isFalse);
      await c.load();
      expect(service.setups, hasLength(1));
      auth.change('a');
      expect(service.setups, hasLength(2));
      final fresh = c.load();
      service.setups[1].complete();
      await _flush();
      service.complete(1);
      await fresh;
      expect(c.data, isNotNull);
      expect(service.owners, ['a', 'a']);
    },
  );

  for (final duringSetup in [true, false]) {
    for (final oldFailure in [false, true]) {
      test(
        'A-B-A reloads the owner without redundant foreign-account updates (setup=$duringSetup, old error=$oldFailure)',
        () async {
          final old = c.load();
          if (!duringSetup) {
            service.setups[0].complete();
            await _flush();
          }
          auth.change('b');
          var notifications = 0;
          c.addListener(() => notifications++);
          for (var i = 0; i < 4; i++) {
            auth.notifyListeners();
          }
          expect(notifications, 0);
          expect(c.data, isNull);
          expect(c.loading, isFalse);
          await c.load();
          expect(service.setups, hasLength(1));
          auth.change('a');
          expect(service.setups, hasLength(2));
          expect(c.loading, isTrue);
          final fresh = c.load();
          service.setups[1].complete();
          await _flush();
          final currentIndex = service.statuses.length - 1;
          service.complete(currentIndex);
          await fresh;
          final current = c.data;
          expect(current, isNotNull);
          if (duringSetup) {
            if (oldFailure) {
              service.setups[0].completeError(StateError('obsolete setup'));
            } else {
              service.setups[0].complete();
            }
          } else if (oldFailure) {
            service.statuses[0].completeError(StateError('obsolete status'));
            service.metrics[0].complete(_metrics);
            service.pricing[0].complete([]);
          } else {
            service.complete(0);
          }
          await old;
          expect(c.data, same(current));
          expect(c.error, isNull);
          expect(c.loading, isFalse);
          expect(service.owners.every((owner) => owner == 'a'), isTrue);
          expect(service.statuses, hasLength(duringSetup ? 1 : 2));
        },
      );
    }
  }

  for (final duringSetup in [true, false]) {
    testWidgets(
      'timeout during ${duringSetup ? 'setup' : 'parallel reads'} is retryable and ignores late work',
      (tester) async {
        c.dispose();
        c = ControllerVendorDashboard(
          auth: auth,
          service: service,
          requestTimeout: const Duration(milliseconds: 20),
        );
        final old = c.load();
        expect(c.load(), same(old));
        if (!duringSetup) {
          service.setups.single.complete();
          await tester.pump();
          expect(service.statuses.length, 1);
        }
        await tester.pump(const Duration(milliseconds: 21));
        await old;
        expect(c.loading, isFalse);
        expect(c.error, isA<TimeoutException>());
        expect(c.data, isNull);

        final retry = c.load();
        expect(retry, isNot(same(old)));
        expect(c.error, isNull);
        expect(c.loading, isTrue);
        if (duringSetup) {
          service.setups.first.complete();
        } else {
          service.complete(0);
        }
        await tester.pump();
        expect(c.data, isNull);
        expect(c.loading, isTrue);
        expect(service.statuses.length, duringSetup ? 0 : 1);

        service.setups.last.complete();
        await tester.pump();
        service.complete(duringSetup ? 0 : 1);
        await tester.pump();
        await retry;
        expect(c.data, isNotNull);
        expect(c.error, isNull);
        expect(c.loading, isFalse);
      },
    );
  }
  for (final failedRead in ['status', 'metrics', 'pricing']) {
    test('$failedRead failure does not wait for other pending reads', () async {
      final pending = c.load();
      service.setups.single.complete();
      await _flush();
      final error = StateError(failedRead);
      switch (failedRead) {
        case 'status':
          service.statuses.single.completeError(error);
        case 'metrics':
          service.metrics.single.completeError(error);
        case 'pricing':
          service.pricing.single.completeError(error);
      }
      await pending;
      expect(c.error, same(error));
      expect(c.loading, isFalse);
      // A second failure arriving after the first must also be handled, without
      // replacing the error already shown or creating an unhandled exception.
      if (!service.statuses.single.isCompleted) {
        service.statuses.single.completeError(StateError('late status'));
      }
      if (!service.metrics.single.isCompleted) {
        service.metrics.single.completeError(StateError('late metrics'));
      }
      if (!service.pricing.single.isCompleted) {
        service.pricing.single.completeError(StateError('late pricing'));
      }
      await _flush();
      expect(c.error, same(error));
      final retry = c.load();
      service.setups.last.complete();
      await _flush();
      service.complete(1);
      await retry;
      expect(c.error, isNull);
      expect(c.data, isNotNull);
    });
  }
  testWidgets('setup and reads share one total timeout budget', (tester) async {
    c.dispose();
    c = ControllerVendorDashboard(
      auth: auth,
      service: service,
      requestTimeout: const Duration(milliseconds: 20),
    );
    final pending = c.load();
    await tester.pump(const Duration(milliseconds: 12));
    service.setups.single.complete();
    await tester.pump();
    expect(service.statuses.length, 1);
    await tester.pump(const Duration(milliseconds: 9));
    await pending;
    expect(c.error, isA<TimeoutException>());
    expect(c.loading, isFalse);
    service.complete(0);
    await tester.pump();
    expect(c.data, isNull);
  });
  for (final change in ['account', 'dispose']) {
    testWidgets('late timeout after $change cannot publish an error', (
      tester,
    ) async {
      c.dispose();
      c = ControllerVendorDashboard(
        auth: auth,
        service: service,
        requestTimeout: const Duration(milliseconds: 20),
      );
      final pending = c.load();
      if (change == 'account') {
        auth.change('other');
      } else {
        c.dispose();
      }
      var notifications = 0;
      if (!c.notifierDisposed) c.addListener(() => notifications++);
      await tester.pump(const Duration(milliseconds: 21));
      await pending;
      expect(c.error, isNull);
      expect(c.data, isNull);
      expect(notifications, 0);
      service.setups.single.complete();
      await tester.pump();
      expect(service.statuses, isEmpty);
    });
  }
  test('failed refresh retains the last complete dashboard snapshot', () async {
    final first = c.load();
    service.setups.single.complete();
    await _flush();
    service.complete(0);
    await first;
    final snapshot = c.data;
    final refresh = c.load();
    service.setups.last.complete();
    await _flush();
    service.statuses.last.completeError(StateError('offline'));
    await refresh;
    expect(c.data, same(snapshot));
    expect(c.error, isA<StateError>());
    expect(c.loading, isFalse);
    service.metrics.last.complete(_metrics);
    service.pricing.last.complete([]);
    await _flush();
    expect(c.data, same(snapshot));
  });

  test(
    'setup gates three parallel reads and concurrent loads share one future',
    () async {
      final first = c.load();
      expect(c.load(), same(first));
      expect(service.setups.length, 1);
      expect(service.statuses, isEmpty);
      service.setups.single.complete();
      await _flush();
      expect(service.statuses.length, 1);
      expect(service.metrics.length, 1);
      expect(service.pricing.length, 1);
      expect(service.owners, ['a']);
      service.complete(0);
      await first;
      expect(c.loading, isFalse);
      expect(c.error, isNull);
      expect(c.data!.metrics, same(_metrics));
      expect(c.data!.plans.map((p) => p.code), ['free', 'growth']);
    },
  );
  test(
    'setup failure is retryable and does not launch dashboard reads',
    () async {
      final first = c.load();
      service.setups.single.completeError(StateError('offline'));
      await first;
      expect(c.error, isA<StateError>());
      expect(c.loading, isFalse);
      expect(service.statuses, isEmpty);
      final retry = c.load();
      service.setups.last.complete();
      await _flush();
      service.complete(0);
      await retry;
      expect(c.error, isNull);
    },
  );
  test('a failed parallel read ends loading and can retry', () async {
    final first = c.load();
    service.setups.single.complete();
    await _flush();
    service.statuses.single.completeError(StateError('status'));
    service.metrics.single.complete(_metrics);
    service.pricing.single.complete([]);
    await first;
    expect(c.error, isA<StateError>());
    expect(c.loading, isFalse);
    final retry = c.load();
    service.setups.last.complete();
    await _flush();
    service.complete(1);
    await retry;
    expect(c.data, isNotNull);
  });
  test('account change during setup prevents all follow-up reads', () async {
    final first = c.load();
    auth.change('b');
    service.setups.single.complete();
    await first;
    expect(service.statuses, isEmpty);
    expect(c.data, isNull);
    await c.load();
    expect(service.setups.length, 1);
  });
  test(
    'account round trip ignores old results and accepts a fresh load',
    () async {
      final old = c.load();
      service.setups.single.complete();
      await _flush();
      auth.change('b');
      auth.change('a');
      final fresh = c.load();
      service.setups.last.complete();
      await _flush();
      service.complete(0);
      await old;
      expect(c.data, isNull);
      expect(c.loading, isTrue);
      service.complete(1);
      await fresh;
      expect(c.data, isNotNull);
    },
  );
  test(
    'personal-data revision reloads without retaining old dashboard',
    () async {
      final first = c.load();
      service.setups.single.complete();
      await _flush();
      service.complete(0);
      await first;
      auth.revision++;
      auth.notifyListeners();
      expect(c.data, isNull);
      expect(service.setups.length, 2);
      service.setups.last.complete();
      await _flush();
      service.complete(1);
      await c.load();
      expect(c.data, isNotNull);
    },
  );
  test(
    'dispose during setup neither queries nor publishes afterwards',
    () async {
      final first = c.load();
      c.dispose();
      service.setups.single.complete();
      await first;
      expect(service.statuses, isEmpty);
      expect(c.data, isNull);
    },
  );
  test('same-account notifications do not reload dashboard', () async {
    final first = c.load();
    auth.notifyListeners();
    expect(service.setups.length, 1);
    service.setups.single.complete();
    await _flush();
    service.complete(0);
    await first;
    final snapshot = c.data;
    auth.notifyListeners();
    expect(c.data, same(snapshot));
  });
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
    expect(data.plans.map((p) => p.id), [
      'free-1',
      'partner-10',
      'partner-1',
      'growth-2',
    ]);
    expect(source.first.id, 'partner-1');
    expect(() => data.plans.clear(), throwsUnsupportedError);
  });

  for (final language in ['en', 'zh', 'ja', 'ko']) {
    testWidgets(
      'dashboard page retries and renders on narrow $language screen',
      (tester) async {
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
        service.setups.single.completeError(StateError('offline'));
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
        await tester.tap(find.byIcon(Icons.refresh));
        await tester.pump();
        service.setups.last.complete();
        await tester.pump();
        service.complete(0);
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.cloud_off_outlined), findsNothing);
        expect(find.byIcon(Icons.storefront_outlined), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
