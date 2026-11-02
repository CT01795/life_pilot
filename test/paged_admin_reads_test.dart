import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/feedback/controller_feedback_admin.dart';
import 'package:life_pilot/feedback/model_feedback_page.dart';
import 'package:life_pilot/feedback/service_feedback.dart';
import 'package:life_pilot/feedback/page_feedback_admin.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/subscription/controller_admin_subscription_page.dart';
import 'package:life_pilot/subscription/model_admin_subscription_page.dart';
import 'package:life_pilot/subscription/repository_admin_subscription_page.dart';
import 'package:life_pilot/subscription/widgets_admin_subscription_page.dart';
import 'package:life_pilot/utils/supabase.dart';

String uuid(int n) {
  final suffix = n.toRadixString(16).padLeft(12, '0');
  return '00000000-0000-0000-0000-$suffix';
}

Map<String, dynamic> feedback(
  int id, {
  String? date = '2026-11-01T00:00:00Z',
  String status = 'pending',
}) => {
  'id': id,
  'subject': 'Feedback $id',
  'content': 'body',
  'created_at': date,
  'status': status,
};
Map<String, dynamic> summary(int n) {
  final email = n.toString().padLeft(3, '0');
  return {
    'account': '$email@example.com',
    'user_id': uuid(n),
    'active_entitlements': 2,
  };
}

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

class _Auth extends ControllerAuth {
  String account = 'one@example.com';
  @override
  String get currentAccount => account;
  @override
  bool get isSysAdmin => true;
  void change() {
    account = 'two@example.com';
    notifyListeners();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SupabaseClient client;
  late List<http.Request> requests;
  Object? payload;
  var missing = false, denied = false;
  Completer<void>? gate;
  setUp(() async {
    requests = [];
    missing = false;
    denied = false;
    gate = null;
    payload = null;
    client = SupabaseClient(
      'https://example.supabase.co',
      'key',
      httpClient: MockClient((request) async {
        requests.add(request);
        Object? body = payload;
        var status = 200;
        if (request.url.path.endsWith(
          'admin_list_user_subscription_summaries_page',
        )) {
          if (missing || denied) {
            body = {'code': denied ? '42501' : 'PGRST202', 'message': 'test'};
            status = denied ? 403 : 404;
          } else {
            body ??= {'rows': List.generate(51, (i) => summary(i + 1))};
          }
        } else if (request.url.path.endsWith(
          'admin_list_user_subscription_summaries',
        )) {
          body ??= List.generate(51, (i) => summary(i + 1));
        } else {
          final filter = request.url.queryParameters['or'] ?? '';
          final match = RegExp(r'id\.lt\.(\d+)').firstMatch(filter);
          final before = match == null ? 121 : int.parse(match[1]!);
          body ??= [
            for (var i = before - 1; i > 0 && i >= before - 51; i--)
              feedback(i),
          ];
        }
        final pending = gate;
        if (pending != null) {
          await pending.future;
        }
        return http.Response(
          jsonEncode(body),
          status,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    supabase = client;
    await login(client, 'one');
  });
  tearDown(() => client.dispose());

  test(
    'feedback bounded 50 rows, no screenshot/CC or separate history query',
    () async {
      final page = await ServiceFeedback().loadFeedbackPage(
        statuses: {'pending', 'in_progress'},
      );
      expect(page.rows, hasLength(50));
      expect(page.hasMore, isTrue);
      expect(page.cursor!.id, 71);
      final q = requests.single.url.queryParameters;
      expect(q['limit'], '51');
      expect(q['select'], isNot(contains('screenshot')));
      expect(q['select']!.split(','), isNot(contains('cc')));
      expect(q['or'], contains('status.eq.pending'));
      expect(q['or'], contains('status.eq.in_progress'));
      expect(
        q['or'],
        contains('and(status.is.null,or(is_ok.eq.false,is_ok.is.null))'),
      );
      expect(q['order'], contains('created_at.desc.nullslast'));
      expect(q['order'], contains('id.desc'));
    },
  );
  test(
    'feedback keyset covers equal timestamps with no skipped lookahead row',
    () async {
      final ids = <int>[];
      FeedbackCursor? cursor;
      while (true) {
        final page = await ServiceFeedback().loadFeedbackPage(
          statuses: {'pending'},
          before: cursor,
        );
        ids.addAll(page.rows.map((r) => r.id));
        cursor = page.cursor;
        if (!page.hasMore) break;
      }
      expect(ids, List.generate(120, (i) => 120 - i));
      expect(ids.toSet(), hasLength(120));
      expect(requests, hasLength(3));
    },
  );
  test(
    'feedback null-date cursor stays in null rows and uses ID tie-break',
    () async {
      payload = [feedback(2, date: null), feedback(1, date: null)];
      final page = await ServiceFeedback().loadFeedbackPage(
        statuses: {'completed'},
        before: const FeedbackCursor(null, 3),
      );
      expect(page.cursor!.createdAt, isNull);
      expect(
        requests.single.url.queryParameters['or'],
        contains('and(created_at.is.null,id.lt.3)'),
      );
      expect(
        requests.single.url.queryParameters['or'],
        contains('and(status.is.null,is_ok.eq.true)'),
      );
    },
  );
  test(
    'empty statuses issue no query; invalid status never reaches network',
    () async {
      expect(
        (await ServiceFeedback().loadFeedbackPage(statuses: {})).rows,
        isEmpty,
      );
      await expectLater(
        ServiceFeedback().loadFeedbackPage(statuses: {'invalid'}),
        throwsArgumentError,
      );
      expect(requests, isEmpty);
    },
  );
  test('admin modern page has lookahead and typed cursor', () async {
    final page = await RepositoryAdminSubscriptionPage(client).read();
    expect(page.rows, hasLength(50));
    expect(page.hasMore, isTrue);
    expect(page.cursor!.userId, uuid(50));
    expect(jsonDecode(requests.single.body)['p_limit'], 50);
  });
  test(
    'admin missing function fallback is bounded; next legacy page skips repeat probe',
    () async {
      missing = true;
      final repo = RepositoryAdminSubscriptionPage(client),
          first = await RepositoryAdminSubscriptionPage(client).read();
      expect(first.legacy, isTrue);
      expect(first.rows, hasLength(50));
      expect(requests, hasLength(2));
      expect(requests.last.url.queryParameters['limit'], '51');
      await repo.read(offset: 50, legacy: true);
      expect(requests, hasLength(3));
      expect(requests.last.url.queryParameters['offset'], '50');
    },
  );
  test('admin permission error never falls back to the old list', () async {
    denied = true;
    await expectLater(
      RepositoryAdminSubscriptionPage(client).read(),
      throwsA(isA<PostgrestException>()),
    );
    expect(requests, hasLength(1));
  });
  test('admin late old-session page is discarded', () async {
    gate = Completer<void>();
    final checked = expectLater(
      RepositoryAdminSubscriptionPage(client).read(),
      throwsStateError,
    );
    await Future<void>.delayed(Duration.zero);
    await login(client, 'two');
    gate!.complete();
    await checked;
  });
  test(
    'feedback failed append preserves records/cursor and retries same cursor',
    () async {
      final auth = _Auth();
      addTearDown(auth.dispose);
      final cursors = <int?>[];
      var fail = true;
      final c = ControllerFeedbackAdmin(
        ServiceFeedback(),
        auth,
        pageLoader: ({required statuses, before}) async {
          cursors.add(before?.id);
        if (before == null) {
            return FeedbackPage.fromRows(
              List.generate(51, (i) => feedback(100 - i)),
            );
        }
          if (fail) throw StateError('offline');
          return FeedbackPage.fromRows([feedback(50)]);
        },
      );
      addTearDown(c.dispose);
      await c.loadFeedback();
      await c.loadMore();
      expect(c.feedbackList, hasLength(50));
      expect(c.loadMoreError, isNotNull);
      fail = false;
      await c.loadMore();
      expect(cursors, [null, 51, 51]);
      expect(c.feedbackList, hasLength(51));
      expect(c.hasMore, isFalse);
    },
  );
  test(
    'feedback status change supersedes pending page, empty selection stops reads',
    () async {
      final auth = _Auth();
      addTearDown(auth.dispose);
      final pending = Completer<FeedbackPage>();
      var calls = 0;
      final c = ControllerFeedbackAdmin(
        ServiceFeedback(),
        auth,
        pageLoader: ({required statuses, before}) async {
          calls++;
          return calls == 1
              ? pending.future
              : const FeedbackPage(rows: [], hasMore: false);
        },
      );
      addTearDown(c.dispose);
      final old = c.loadFeedback();
      c.toggleStatus('completed');
      await Future<void>.delayed(Duration.zero);
      pending.complete(FeedbackPage.fromRows([feedback(1)]));
      await old;
      expect(c.feedbackList, isEmpty);
      c.toggleStatus('pending');
      c.toggleStatus('in_progress');
      c.toggleStatus('completed');
      await Future<void>.delayed(Duration.zero);
      expect(c.selectedStatuses, isEmpty);
      expect(c.hasMore, isFalse);
      expect(c.isLoading, isFalse);
      expect(calls, 4);
    },
  );
  test(
    'feedback account change ignores old page and stops stale appends',
    () async {
      final auth = _Auth();
      addTearDown(auth.dispose);
      final pending = Completer<FeedbackPage>();
      var calls = 0;
      final c = ControllerFeedbackAdmin(
        ServiceFeedback(),
        auth,
        pageLoader: ({required statuses, before}) {
          calls++;
          return pending.future;
        },
      );
      addTearDown(c.dispose);
      final old = c.loadFeedback();
      auth.change();
      pending.complete(
        FeedbackPage.fromRows(List.generate(51, (i) => feedback(100 - i))),
      );
      await old;
      await c.loadMore();
      expect(c.feedbackList, isEmpty);
      expect(c.hasMore, isFalse);
      expect(calls, 1);
    },
  );
  test(
    'admin controller blocks duplicate load and retries failed page without losing rows',
    () async {
      final auth = _Auth();
      addTearDown(auth.dispose);
      var calls = 0;
      var fail = true;
      final offsets = <int>[];
      final c = ControllerAdminSubscriptionPage(
        auth: auth,
        load: ({after, required offset, required legacy}) async {
          calls++;
          offsets.add(offset);
          if (offset > 0 && fail) throw StateError('offline');
          return AdminSubscriptionPage.fromRows(
            offset == 0
                ? List.generate(51, (i) => summary(i + 1))
                : [summary(51)],
          );
        },
      );
      addTearDown(c.dispose);
      await Future.wait([c.load(), c.load()]);
      expect(calls, 1);
      await c.load(more: true);
      expect(c.rows, hasLength(50));
      expect(c.error, isNotNull);
      expect(c.retryMore, isTrue);
      fail = false;
      await c.load(more: c.retryMore);
      expect(offsets, [0, 50, 50]);
      expect(c.rows, hasLength(51));
    },
  );
  test(
    'admin controller drops stale account results and stops further paging',
    () async {
      final auth = _Auth();
      addTearDown(auth.dispose);
      final pending = Completer<AdminSubscriptionPage>();
      final c = ControllerAdminSubscriptionPage(
        auth: auth,
        load: ({after, required offset, required legacy}) => pending.future,
      );
      addTearDown(c.dispose);
      final old = c.load();
      auth.change();
      pending.complete(
        AdminSubscriptionPage.fromRows(
          List.generate(51, (i) => summary(i + 1)),
        ),
      );
      await old;
      expect(c.rows, isEmpty);
      expect(c.loading, isFalse);
      expect(c.hasMore, isFalse);
    },
  );
  testWidgets(
    'default feedback page actually uses bounded loading and load-more',
    (tester) async {
      final auth = _Auth();
      addTearDown(auth.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider<ControllerAuth>.value(
          value: auth,
          child: MaterialApp(
            locale: const Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: const PageFeedbackAdmin(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(requests, hasLength(1));
      expect(requests.single.url.queryParameters['limit'], '51');
      final loc = AppLocalizations.of(
        tester.element(find.byType(PageFeedbackAdmin)),
      )!;
      await tester.scrollUntilVisible(
        find.text(loc.clickHereToSeeMore),
        500,
        maxScrolls: 30,
      );
      await tester.tap(find.text(loc.clickHereToSeeMore));
      await tester.pumpAndSettle();
      expect(requests, hasLength(2));
      expect(requests.last.url.queryParameters['or'], contains('id.lt.71'));
    },
  );
  testWidgets(
    'admin summary widget offers retry and a usable account selection',
    (tester) async {
      final auth = _Auth();
      addTearDown(auth.dispose);
      var calls = 0;
      String? selected;
      await tester.pumpWidget(
        ChangeNotifierProvider<ControllerAuth>.value(
          value: auth,
          child: MaterialApp(
            locale: const Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(
              body: AdminSubscriptionSummaryList(
                onSelected: (email) => selected = email,
                load: ({after, required offset, required legacy}) async {
                  if (calls++ == 0) throw StateError('offline');
                  return AdminSubscriptionPage.fromRows([summary(1)]);
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final loc = AppLocalizations.of(
        tester.element(find.byType(AdminSubscriptionSummaryList)),
      )!;
      await tester.tap(find.text(loc.retry));
      await tester.pumpAndSettle();
      await tester.tap(find.text('001@example.com'));
      expect(selected, '001@example.com');
      expect(calls, 2);
    },
  );
}
