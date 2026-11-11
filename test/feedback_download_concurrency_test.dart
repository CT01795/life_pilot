import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_pilot/feedback/service_feedback.dart';
import 'package:life_pilot/utils/supabase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('feedback screenshot downloads use bounded batches', () async {
    var active = 0;
    var maximum = 0;
    var downloads = 0;
    final firstBatchStarted = Completer<void>();
    final release = Completer<void>();
    final client = SupabaseClient(
      'https://example.supabase.co',
      'key',
      httpClient: MockClient((request) async {
        if (request.url.path.contains(
          '/storage/v1/object/feedback-screenshots/',
        )) {
          downloads++;
          active++;
          if (active > maximum) maximum = active;
          if (active == 3 && !firstBatchStarted.isCompleted) {
            firstBatchStarted.complete();
          }
          await release.future;
          active--;
          return http.Response.bytes(
            [1, 2, 3],
            200,
            request: request,
            headers: {'content-type': 'application/octet-stream'},
          );
        }
        return http.Response(
          jsonEncode({
            'screenshot': <String>[],
            'screenshot_paths': List.generate(5, (index) => 'owner/$index.png'),
          }),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.dispose);
    await client.auth.setInitialSession(
      jsonEncode({
        'access_token': 'token',
        'token_type': 'bearer',
        'user': {
          'id': 'owner',
          'email': 'owner@example.com',
          'app_metadata': {},
          'user_metadata': {},
          'aud': 'authenticated',
          'created_at': '2026-01-01T00:00:00Z',
        },
      }),
    );
    supabase = client;

    final pending = ServiceFeedback().loadScreenshots(1);
    await firstBatchStarted.future.timeout(const Duration(seconds: 2));
    expect(downloads, 3);
    expect(maximum, 3);
    release.complete();
    final images = await pending;
    expect(images, hasLength(5));
    expect(downloads, 5);
    expect(maximum, 3);
  });
}
