import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/subscription/service_subscription.dart';
import 'package:life_pilot/subscription/widgets_admin_quota_free_period.dart';
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
  late SupabaseClient c;
  late List<http.Request> requests;
  Completer<void>? gate;
  var fail = false;
  setUp(() async {
    gate = null;
    fail = false;
    requests = [];
    c = SupabaseClient(
      'https://example.supabase.co',
      'key',
      httpClient: MockClient((r) async {
        requests.add(r);
        final read = r.url.path.contains('/get_');
        final pending = read ? gate : null;
        final failed = fail;
        if (pending != null) await pending.future;
        return http.Response(
          jsonEncode(
            failed
                ? {'code': '42501', 'message': 'denied'}
                : read
                ? []
                : r.url.path.endsWith('cleanup_subscription_data')
                ? {'deleted': 0}
                : null,
          ),
          failed ? 403 : 200,
          request: r,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    supabase = c;
    await login(c, 'one');
  });
  tearDown(() => c.dispose());
  final reads = <String, Future<Object> Function()>{
    'periods': () => ServiceSubscription().fetchQuotaFreePeriods(),
    'cleanup': () =>
        ServiceSubscription().fetchCleanupPreview(email: 'one@example.com'),
  };
  for (final entry in reads.entries) {
    test(
      '${entry.key}: simultaneous reads share, completed values are not cached',
      () async {
        gate = Completer<void>();
        final a = entry.value(), b = entry.value();
        await Future<void>.delayed(Duration.zero);
        expect(requests, hasLength(1));
        gate!.complete();
        await Future.wait([a, b]);
        gate = null;
        await entry.value();
        expect(requests, hasLength(2));
      },
    );
    test(
      '${entry.key}: old session response is rejected and failures can retry',
      () async {
        gate = Completer<void>();
        final a = entry.value();
        final checked = expectLater(a, throwsStateError);
        await Future<void>.delayed(Duration.zero);
        await login(c, 'two');
        gate!.complete();
        await checked;
        gate = null;
        fail = true;
        await expectLater(entry.value(), throwsA(isA<PostgrestException>()));
        fail = false;
        expect(await entry.value(), isEmpty);
      },
    );
  }
  test('different cleanup targets never share', () async {
    gate = Completer<void>();
    final service = ServiceSubscription();
    final a = service.fetchCleanupPreview(email: 'one@example.com');
    final b = service.fetchCleanupPreview(email: 'two@example.com');
    final own = service.fetchCleanupPreview();
    await Future<void>.delayed(Duration.zero);
    expect(requests, hasLength(3));
    gate!.complete();
    await Future.wait([a, b, own]);
  });
  for (final mutation in ['save', 'delete', 'cleanup']) {
    test(
      '$mutation invalidates pending reads; writes never auto-retry',
      () async {
        final service = ServiceSubscription();
        gate = Completer<void>();
        final oldGate = gate!;
        final preview = service.fetchCleanupPreview();
        final checked = expectLater(preview, throwsStateError);
        final period = mutation == 'cleanup'
            ? null
            : service.fetchQuotaFreePeriods();
        final checkedPeriod = period == null
            ? null
            : expectLater(period, throwsStateError);
        await Future<void>.delayed(Duration.zero);
        gate = null;
        if (mutation == 'save') {
          await service.saveQuotaFreePeriodAsAdmin(
            name: 'test',
            startsAt: DateTime(2026),
            endsAt: DateTime(2027),
            enabled: true,
          );
        } else if (mutation == 'delete') {
          await service.deleteQuotaFreePeriodAsAdmin('id');
        } else {
          await service.cleanupData(mode: 'excess');
        }
        oldGate.complete();
        await checked;
        if (checkedPeriod != null) await checkedPeriod;
        await service.fetchCleanupPreview();
        expect(
          requests.where((r) => !r.url.path.contains('/get_')),
          hasLength(1),
        );
      },
    );
  }
  test(
    'cleanup failures retain their error and never repeat the destructive request',
    () async {
      fail = true;
      await expectLater(
        ServiceSubscription().cleanupData(mode: 'all'),
        throwsA(isA<PostgrestException>()),
      );
      expect(requests, hasLength(1));
      fail = false;
      expect(await ServiceSubscription().fetchCleanupPreview(), isEmpty);
    },
  );
  testWidgets(
    'promotion editor reads only after expansion and refreshes explicitly',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: SingleChildScrollView(child: AdminQuotaFreePeriod()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(requests, isEmpty);
      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();
      expect(requests, hasLength(1));
      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();
      expect(requests, hasLength(1));
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();
      expect(requests, hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );
}
