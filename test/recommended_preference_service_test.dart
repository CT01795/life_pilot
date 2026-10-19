import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/event/service_event.dart';
import 'package:life_pilot/l10n/app_localizations_en.dart';
import 'package:life_pilot/l10n/app_localizations_ja.dart';
import 'package:life_pilot/l10n/app_localizations_ko.dart';
import 'package:life_pilot/l10n/app_localizations_zh.dart';
import 'package:life_pilot/utils/api.dart' as api;
import 'package:life_pilot/utils/const.dart';

void main() {
  late SupabaseClient client;
  late List<http.Request> requests;
  var fail = false;
  setUp(() {
    requests = [];
    fail = false;
    client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(
          fail
              ? jsonEncode({'code': 'P0001', 'message': 'content_not_visible'})
              : '',
          fail ? 400 : 204,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    api.supabase = client;
  });
  tearDown(() => client.dispose());
  for (final table in [
    TableNames.recommendEvents,
    TableNames.recommendPlaces,
  ]) {
    for (final state in [(true, false), (false, true), (false, false)]) {
      test(
        '$table persists $state with one atomic RPC, never an increment request',
        () async {
          await ServiceEvent().updateLikeEvent(
            event: EventItem(
              id: 'content',
              name: 'Name',
              isLike: state.$1,
              isDislike: state.$2,
            ),
            account: 'one@example.com',
            tableName: table,
          );
          expect(requests, hasLength(1));
          expect(
            requests.single.url.path,
            '/rest/v1/rpc/set_recommended_content_preference',
          );
          expect(jsonDecode(requests.single.body), {
            'p_table_name': table,
            'p_content_id': 'content',
            'p_is_like': state.$1,
            'p_is_dislike': state.$2,
          });
        },
      );
    }
  }
  test('RPC failure is propagated so the controller can roll back', () async {
    fail = true;
    await expectLater(
      ServiceEvent().updateLikeEvent(
        event: EventItem(id: 'content', name: 'Name'),
        account: 'one@example.com',
        tableName: TableNames.recommendPlaces,
      ),
      throwsA(isA<PostgrestException>()),
    );
    expect(requests, hasLength(1));
  });
  test('all four navigation counter labels are localized', () {
    expect(AppLocalizationsZh().vendorAnalyticsCardClicks, '導航點擊');
    expect(AppLocalizationsEn().vendorAnalyticsCardClicks, 'Navigation clicks');
    expect(AppLocalizationsJa().vendorAnalyticsCardClicks, 'ナビクリック');
    expect(AppLocalizationsKo().vendorAnalyticsCardClicks, '길찾기 클릭');
  });
}
