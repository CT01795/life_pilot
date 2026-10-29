import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/accounting/controller_accounting_detail.dart';
import 'package:life_pilot/accounting/model_accounting_detail.dart';
import 'package:life_pilot/accounting/model_accounting_preview.dart';
import 'package:life_pilot/accounting/service_accounting.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:life_pilot/point_record/controller_point_record_detail.dart';
import 'package:life_pilot/point_record/model_point_record_detail.dart';
import 'package:life_pilot/point_record/model_point_record_preview.dart';
import 'package:life_pilot/point_record/service_point_record.dart';
import 'package:life_pilot/utils/safe_change_notifier.dart';

class _Auth extends ControllerAuth {
  String account = 'a@example.com';
  DataStorageLocation storage = DataStorageLocation.cloud;
  int usageReads = 0;
  @override
  String get currentAccount => account;
  @override
  DataStorageLocation get preferredStorage => storage;
  @override
  Future<void> refreshSubscriptionUsage({bool notify = true}) async {
    usageReads++;
  }

  void changeAccount() {
    account = 'b@example.com';
    notifyListeners();
  }

  void changeStorage() {
    storage = DataStorageLocation.local;
    notifyListeners();
  }
}

class _Row {
  _Row(this.id, {DateTime? date, this.category = 'food'})
    : date = date ?? DateTime.now();
  final String id, category;
  final DateTime date;
}

class _Requests {
  final pages = <Completer<List<_Row>>>[];
  final ranges = <(DateTime, DateTime, bool, bool)>[];
  final histories = <Completer<bool>>[];
  final beforeDates = <DateTime>[];
  final latest = <Completer<DateTime?>>[];
  final cursors = <DateTime>[];
  final writes = <Completer<void>>[];
  Future<List<_Row>> page(
    DateTime from,
    DateTime to,
    bool fallback,
    bool reserved,
  ) {
    ranges.add((from, to, fallback, reserved));
    final done = Completer<List<_Row>>();
    pages.add(done);
    return done.future;
  }

  Future<bool> history(DateTime before) {
    beforeDates.add(before);
    final done = Completer<bool>();
    histories.add(done);
    return done.future;
  }

  Future<DateTime?> older(DateTime before) {
    cursors.add(before);
    final done = Completer<DateTime?>();
    latest.add(done);
    return done.future;
  }

  Future<void> write() {
    final done = Completer<void>();
    writes.add(done);
    return done.future;
  }
}

class _Accounting extends ServiceAccounting {
  _Accounting(this.requests);
  final _Requests requests;
  @override
  Future<List<ModelAccountingDetail>> fetchRecordsPage({
    required String accountId,
    required String type,
    required DateTime dateFrom,
    required DateTime dateTo,
    bool includeLatestFallback = false,
    bool includeReservedRecords = true,
  }) async {
    final rows = await requests.page(
      dateFrom,
      dateTo,
      includeLatestFallback,
      includeReservedRecords,
    );
    return List.unmodifiable(
      rows.map(
        (row) => ModelAccountingDetail(
          id: row.id,
          accountId: accountId,
          createdAt: row.date,
          date: row.date,
          primaryCategory: row.category,
          description: row.id,
          type: type,
          value: 1.25,
          currency: 'TWD',
          balance: 10.5,
        ),
      ),
    );
  }

  @override
  Future<bool> hasRecordsBefore({
    required String accountId,
    required String type,
    required DateTime before,
  }) => requests.history(before);
  @override
  Future<DateTime?> latestRecordDateBefore({
    required String accountId,
    required String type,
    required DateTime before,
  }) => requests.older(before);
  @override
  Future<void> insertRecordsBatch({
    required String accountId,
    required String type,
    required List<AccountingPreview> records,
    required String? currency,
  }) => requests.write();
  @override
  Future<void> updateAccountingDetail({
    required String detailId,
    required num newValue,
    required String newCurrency,
    required String newDescription,
    required DateTime newDate,
    required String newPrimaryCategory,
    String? newSecondaryCategory,
  }) => requests.write();
  @override
  Future<void> deleteAccountingDetail({required String detailId}) =>
      requests.write();
}

class _Points extends ServicePointRecord {
  _Points(this.requests);
  final _Requests requests;
  @override
  Future<List<ModelPointRecordDetail>> fetchRecordsPage({
    required String accountId,
    required String type,
    required DateTime dateFrom,
    required DateTime dateTo,
    bool includeLatestFallback = false,
    bool includeReservedRecords = true,
  }) async {
    final rows = await requests.page(
      dateFrom,
      dateTo,
      includeLatestFallback,
      includeReservedRecords,
    );
    return List.unmodifiable(
      rows.map(
        (row) => ModelPointRecordDetail(
          id: row.id,
          accountId: accountId,
          createdAt: row.date,
          date: row.date,
          primaryCategory: row.category,
          description: row.id,
          type: type,
          value: 1,
          points: 10,
        ),
      ),
    );
  }

  @override
  Future<bool> hasRecordsBefore({
    required String accountId,
    required String type,
    required DateTime before,
  }) => requests.history(before);
  @override
  Future<DateTime?> latestRecordDateBefore({
    required String accountId,
    required String type,
    required DateTime before,
  }) => requests.older(before);
  @override
  Future<void> insertRecordsBatch({
    required String accountId,
    required String type,
    required List<PointRecordPreview> records,
  }) => requests.write();
  @override
  Future<void> updatePointRecordDetail({
    required String detailId,
    required int newValue,
    required String newDescription,
    required DateTime newDate,
    required String newPrimaryCategory,
    String? newSecondaryCategory,
  }) => requests.write();
  @override
  Future<void> deletePointRecordDetail({required String detailId}) =>
      requests.write();
}

class _Harness {
  _Harness.accounting(ControllerAccountingDetail c)
    : controller = c,
      load = c.loadToday,
      more = c.loadMore,
      ids = (() => c.todayRecords.map((r) => r.id).toList()),
      loading = (() => c.isLoading),
      loadingMore = (() => c.isLoadingMore),
      commit = (() => c.commitRecords([
        AccountingPreview(
          description: 'A',
          value: 1.25,
          currency: 'TWD',
          exchangeRate: 1,
        ),
      ])),
      update = (() => c.updateAccountingDetail(
        AccountingPreview(
          id: 'a',
          description: 'A',
          value: 2.5,
          currency: 'TWD',
          exchangeRate: 1,
        ),
      )),
      delete = (() => c.deleteAccountingDetail('a'));
  _Harness.points(ControllerPointRecordDetail c)
    : controller = c,
      load = c.loadToday,
      more = c.loadMore,
      ids = (() => c.todayRecords.map((r) => r.id).toList()),
      loading = (() => c.isLoading),
      loadingMore = (() => c.isLoadingMore),
      commit = (() =>
          c.commitRecords([PointRecordPreview(description: 'A', value: 1)])),
      update = (() => c.updatePointRecordDetail(
        PointRecordPreview(id: 'a', description: 'A', value: 2),
      )),
      delete = (() => c.deletePointRecordDetail('a'));
  final SafeChangeNotifier controller;
  final Future<void> Function({String? inputAccountId}) load, more;
  final Future<void> Function() commit, update, delete;
  final List<String> Function() ids;
  final bool Function() loading, loadingMore;
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  for (final accounting in [true, false]) {
    group(accounting ? 'accounting detail' : 'point detail', () {
      late _Auth auth;
      late _Requests requests;
      late _Harness h;
      setUp(() {
        auth = _Auth();
        requests = _Requests();
        h = accounting
            ? _Harness.accounting(
                ControllerAccountingDetail(
                  service: _Accounting(requests),
                  auth: auth,
                  accountId: 'acct',
                ),
              )
            : _Harness.points(
                ControllerPointRecordDetail(
                  service: _Points(requests),
                  auth: auth,
                  accountId: 'acct',
                ),
              );
      });
      tearDown(() {
        if (!h.controller.notifierDisposed) h.controller.dispose();
        auth.dispose();
      });
      Future<void> seed({bool more = true}) async {
        final pending = h.load();
        requests.pages.last.complete([_Row('initial')]);
        await _flush();
        requests.histories.last.complete(more);
        await pending;
      }

      test(
        'latest fallback excludes reserved rows when choosing history cursor',
        () async {
          final pending = h.load();
          requests.pages.single.complete([
            _Row('reserved', category: 'reserved'),
            _Row('old', date: DateTime(2026, 4, 15)),
          ]);
          await _flush();
          expect(requests.beforeDates.single, DateTime(2026, 4, 15));
          requests.histories.single.complete(false);
          await pending;
          expect(h.ids(), ['reserved', 'old']);
        },
      );
      for (final change in ['account', 'storage', 'dispose']) {
        test(
          '$change during initial query prevents metadata and publication',
          () async {
            final pending = h.load();
            if (change == 'account') {
              auth.changeAccount();
            } else if (change == 'storage') {
              auth.changeStorage();
            } else {
              h.controller.dispose();
            }
            requests.pages.single.complete([_Row('old')]);
            await pending;
            expect(requests.histories, isEmpty);
            expect(h.ids(), isEmpty);
          },
        );
      }
      test(
        'same-account notification retains visible records without requery',
        () async {
          await seed();
          auth.notifyListeners();
          expect(h.ids(), ['initial']);
          expect(requests.pages.length, 1);
        },
      );
      test(
        'account switch during initial notification prevents unsent read',
        () async {
          var changed = false;
          h.controller.addListener(() {
            if (!changed && h.loading()) {
              changed = true;
              auth.changeAccount();
            }
          });
          await h.load();
          expect(requests.pages, isEmpty);
        },
      );
      test('full refresh blocks new load-more until it completes', () async {
        await seed();
        final refreshed = h.load();
        await h.more();
        expect(requests.latest, isEmpty);
        requests.pages.last.complete([_Row('new')]);
        await _flush();
        requests.histories.last.complete(false);
        await refreshed;
        expect(h.ids(), ['new']);
      });
      test('full refresh supersedes pending older-date probe', () async {
        await seed();
        final old = h.more();
        final fresh = h.load();
        requests.latest.single.complete(DateTime(2026, 4));
        await old;
        expect(requests.pages.length, 2);
        expect(h.loading(), isTrue);
        requests.pages.last.complete([_Row('new')]);
        await _flush();
        requests.histories.last.complete(false);
        await fresh;
        expect(h.ids(), ['new']);
        expect(h.loadingMore(), isFalse);
      });
      test('late history page cannot append after full refresh', () async {
        await seed();
        final old = h.more();
        requests.latest.single.complete(DateTime(2026, 4));
        await _flush();
        final fresh = h.load();
        requests.pages.last.complete([_Row('new')]);
        await _flush();
        requests.histories.last.complete(false);
        await fresh;
        final metadataCalls = requests.histories.length;
        requests.pages[1].complete([_Row('stale')]);
        await old;
        expect(h.ids(), ['new']);
        expect(requests.histories.length, metadataCalls);
      });
      test(
        'read-only service pages can append and deduplicate safely',
        () async {
          await seed();
          final old = h.more();
          requests.latest.single.complete(DateTime(2026, 4));
          await _flush();
          requests.pages.last.complete([
            _Row('older', date: DateTime(2026, 4)),
            _Row('initial'),
          ]);
          await _flush();
          requests.histories.last.complete(false);
          await old;
          expect(h.ids(), ['initial', 'older']);
        },
      );
      test(
        'storage change while metadata is pending discards all old results',
        () async {
          final pending = h.load();
          requests.pages.single.complete([_Row('old')]);
          await _flush();
          auth.changeStorage();
          requests.histories.single.complete(true);
          await pending;
          expect(h.ids(), isEmpty);
          expect(h.loading(), isFalse);
        },
      );
      test(
        'history-page failure keeps records and retries the same cursor',
        () async {
          await seed();
          final pending = h.more();
          final checked = expectLater(pending, throwsStateError);
          requests.latest.single.complete(DateTime(2026, 4));
          await _flush();
          requests.pages.last.completeError(StateError('offline'));
          await checked;
          expect(h.ids(), ['initial']);
          expect(h.loadingMore(), isFalse);
          final retry = h.more();
          expect(requests.cursors.last, requests.cursors.first);
          requests.latest.last.complete(null);
          await retry;
          expect(h.ids(), ['initial']);
        },
      );
      test(
        'metadata failure retains visible data and allows full retry',
        () async {
          await seed();
          final pending = h.load();
          final checked = expectLater(pending, throwsStateError);
          requests.pages.last.complete([_Row('new')]);
          await _flush();
          requests.histories.last.completeError(StateError('metadata'));
          await checked;
          expect(h.ids(), ['initial']);
          expect(h.loading(), isFalse);
          final retry = h.load();
          requests.pages.last.complete([_Row('retried')]);
          await _flush();
          requests.histories.last.complete(false);
          await retry;
          expect(h.ids(), ['retried']);
        },
      );

      for (final operation in ['commit', 'update', 'delete']) {
        Future<void> act() => switch (operation) {
          'commit' => h.commit(),
          'update' => h.update(),
          _ => h.delete(),
        };
        for (final change in ['account', 'storage', 'dispose']) {
          test(
            '$operation completion after $change does not reload or refresh usage',
            () async {
              final pending = act();
              expect(requests.writes.length, 1);
              if (change == 'account') {
                auth.changeAccount();
              } else if (change == 'storage') {
                auth.changeStorage();
              } else {
                h.controller.dispose();
              }
              requests.writes.single.complete();
              await pending;
              expect(auth.usageReads, 0);
              expect(requests.pages, isEmpty);
            },
          );
        }
      }
      test(
        'successful commit refreshes usage and reloads the current detail',
        () async {
          final pending = h.commit();
          requests.writes.single.complete();
          await _flush();
          expect(auth.usageReads, 1);
          requests.pages.single.complete([_Row('saved')]);
          await _flush();
          requests.histories.single.complete(false);
          await pending;
          expect(h.ids(), ['saved']);
        },
      );
      test('disposed controller ignores reads and all writes', () async {
        h.controller.dispose();
        await h.load();
        await h.more();
        await h.commit();
        await h.update();
        await h.delete();
        expect(requests.writes, isEmpty);
        expect(requests.pages, isEmpty);
      });
    });
  }
}
