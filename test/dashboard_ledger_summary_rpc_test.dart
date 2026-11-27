import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_pilot/pages/home/repository/repository_dashboard.dart';
import 'package:life_pilot/pages/home/model/event/calendar_event.dart';
import 'package:life_pilot/pages/home/controller_dashboard.dart';
import 'package:life_pilot/utils/provider_locale.dart';
import 'package:life_pilot/utils/supabase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'pull refresh reuses a current shared summary, never a late bootstrap',
    () async {
      const account = 'person@example.com';
      final bootstraps = <Completer<Object>>[];
      var standaloneReads = 0;
      Map<String, Object> event(String id) => {
        'id': id,
        'name': id,
        'start_date': DateTime.now().toUtc().toIso8601String(),
        'is_completed': false,
        'account': account,
        'is_shared': false,
      };
      Map<String, Object> snapshot(String id, int total) => {
        'setting': {
          'recommend_event_city': '台北',
          'recommend_place_city': '台中',
          'language': 'zh',
        },
        'today_events': [event(id)],
        'shared_ledgers': [
          {
            'share_id': 'share',
            'kind': 'accounting',
            'account_name': 'shared',
            'snapshot': {
              'totals': {'total': total},
              'entries': [],
            },
          },
        ],
      };
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        httpClient: MockClient((request) async {
          final Object body;
          if (request.url.path.endsWith(
            '/get_or_create_my_dashboard_core_v2',
          )) {
            final pending = Completer<Object>();
            bootstraps.add(pending);
            body = await pending.future;
          } else {
            expect(request.url.path, endsWith('/calendar_events'));
            standaloneReads++;
            body = [event('direct')];
          }
          return http.Response(
            jsonEncode(body),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      supabase = client;
      addTearDown(client.dispose);
      final locale = ProviderLocale(locale: const Locale('zh'));
      addTearDown(locale.dispose);
      final controller = ControllerDashboard(
        repository: DashboardRepository(),
        localeProvider: locale,
      )..switchAccount(account);
      addTearDown(controller.dispose);
      Future<void> flush() => Future<void>.delayed(Duration.zero);

      final initial = controller.refreshCore(account: account);
      await flush();
      bootstraps.single.complete(snapshot('initial', 1));
      await initial;
      expect(controller.sharedToday(points: false)?['total'], 1);

      final older = controller.refreshCore(
        account: account,
        refreshShared: true,
      );
      final newest = controller.refreshCore(
        account: account,
        refreshShared: true,
      );
      await flush();
      bootstraps[2].complete(snapshot('newest', 3));
      await newest;
      bootstraps[1].complete(snapshot('obsolete', 2));
      await older;
      expect(controller.sharedToday(points: false)?['total'], 3);
      expect(controller.state.todayEvents.single.id, 'newest');
      expect(standaloneReads, 0);

      await controller.refreshTodaySchedule(account: account);
      expect(controller.state.todayEvents.single.id, 'direct');
      expect(standaloneReads, 1);
    },
  );

  test('dashboard bootstrap returns setting and both summaries once', () async {
    final requests = <http.Request>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({
            'setting': {
              'recommend_event_city': '台北',
              'recommend_place_city': '台中',
              'language': 'zh',
              'accounting_account_id': 'accounting-id',
              'accounting_account_name': '現金',
              'point_account_id': 'point-id',
              'point_account_name': '積分',
            },
            'accounting': {
              'total': 120,
              'today_total': -10,
              'currency': 'TWD',
              'records': [],
            },
            'points': {'total': 50, 'today_total': 5, 'records': []},
            'shared_ledgers': [],
            'today_events': [
              {
                'id': 'today',
                'name': 'Today event',
                'start_date': DateTime.now().toUtc().toIso8601String(),
                'is_completed': false,
                'account': 'person@example.com',
                'is_shared': false,
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    supabase = client;

    final repository = DashboardRepository();
    final bootstrap = await repository.loadDashboardBootstrap(
      account: 'person@example.com',
    );

    expect(bootstrap.setting.accountingAccountName, '現金');
    expect(bootstrap.accounting?.total, 120);
    expect(bootstrap.points?.total, 50);
    expect(bootstrap.todayEvents?.single.id, 'today');
    expect(requests, hasLength(1));
    expect(
      requests.single.url.path,
      endsWith('/rpc/get_or_create_my_dashboard_core_v2'),
    );
  });

  test('dashboard ledger summaries each use one compact RPC', () async {
    final requests = <http.Request>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final points = body['p_kind'] == 'points';
        return http.Response(
          jsonEncode({
            'total': points ? 1500 : 120.5,
            'today_total': points ? 20 : -30.5,
            if (!points) 'currency': 'TWD',
            'records': [
              {
                'description': 'recent',
                'value': points ? 20 : -30.5,
                if (points) 'type': '+',
                if (!points) 'currency': 'TWD',
                'date': '2026-11-11T03:00:00Z',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    supabase = client;

    final repository = DashboardRepository();
    final accounting = await repository.loadAccountingSummary(accountId: 'a');
    final points = await repository.loadPointSummary(accountId: 'p');

    expect(accounting.total, 120.5);
    expect(accounting.todayTotal, -30.5);
    expect(accounting.records.single.description, 'recent');
    expect(points.total, 1500);
    expect(points.todayTotal, 20);
    expect(points.records.single.description, 'recent');
    expect(requests, hasLength(2));
    expect(
      requests.every(
        (request) =>
            request.url.path.endsWith('/rpc/get_my_dashboard_ledger_summary'),
      ),
      isTrue,
    );
  });

  test(
    'schedule list omits deferred detail and one detail read restores it',
    () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        httpClient: MockClient((request) async {
          requests.add(request);
          if (request.url.queryParameters['select']?.contains('description') ==
              true) {
            return http.Response(
              jsonEncode({
                'id': 'event',
                'name': 'Event',
                'description': 'Full detail',
                'sub_events': [
                  {'id': 'child'},
                ],
                'account': 'person@example.com',
              }),
              200,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }
          return http.Response(
            '[]',
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      supabase = client;
      final repository = DashboardRepository();

      await repository.loadTodayEvents('person@example.com');
      final summarySelect = requests.single.url.queryParameters['select']!;
      expect(summarySelect, isNot(contains('description')));
      expect(summarySelect, isNot(contains('sub_events')));

      final detail = await repository.loadCalendarEventDetail(
        summary: CalendarEvent(id: 'event', name: 'Event'),
        account: 'person@example.com',
      );
      expect(detail.description, 'Full detail');
      expect(detail.subEvents.single['id'], 'child');
      expect(requests, hasLength(2));
    },
  );

  test('home recommendations use one combined RPC', () async {
    final requests = <http.Request>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({
            'events': [
              {'id': 'event', 'name': 'Event'},
            ],
            'places': [
              {'id': 'place', 'name': 'Place'},
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    supabase = client;

    final result = await DashboardRepository().loadRecommendations(
      eventCity: '台北',
      placeCity: '台中',
    );

    expect(result.events.single.id, 'event');
    expect(result.places.single.id, 'place');
    expect(requests, hasLength(1));
    expect(requests.single.url.path, endsWith('/rpc/get_home_recommendations'));
    expect(jsonDecode(requests.single.body), {
      'p_event_city': '台北',
      'p_place_city': '台中',
      'p_limit': 5,
    });
  });
}
