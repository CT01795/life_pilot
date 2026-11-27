import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_pilot/accounting/repository_ledger_overview_page.dart';
import 'package:life_pilot/accounting/page_ledger_sharing.dart';
import 'package:life_pilot/accounting/service_ledger_sharing.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets(
    'overview cards render the provided count without an initial RPC',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Column(
              children: [
                LedgerReviewButton(
                  kind: LedgerKind.accounting,
                  accountId: 'a',
                  pagePendingCount: 0,
                ),
                LedgerReviewButton(
                  kind: LedgerKind.points,
                  accountId: 'b',
                  pagePendingCount: 3,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final loc = AppLocalizations.of(tester.element(find.byType(Scaffold)))!;
      expect(find.text('${loc.ledgerPendingProposals} (3)'), findsOneWidget);
      expect(find.text('${loc.ledgerPendingProposals} (0)'), findsNothing);
      expect(find.byType(TextButton), findsOneWidget);
    },
  );
  for (final kind in ['accounting', 'points']) {
    test(
      '$kind overview sends one paged request and keeps actual zero',
      () async {
        final requests = <http.Request>[];
        var rows =
            '[{"id":"a","pending_count":0},{"id":"b","pending_count":3}]';
        final client = SupabaseClient(
          'https://example.supabase.co',
          'key',
          httpClient: MockClient((request) async {
            requests.add(request);
            return http.Response(
              rows,
              200,
              request: request,
              headers: {'content-type': 'application/json'},
            );
          }),
        );
        addTearDown(client.dispose);
        final repository = RepositoryLedgerOverviewPage(client);
        Future<List<Map<String, dynamic>>> read() => repository.read(
          kind: kind,
          expectedEmail: 'a@example.com',
          category: 'personal',
          search: ' food ',
          offset: 20,
          limit: 11,
        );
        expect((await read()).map((row) => row['pending_count']), [0, 3]);
        expect(
          requests.single.url.path,
          endsWith('/list_my_ledger_overview_page'),
        );
        expect(jsonDecode(requests.single.body), {
          'p_kind': kind,
          'p_expected_email': 'a@example.com',
          'p_category': 'personal',
          'p_search': 'food',
          'p_offset': 20,
          'p_limit': 11,
        });
        rows = '[{"id":"a","pending_count":null}]';
        await expectLater(read(), throwsFormatException);
        expect(requests, hasLength(2));
      },
    );
  }

  test('SQL paginates before counting and keeps account RLS', () {
    final sql = File(
      'supabase/migrations/20261127000400_ledger_overview_pending_counts.sql',
    ).readAsStringSync();
    expect(sql, contains('security invoker'));
    expect(sql, contains('auth.uid() is null'));
    expect(sql, contains('from public, anon'));
    expect(sql, isNot(contains('master_graph_url')));
    expect(
      RegExp('offset p_offset limit p_limit').allMatches(sql),
      hasLength(2),
    );
    expect(
      RegExp('get_my_ledger_account_pending_count').allMatches(sql),
      hasLength(2),
    );
  });
}
