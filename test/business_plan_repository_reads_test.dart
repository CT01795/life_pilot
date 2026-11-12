import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:life_pilot/business_plan/repository_business_plan_reads.dart';
import 'package:life_pilot/business_plan/service_business_plan.dart';
import 'package:life_pilot/utils/const.dart';
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
  Completer<void>? gate;
  var denied = false, duplicate = false;
  final from = DateTime.utc(2026, 10), to = DateTime.utc(2026, 11);
  setUp(() async {
    requests = [];
    gate = null;
    denied = false;
    duplicate = false;
    client = SupabaseClient(
      'https://example.supabase.co',
      'key',
      httpClient: MockClient((r) async {
        requests.add(r);
        if (r.method != 'GET') {
          if (r.url.path.endsWith('/rpc/get_my_business_plan_window')) {
            return http.Response(
              jsonEncode({
                'rows': [
                  {
                    'id': 'p',
                    'title': '企劃',
                    'created_at': '2026-10-01T12:34:56Z',
                    'status': 'in_progress',
                  },
                ],
                'next_before': from.toIso8601String(),
                'has_more': false,
              }),
              200,
              request: r,
              headers: {'content-type': 'application/json'},
            );
          }
          if (r.url.path.endsWith('/rpc/create_business_plan_from_template')) {
            return http.Response(
              duplicate
                  ? jsonEncode({'code': '23505', 'message': 'plan_name_exists'})
                  : jsonEncode('new'),
              duplicate ? 409 : 200,
              request: r,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            'null',
            201,
            request: r,
            headers: {'content-type': 'application/json'},
          );
        }
        final pending = gate;
        Object? payload;
        var status = 200;
        if (denied) {
          payload = {'code': '42501', 'message': 'denied'};
          status = 403;
        } else {
          final table = r.url.pathSegments.last;
          final rows = switch (table) {
            TableNames.businessPlanTemplate => [
              {
                'id': 't',
                'title': '模板',
                'description': 'Full description',
                'is_valid': true,
                'created_at': '2026-01-01',
                'unused_blob': 'unneeded',
              },
            ],
            _ => [
              {
                'id': 'p',
                'title': '企劃',
                'created_at': '2026-10-01T12:34:56Z',
                'status': 'in_progress',
                'unused_blob': 'unneeded',
              },
            ],
          };
          final fields = (r.url.queryParameters['select'] ?? '*').split(',');
          payload = rows
              .map(
                (row) => fields.contains('*')
                    ? row
                    : {for (final field in fields) field: row[field]},
              )
              .toList();
        }
        if (pending != null) await pending.future;
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

  test(
    'active read projections include only consumed fields and preserve filters/order',
    () async {
      final repo = RepositoryBusinessPlanReads(client);
      final templates = await repo.templates();
      expect(templates.single['description'], 'Full description');
      expect(
        requests.last.url.queryParameters['select'],
        'id,title,description',
      );
      expect(requests.last.url.queryParameters[Fields.isValid], 'eq.true');
      expect(
        requests.last.url.queryParameters['order'],
        'created_at.asc.nullslast',
      );
      final plans = await repo.plans(
        user: 'one@example.com',
        from: from,
        to: to,
      );
      expect(plans.single['status'], 'in_progress');
      expect(
        requests.last.url.queryParameters['select'],
        'id,title,created_at,status',
      );
      expect(
        requests.last.url.queryParameters[Fields.createdBy],
        'eq.one@example.com',
      );
      // Multiple constraints for a single field remain inclusive-start/exclusive-end.
      expect(requests.last.url.queryParametersAll[Fields.createdAt], [
        'gte.${from.toIso8601String()}',
        'lt.${to.toIso8601String()}',
      ]);
      expect(
        requests.last.url.queryParameters['order'],
        'created_at.desc.nullslast',
      );
    },
  );
  test(
    'template callers share active requests but not completed values or mutable models',
    () async {
      gate = Completer<void>();
      final a = ServiceBusinessPlan().fetchTemplates(),
          b = ServiceBusinessPlan().fetchTemplates();
      await Future<void>.delayed(Duration.zero);
      expect(requests, hasLength(1));
      gate!.complete();
      final values = await Future.wait([a, b]);
      gate = null;
      expect(values.first.single.id, 't');
      expect(values.first.single, isNot(same(values.last.single)));
      values.first.clear();
      expect(values.last, hasLength(1));
      await ServiceBusinessPlan().fetchTemplates();
      expect(requests, hasLength(2));
    },
  );
  test(
    'template read error stays visible and retry performs a fresh query',
    () async {
      denied = true;
      final repo = RepositoryBusinessPlanReads(client);
      await expectLater(repo.templates(), throwsA(isA<PostgrestException>()));
      expect(requests, hasLength(1));
      denied = false;
      expect(await repo.templates(), hasLength(1));
      expect(requests, hasLength(2));
    },
  );
  test('template response from an old login is rejected', () async {
    gate = Completer<void>();
    final read = RepositoryBusinessPlanReads(client).templates();
    final checked = expectLater(read, throwsStateError);
    await Future<void>.delayed(Duration.zero);
    await login(client, 'two');
    gate!.complete();
    await checked;
  });
  test('plan list reads remain independent across refresh workflows', () async {
    gate = Completer<void>();
    final repo = RepositoryBusinessPlanReads(client);
    final a = repo.plans(user: 'one@example.com', from: from, to: to);
    final b = repo.plans(user: 'one@example.com', from: from, to: to);
    await Future<void>.delayed(Duration.zero);
    expect(requests, hasLength(2));
    gate!.complete();
    await Future.wait([a, b]);
  });
  test(
    'creating from a template uses one atomic RPC with only identifiers',
    () async {
      await ServiceBusinessPlan().createPlanFromTemplate(
        user: 'one@example.com',
        planId: 'new',
        title: 'New',
        templateId: 't',
      );
      expect(requests, hasLength(1));
      expect(requests.single.method, 'POST');
      expect(
        requests.single.url.path,
        endsWith('/rpc/create_business_plan_from_template'),
      );
      expect(jsonDecode(requests.single.body), {
        'p_plan_id': 'new',
        'p_title': 'New',
        'p_template_id': 't',
      });
    },
  );
  test('duplicate plan validation still stops before any write', () async {
    duplicate = true;
    await expectLater(
      ServiceBusinessPlan().createPlanFromTemplate(
        user: 'one@example.com',
        planId: 'new',
        title: 'same',
        templateId: 't',
      ),
      throwsException,
    );
    expect(requests, hasLength(1));
    expect(requests.single.method, 'POST');
  });
  test(
    'plan list mapping keeps status/date/title but does not preload details',
    () async {
      final service = ServiceBusinessPlan();
      final plans = await service.fetchPlans(
        user: 'one@example.com',
        dateFrom: from,
        dateTo: to,
      );
      expect(plans.single.id, 'p');
      expect(plans.single.title, '企劃');
      expect(plans.single.createdAt, DateTime.utc(2026, 10, 1, 12, 34, 56));
      expect(plans.single.status, 'in_progress');
      expect(plans.single.sections, isEmpty);
      expect(requests, hasLength(1));
      expect(
        requests.single.url.path,
        endsWith('/rpc/get_my_business_plan_window'),
      );
      expect(
        await service.hasPlansBefore(
          user: 'one@example.com',
          before: from,
        ),
        isFalse,
      );
      expect(requests, hasLength(1));
    },
  );
}
