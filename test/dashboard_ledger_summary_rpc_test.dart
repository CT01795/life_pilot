import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_pilot/pages/home/repository/repository_dashboard.dart';
import 'package:life_pilot/utils/supabase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
    final setting = await repository.loadDashboardSetting(
      account: 'person@example.com',
    );
    final accounting = await repository.loadAccountingSummary(
      accountId: 'accounting-id',
    );
    final points = await repository.loadPointSummary(accountId: 'point-id');

    expect(setting.accountingAccountName, '現金');
    expect(accounting.total, 120);
    expect(points.total, 50);
    expect(requests, hasLength(1));
    expect(
      requests.single.url.path,
      endsWith('/rpc/get_or_create_my_dashboard_core'),
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
}
