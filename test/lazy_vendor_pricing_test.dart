import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/subscription/controller_pricing_list.dart';
import 'package:life_pilot/vendor/widgets_admin_vendor_pricing.dart';
import 'package:life_pilot/utils/supabase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'controller is lazy, shares active load and reuses view data until refresh',
    () async {
      var calls = 0;
      final gate = Completer<List<int>>();
      final c = ControllerPricingList<int>(
        load: () {
          calls++;
          return gate.future;
        },
      );
      addTearDown(c.dispose);
      expect(calls, 0);
      final a = c.load(), b = c.load();
      expect(calls, 1);
      expect(c.ready, isFalse);
      final source = [1, 2];
      gate.complete(source);
      await Future.wait([a, b]);
      source.clear();
      expect(c.rows, [1, 2]);
      expect(c.ready, isTrue);
      expect(() => c.rows.clear(), throwsUnsupportedError);
      await c.load();
      expect(calls, 1);
    },
  );
  test(
    'forced refresh ignores late completion from an older generation',
    () async {
      final old = Completer<List<int>>(), fresh = Completer<List<int>>();
      var calls = 0;
      final c = ControllerPricingList<int>(
        load: () => calls++ == 0 ? old.future : fresh.future,
      );
      addTearDown(c.dispose);
      final a = c.load(), b = c.load(force: true);
      fresh.complete([2]);
      await b;
      old.complete([1]);
      await a;
      expect(c.rows, [2]);
      expect(c.ready, isTrue);
      expect(calls, 2);
    },
  );
  test(
    'failed refresh retains display rows but is not ready until retry succeeds',
    () async {
      var calls = 0;
      final c = ControllerPricingList<int>(
        load: () async {
          calls++;
          if (calls == 2) throw StateError('network');
          return [calls];
        },
      );
      addTearDown(c.dispose);
      await c.load();
      await c.load(force: true);
      expect(c.rows, [1]);
      expect(c.error, isNotNull);
      expect(c.ready, isFalse);
      await c.load(force: true);
      expect(c.rows, [3]);
      expect(c.ready, isTrue);
    },
  );
  test(
    'synchronous errors are handled and an initial failure can retry',
    () async {
      var fail = true;
      final c = ControllerPricingList<int>(
        load: () {
          if (fail) throw StateError('sync');
          return Future.value([]);
        },
      );
      addTearDown(c.dispose);
      await c.load();
      expect(c.error, isNotNull);
      expect(c.loading, isFalse);
      fail = false;
      await c.load();
      expect(c.ready, isTrue);
      expect(c.rows, isEmpty);
    },
  );
  test('timeout ends loading and late errors remain observed', () async {
    final late = Completer<List<int>>();
    var calls = 0;
    final c = ControllerPricingList<int>(
      timeout: const Duration(milliseconds: 5),
      load: () => calls++ == 0 ? late.future : Future.value([2]),
    );
    addTearDown(c.dispose);
    await c.load();
    expect(c.error, isA<TimeoutException>());
    await c.load();
    expect(c.rows, [2]);
    late.completeError(StateError('late'));
    await Future<void>.delayed(Duration.zero);
    expect(c.ready, isTrue);
  });
  test('dispose ignores late response and does not notify', () async {
    final gate = Completer<List<int>>();
    final c = ControllerPricingList<int>(load: () => gate.future);
    var notices = 0;
    c.addListener(() => notices++);
    final load = c.load();
    c.dispose();
    gate.complete([1]);
    await load;
    expect(notices, 1);
    expect(c.rows, isEmpty);
  });

  late SupabaseClient client;
  late List<http.Request> requests;
  Completer<void>? gate;
  var denied = false, empty = false;
  setUp(() async {
    requests = [];
    gate = null;
    denied = false;
    empty = false;
    client = SupabaseClient(
      'https://example.supabase.co',
      'key',
      httpClient: MockClient((r) async {
        requests.add(r);
        if (gate != null) await gate!.future;
        return http.Response(
          jsonEncode(
            denied
                ? {'code': '42501', 'message': 'denied'}
                : {
                    'versions': empty
                        ? []
                        : [
                            {
                              'id': 'v1',
                              'plan_code': 'partner',
                              'version_name': '',
                              'effective_at': '2026-01-01T00:00:00Z',
                              'quarterly_price_twd': 499,
                              'event_quota': 50,
                              'attraction_quota': 15,
                              'image_megabytes': 25,
                              'analytics_days': 365,
                            },
                          ],
                  },
          ),
          denied ? 403 : 200,
          request: r,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    supabase = client;
    await client.auth.setInitialSession(
      jsonEncode({
        'access_token': 'token',
        'token_type': 'bearer',
        'user': {
          'id': 'admin',
          'email': 'admin@example.com',
          'app_metadata': {},
          'user_metadata': {},
          'aud': 'authenticated',
          'created_at': '2026-01-01T00:00:00Z',
        },
      }),
    );
  });
  tearDown(() => client.dispose());

  Future<AppLocalizations> mount(
    WidgetTester tester, {
    String language = 'en',
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: Locale(language),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: SingleChildScrollView(child: AdminVendorPricing()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return AppLocalizations.of(
      tester.element(find.byType(AdminVendorPricing)),
    )!;
  }

  testWidgets(
    'both collapsed sections issue no query; expanding both shares one request',
    (tester) async {
      final loc = await mount(tester);
      expect(requests, isEmpty);
      gate = Completer<void>();
      await tester.tap(find.text(loc.adminVendorPricingTitle));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.ensureVisible(find.text(loc.adminVendorSubscriptionTitle));
      await tester.tap(find.text(loc.adminVendorSubscriptionTitle));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(requests, hasLength(1));
      expect(find.byType(LinearProgressIndicator), findsNWidgets(2));
      gate!.complete();
      gate = null;
      await tester.pumpAndSettle();
      expect(requests.single.url.path, endsWith('get_pricing_catalog'));
      expect(jsonDecode(requests.single.body), {'p_vendor': true});
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'failed load is visible and refresh retries without write requests',
    (tester) async {
      final loc = await mount(tester);
      denied = true;
      await tester.tap(find.text(loc.adminVendorPricingTitle));
      await tester.pumpAndSettle();
      expect(find.text(loc.dashboardLoadFailed), findsOneWidget);
      expect(requests, hasLength(1));
      denied = false;
      empty = true;
      final refresh = find.byTooltip(loc.refreshList);
      await tester.ensureVisible(refresh);
      await tester.tap(refresh);
      await tester.pumpAndSettle();
      expect(find.text(loc.dashboardLoadFailed), findsNothing);
      expect(requests, hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('removed selected version is cleared and cannot be assigned', (
    tester,
  ) async {
    final loc = await mount(tester);
    await tester.tap(find.text(loc.adminVendorSubscriptionTitle));
    await tester.pumpAndSettle();
    final selector = find.byType(DropdownButtonFormField<String>);
    await tester.ensureVisible(selector);
    await tester.tap(selector);
    await tester.pumpAndSettle();
    await tester.tap(find.text(loc.vendorPlanPartnerName).last);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, loc.adminSubscriptionSave),
          )
          .onPressed,
      isNotNull,
    );
    empty = true;
    final refresh = find.byTooltip(loc.refreshList);
    await tester.ensureVisible(refresh);
    await tester.tap(refresh);
    await tester.pumpAndSettle();
    expect(tester.state<FormFieldState<String>>(selector).value, isNull);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, loc.adminSubscriptionSave),
          )
          .onPressed,
      isNull,
    );
    expect(requests, hasLength(2));
    expect(tester.takeException(), isNull);
  });
  for (final language in ['zh', 'en', 'ja', 'ko']) {
    testWidgets(
      '$language: narrow section loading and errors do not overflow',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final loc = await mount(tester, language: language);
        denied = true;
        await tester.tap(find.text(loc.adminVendorSubscriptionTitle));
        await tester.pumpAndSettle();
        expect(find.text(loc.dashboardLoadFailed), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
