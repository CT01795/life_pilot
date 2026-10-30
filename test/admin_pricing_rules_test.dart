import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/subscription/model_personal_pricing_choice.dart';
import 'package:life_pilot/subscription/repository_pricing_version_guard.dart';
import 'package:life_pilot/subscription/widgets_admin_pricing_editor.dart';
import 'package:life_pilot/utils/supabase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SupabaseClient client;
  late List<http.Request> requests;
  Object lockResult = true;
  var fail = false;
  setUp(() {
    requests = [];
    lockResult = true;
    fail = false;
    client = SupabaseClient(
      'https://example.supabase.co',
      'key',
      httpClient: MockClient((request) async {
        requests.add(request);
        if (fail) {
          return http.Response(
            '{"code":"PGRST202","message":"missing"}',
            404,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }
        final path = request.url.path;
        return http.Response(
          jsonEncode(
            path.endsWith('admin_pricing_version_is_locked')
                ? lockResult
                : path.endsWith('get_subscription_pricing_versions')
                ? []
                : null,
          ),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    supabase = client;
  });
  tearDown(() => client.dispose());

  test(
    'free is cloud and exactly zero; paid choices require positive price',
    () {
      expect(PersonalPricingChoice.cloudFree.storagePlan, 'cloud');
      expect(PersonalPricingChoice.cloudFree.acceptsPrice(0), isTrue);
      expect(PersonalPricingChoice.cloudFree.acceptsPrice(1), isFalse);
      for (final choice in [
        PersonalPricingChoice.cloudPaid,
        PersonalPricingChoice.localPaid,
      ]) {
        expect(choice.acceptsPrice(0), isFalse);
        expect(choice.acceptsPrice(-1), isFalse);
        expect(choice.acceptsPrice(null), isFalse);
        expect(choice.acceptsPrice(149), isTrue);
      }
      expect(
        PersonalPricingChoice.from('cloud', 0),
        PersonalPricingChoice.cloudFree,
      );
      expect(
        PersonalPricingChoice.from('cloud', 149),
        PersonalPricingChoice.cloudPaid,
      );
      expect(
        PersonalPricingChoice.from('local', 149),
        PersonalPricingChoice.localPaid,
      );
    },
  );

  test(
    'lock lookup is one intent request and distinguishes personal/vendor',
    () async {
      final guard = RepositoryPricingVersionGuard();
      expect(await guard.isLocked('personal-id'), isTrue);
      lockResult = false;
      expect(await guard.isLocked('vendor-id', vendor: true), isFalse);
      expect(requests, hasLength(2));
      expect(jsonDecode(requests[0].body), {
        'p_version_id': 'personal-id',
        'p_vendor': false,
      });
      expect(jsonDecode(requests[1].body), {
        'p_version_id': 'vendor-id',
        'p_vendor': true,
      });
    },
  );
  test('missing guard never silently enables edits', () async {
    fail = true;
    await expectLater(
      RepositoryPricingVersionGuard().isLocked('id'),
      throwsA(isA<PostgrestException>()),
    );
    expect(requests, hasLength(1));
  });
  test('invalid lock response fails closed', () async {
    lockResult = {};
    await expectLater(
      RepositoryPricingVersionGuard().isLocked('id'),
      throwsFormatException,
    );
  });

  testWidgets('explicit free selection submits cloud with price zero', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late AppLocalizations loc;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              loc = AppLocalizations.of(context)!;
              return const SingleChildScrollView(
                child: AdminPricingVersionEditor(),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(loc.adminPricingTitle));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byType(DropdownButtonFormField<PersonalPricingChoice>),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(loc.subscriptionFreeName).last);
    await tester.pumpAndSettle();
    for (final element in find.byType(TextField).evaluate()) {
      final field = element.widget as TextField;
      if (field.decoration?.labelText == loc.adminPricingQuarterlyPrice) {
        expect(field.controller!.text, '0');
        expect(field.enabled, isFalse);
      } else {
        await tester.enterText(
          find.byWidget(field),
          field.decoration?.labelText == loc.adminPricingVersionName
              ? 'Free test'
              : '1',
        );
      }
    }
    await tester.tap(find.text(loc.adminPricingCreate));
    await tester.pumpAndSettle();
    final create = requests.singleWhere(
      (r) => r.url.path.endsWith('admin_create_subscription_pricing_version'),
    );
    final body = jsonDecode(create.body) as Map;
    expect(body['p_storage_plan'], 'cloud');
    expect(body['p_quarterly_price_twd'], 0);
    expect(tester.takeException(), isNull);
  });
}
