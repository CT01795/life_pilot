import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/subscription/widgets_admin_pricing_editor.dart';
import 'package:life_pilot/subscription/widgets_admin_subscription_editor.dart';
import 'package:life_pilot/utils/service/export/repository_personal_export_rows.dart';
import 'package:life_pilot/utils/supabase.dart';

Future<void> login(SupabaseClient c, String id) => c.auth.setInitialSession(
  jsonEncode({
    'access_token': 'token-$id',
    'token_type': 'bearer',
    'user': {
      'id': id,
      'email': '$id@example.com',
      'app_metadata': {},
      'user_metadata': {},
      'aud': 'authenticated',
      'created_at': '2026-01-01T00:00:00Z',
    },
  }),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SupabaseClient client;
  late List<http.Request> requests;
  var cap = 2,
      missing = false,
      denied = false,
      repeated = false,
      failLater = false,
      switchLater = false;
  Completer<void>? gate;
  setUp(() async {
    requests = [];
    cap = 2;
    missing = false;
    denied = false;
    repeated = false;
    failLater = false;
    switchLater = false;
    gate = null;
    client = SupabaseClient(
      'https://example.supabase.co',
      'key',
      httpClient: MockClient((r) async {
        requests.add(r);
        if (gate != null) await gate!.future;
        Object? payload;
        var status = 200;
        if (denied) {
          payload = {'code': '42501', 'message': 'denied'};
          status = 403;
        } else if (r.url.path.endsWith('get_pricing_catalog')) {
          payload = {'versions': []};
        } else if (missing &&
            r.url.path.endsWith('export_my_personal_excel_rows')) {
          payload = {'code': 'PGRST202', 'message': 'missing'};
          status = 404;
        } else {
          final offset = int.parse(r.url.queryParameters['offset'] ?? '0');
          if (offset > 0 && failLater) {
            throw TimeoutException('late read failed');
          }
          if (offset > 0 && switchLater) await login(client, 'two');
          final rows = List.generate(
            5,
            (i) => {
              'table_name': i == 4
                  ? 'point_record_detail'
                  : 'accounting_detail',
              'id': '$i',
              'value': -1234.5678,
              'date': '2030-01-01',
              'primary_category': 'income',
              'secondary_category': 'salary',
              'currency': 'JPY',
            },
          );
          payload = rows.skip(repeated ? 0 : offset).take(cap).toList();
        }
        if (r.url.path.endsWith('export_my_personal_excel_rows') &&
            status == 200) {
          payload = (payload as List)
              .map(
                (row) => {
                  'table_name': row['table_name'],
                  'record': Map<String, dynamic>.from(row as Map)
                    ..remove('table_name'),
                },
              )
              .toList();
        }
        return http.Response(
          jsonEncode(payload),
          status,
          request: r,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    supabase = client;
    await login(client, 'one');
  });
  tearDown(() => client.dispose());

  for (final legacy in [false, true]) {
    test(
      'Excel includes all rows with project cap 2 (legacy=$legacy)',
      () async {
        missing = legacy;
        final rows = await RepositoryPersonalExportRows(
          client: client,
        ).read('one@example.com');
        expect(rows, hasLength(5));
        expect(rows.last['table_name'], 'point_record_detail');
        expect(rows.first['value'], -1234.5678);
        expect(rows.first['currency'], 'JPY');
        expect(rows.first['date'], '2030-01-01');
        expect(rows.first['secondary_category'], 'salary');
        final success = requests.where(
          (r) =>
              !legacy || !r.url.path.endsWith('export_my_personal_excel_rows'),
        );
        expect(success.map((r) => r.url.queryParameters['offset']).toList(), [
          '0',
          '2',
          '4',
          '5',
        ]);
      },
    );
  }
  test('one short page is followed by completion probe', () async {
    cap = 1000;
    final rows = await RepositoryPersonalExportRows(
      client: client,
    ).read('one@example.com');
    expect(rows, hasLength(5));
    expect(requests, hasLength(2));
    expect(requests.last.url.queryParameters['offset'], '5');
  });
  test(
    'repeated page is rejected instead of exporting duplicates indefinitely',
    () async {
      repeated = true;
      await expectLater(
        RepositoryPersonalExportRows(client: client).read('one@example.com'),
        throwsFormatException,
      );
      expect(requests, hasLength(2));
    },
  );
  test('later read failure never returns a partial export', () async {
    failLater = true;
    await expectLater(
      RepositoryPersonalExportRows(client: client).read('one@example.com'),
      throwsA(isA<TimeoutException>()),
    );
    expect(requests, hasLength(2));
  });
  test('account switch between pages rejects the old export', () async {
    switchLater = true;
    await expectLater(
      RepositoryPersonalExportRows(client: client).read('one@example.com'),
      throwsStateError,
    );
    expect(requests, hasLength(2));
  });

  for (final pricing in [true, false]) {
    testWidgets(
      'admin editor lazy read, failure retry and refresh (pricing=$pricing)',
      (tester) async {
        final key = ValueKey(
          pricing
              ? 'admin-pricing-refresh'
              : 'admin-subscription-pricing-refresh',
        );
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: pricing
                    ? const AdminPricingVersionEditor()
                    : const AdminSubscriptionEditor(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(requests, isEmpty);
        denied = true;
        await tester.tap(find.byType(ExpansionTile));
        await tester.pumpAndSettle();
        expect(requests, hasLength(1));
        final loc = AppLocalizations.of(
          tester.element(find.byType(ExpansionTile)),
        )!;
        expect(find.text(loc.dashboardLoadFailed), findsOneWidget);
        denied = false;
        await tester.ensureVisible(find.byKey(key));
        await tester.tap(find.byKey(key));
        await tester.pumpAndSettle();
        expect(requests, hasLength(2));
        expect(find.text(loc.dashboardLoadFailed), findsNothing);
        await tester.ensureVisible(find.byType(ListTile).first);
        await tester.tap(find.byType(ListTile).first);
        await tester.pumpAndSettle();
        await tester.tap(find.byType(ListTile).first);
        await tester.pumpAndSettle();
        expect(requests, hasLength(2));
        await tester.ensureVisible(find.byKey(key));
        await tester.tap(find.byKey(key));
        await tester.pumpAndSettle();
        expect(requests, hasLength(3));
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets('pending version request disables refresh (pricing=$pricing)', (
      tester,
    ) async {
      gate = Completer<void>();
      final key = ValueKey(
        pricing
            ? 'admin-pricing-refresh'
            : 'admin-subscription-pricing-refresh',
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: pricing
                  ? const AdminPricingVersionEditor()
                  : const AdminSubscriptionEditor(),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(ExpansionTile));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(requests, hasLength(1));
      expect(tester.widget<IconButton>(find.byKey(key)).onPressed, isNull);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      gate!.complete();
      gate = null;
      await tester.pumpAndSettle();
      expect(tester.widget<IconButton>(find.byKey(key)).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    });
  }
}
