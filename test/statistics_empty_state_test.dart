import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/event/model_content_performance.dart';
import 'package:life_pilot/event/model_content_performance_period.dart';
import 'package:life_pilot/event/page_content_performance.dart';
import 'package:life_pilot/event/service_content_performance.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:life_pilot/record_statistics/model_record_statistics.dart';
import 'package:life_pilot/record_statistics/page_record_statistics.dart';
import 'package:life_pilot/record_statistics/service_record_statistics.dart';
import 'record_statistics_test.dart' show StatisticsTestAuth;

class _Records extends ServiceRecordStatistics {
  final List<Map<String, dynamic>> rows;
  final bool fail;
  _Records({this.rows = const [], this.fail = false});
  @override
  Future<List<Map<String, dynamic>>> read({
    required String owner,
    required DataStorageLocation storage,
    required String accountId,
    required RecordStatisticsKind kind,
    required DateTime now,
    String? currency,
    bool history = false,
  }) async {
    if (fail) throw StateError('offline');
    return rows;
  }
}

class _Performance extends ServiceContentPerformance {
  @override
  Future<ModelContentPerformance> read({
    required String owner,
    required bool attractions,
    bool includeSubmissionDetails = false,
    ContentPerformancePeriod? period,
    String keyword = '',
    bool statisticsOnly = false,
  }) async => ModelContentPerformance([]);
}

Widget _app(StatisticsTestAuth auth, Widget page, String language) =>
    ChangeNotifierProvider<ControllerAuth>.value(
      value: auth,
      child: MaterialApp(
        locale: Locale(language),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: page,
      ),
    );

void main() {
  test(
    'empty, invalid and future-only records do not produce a historical chart',
    () {
      final now = DateTime(2026, 10, 20);
      for (final rows in <List<Map<String, dynamic>>>[
        [],
        [
          {'date': 'invalid', 'value': 100},
        ],
        [
          {'date': '2026-11-01', 'value': 100},
        ],
      ]) {
        expect(
          ModelRecordStatistics.fromRows(rows, now: now).hasChartData,
          false,
        );
      }
    },
  );
  test('zero, offsetting and opening records remain real chart data', () {
    final now = DateTime(2026, 10, 20);
    for (final rows in <List<Map<String, dynamic>>>[
      [
        {'date': '2026-10-01', 'value': 0},
      ],
      [
        {'date': '2026-10-01', 'value': 100},
        {'date': '2026-10-01', 'value': -100},
      ],
      [
        {'date': '2020-01-01', 'value': 100},
      ],
    ]) {
      expect(ModelRecordStatistics.fromRows(rows, now: now).hasChartData, true);
    }
  });
  for (final language in ['zh', 'en', 'ja', 'ko']) {
    for (final kind in RecordStatisticsKind.values) {
      for (final storage in DataStorageLocation.values) {
        testWidgets(
          '$language $kind $storage: empty chart displays localized message',
          (tester) async {
            final auth = StatisticsTestAuth()..storage = storage;
            addTearDown(auth.dispose);
            await tester.pumpWidget(
              _app(
                auth,
                PageRecordStatistics(
                  accountId: 'a',
                  accountName: 'Account',
                  kind: kind,
                  service: _Records(),
                ),
                language,
              ),
            );
            await tester.pumpAndSettle();
            final loc = AppLocalizations.of(
              tester.element(find.byType(PageRecordStatistics)),
            )!;
            expect(find.text(loc.statisticsNoData), findsOneWidget);
            expect(find.byType(ChoiceChip), findsNothing);
            expect(find.byType(CircularProgressIndicator), findsNothing);
            expect(tester.takeException(), null);
            await tester.pumpWidget(const SizedBox());
          },
        );
      }
    }
    for (final attractions in [false, true]) {
      testWidgets(
        '$language attractions=$attractions: empty performance displays localized message',
        (tester) async {
          final auth = StatisticsTestAuth();
          addTearDown(auth.dispose);
          await tester.pumpWidget(
            _app(
              auth,
              PageContentPerformance(
                attractions: attractions,
                service: _Performance(),
              ),
              language,
            ),
          );
          await tester.pumpAndSettle();
          final loc = AppLocalizations.of(
            tester.element(find.byType(PageContentPerformance)),
          )!;
          expect(find.text(loc.statisticsNoData), findsOneWidget);
          expect(find.byType(LinearProgressIndicator), findsNothing);
          expect(find.byType(CircularProgressIndicator), findsNothing);
          expect(find.byType(ExpansionTile), findsNothing);
          expect(tester.takeException(), null);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
  for (final kind in RecordStatisticsKind.values) {
    testWidgets(
      '$kind: valid zero-valued records must still display the chart',
      (tester) async {
        final auth = StatisticsTestAuth();
        addTearDown(auth.dispose);
        await tester.pumpWidget(
          _app(
            auth,
            PageRecordStatistics(
              accountId: 'a',
              accountName: 'Account',
              kind: kind,
              service: _Records(
                rows: [
                  {'date': DateTime.now().toIso8601String(), 'value': 0},
                ],
              ),
            ),
            'zh',
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('沒有資料可顯示'), findsNothing);
        expect(find.byType(ChoiceChip), findsNWidgets(2));
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets('a failed query is retryable, not a successful empty result', (
    tester,
  ) async {
    final auth = StatisticsTestAuth();
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      _app(
        auth,
        PageRecordStatistics(
          accountId: 'a',
          accountName: 'Account',
          kind: RecordStatisticsKind.accounting,
          service: _Records(fail: true),
        ),
        'zh',
      ),
    );
    await tester.pumpAndSettle();
    final loc = AppLocalizations.of(
      tester.element(find.byType(PageRecordStatistics)),
    )!;
    expect(find.text(loc.statisticsNoData), findsNothing);
    expect(find.text(loc.retry), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
