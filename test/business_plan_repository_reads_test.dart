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
            TableNames.businessPlanTemplateSection => [
              {
                'id': 's1',
                'title': '章節一',
                'sort_order': 1,
                'plan_id': 't',
                'unused_blob': 'unneeded',
              },
              {
                'id': 's2',
                'title': '章節二',
                'sort_order': 2,
                'plan_id': 't',
                'unused_blob': 'unneeded',
              },
            ],
            TableNames.businessPlanTemplateQuestion => [
              {
                'id': 'q1',
                'prompt': '完整題目',
                'sort_order': 1,
                'unused_blob': 'unneeded',
              },
            ],
            _ =>
              r.url.queryParameters.containsKey('title')
                  ? duplicate
                        ? [
                            {
                              'id': 'existing',
                              'is_valid': true,
                              'title': 'same',
                            },
                          ]
                        : <Map<String, dynamic>>[]
                  : [
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
    'five read projections include only consumed fields and preserve filters/order',
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
      await repo.sections('t');
      expect(
        requests.last.url.queryParameters['select'],
        'id,title,sort_order',
      );
      expect(requests.last.url.queryParameters['plan_id'], 'eq.t');
      await repo.questions('s1');
      expect(requests.last.url.queryParameters['select'], 'prompt,sort_order');
      expect(requests.last.url.queryParameters['section_id'], 'eq.s1');
      expect(
        requests.last.url.queryParameters['order'],
        'sort_order.asc.nullslast',
      );
      await repo.existingPlan(user: 'one@example.com', title: 'Title');
      expect(requests.last.url.queryParameters['select'], 'id,is_valid');
      expect(
        requests.last.url.queryParameters[Fields.createdBy],
        'eq.one@example.com',
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
  test('different template structure keys do not merge', () async {
    gate = Completer<void>();
    final repo = RepositoryBusinessPlanReads(client);
    final a = repo.questions('s1'),
        b = repo.questions('s2'),
        c = repo.sections('t');
    await Future<void>.delayed(Duration.zero);
    expect(requests, hasLength(3));
    gate!.complete();
    await Future.wait([a, b, c]);
  });
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
  test('shared raw template data cannot be mutated by a caller', () async {
    final rows = await RepositoryBusinessPlanReads(client).sections('t');
    expect(() => rows.clear(), throwsUnsupportedError);
    expect(() => rows.first['title'] = 'changed', throwsUnsupportedError);
  });
  test(
    'plan lookup and list do not share reads across write workflows',
    () async {
      gate = Completer<void>();
      final repo = RepositoryBusinessPlanReads(client);
      final a = repo.existingPlan(user: 'one@example.com', title: 'x');
      final b = repo.existingPlan(user: 'one@example.com', title: 'x');
      final c = repo.plans(user: 'one@example.com', from: from, to: to);
      final d = repo.plans(user: 'one@example.com', from: from, to: to);
      await Future<void>.delayed(Duration.zero);
      expect(requests, hasLength(4));
      gate!.complete();
      await Future.wait([a, b, c, d]);
    },
  );
  test(
    'creating from a template keeps all section/question values and original writes',
    () async {
      await ServiceBusinessPlan().createPlanFromTemplate(
        user: 'one@example.com',
        planId: 'new',
        title: 'New',
        templateId: 't',
      );
      final writes = requests.where((r) => r.method == 'POST').toList();
      expect(writes, hasLength(5));
      expect(jsonDecode(writes.first.body), containsPair('template_id', 't'));
      expect(
        jsonDecode(writes.first.body),
        containsPair(Fields.createdBy, 'one@example.com'),
      );
      final sections = writes
          .where(
            (r) => r.url.path.endsWith('/${TableNames.businessPlanSection}'),
          )
          .toList();
      final questions = writes
          .where(
            (r) => r.url.path.endsWith('/${TableNames.businessPlanQuestion}'),
          )
          .toList();
      expect(sections, hasLength(2));
      expect(questions, hasLength(2));
      for (var i = 0; i < 2; i++) {
        final section = jsonDecode(sections[i].body) as Map;
        final question = (jsonDecode(questions[i].body) as List).single as Map;
        expect(section['plan_id'], 'new');
        expect(section['sort_order'], i + 1);
        expect(question['section_id'], section['id']);
        expect(question['prompt'], '完整題目');
        expect(question['sort_order'], 1);
        expect(question.containsKey('unused_blob'), isFalse);
      }
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
    expect(requests.single.method, 'GET');
  });
  test(
    'plan list mapping keeps status/date/title but does not preload details',
    () async {
      final plans = await ServiceBusinessPlan().fetchPlans(
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
    },
  );
}
