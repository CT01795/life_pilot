import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/event/controller_event.dart';
import 'package:life_pilot/event/model_event.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/event/model_event_load_policy.dart';
import 'package:life_pilot/event/service_event.dart';
import 'package:life_pilot/l10n/app_localizations_en.dart';
import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/service/service_weather.dart';

class _Auth extends ControllerAuth {
  String account = 'one@example.com';
  bool local = false;
  @override
  String get currentAccount => account;
  @override
  bool get isSysAdmin => false;
  @override
  bool get storesNewDataLocally => local;
  @override
  DataStorageLocation get preferredStorage =>
      local ? DataStorageLocation.local : DataStorageLocation.cloud;
}

class _Read {
  _Read(this.offset, this.active);
  final int offset;
  final bool Function()? active;
  final done = Completer<List<EventItem>>();
}

class _Service extends ServiceEvent {
  final reads = <_Read>[];
  int olderProbes = 0;
  Completer<DateTime?>? pendingOlder;
  @override
  Future<List<EventItem>?> getEvents({
    required String tableName,
    DateTime? dateS,
    DateTime? dateE,
    String? id,
    String? inputUser,
    DataStorageLocation? storageLocation,
    int? limit,
    int offset = 0,
    void Function(List<EventItem>)? onPartialEvents,
    bool Function()? shouldContinue,
  }) {
    final read = _Read(offset, shouldContinue);
    reads.add(read);
    return read.done.future;
  }

  @override
  Future<bool> hasEventsBefore({
    required String tableName,
    required DateTime before,
    String? inputUser,
    DataStorageLocation? storageLocation,
    bool Function()? shouldContinue,
  }) async => true;

  @override
  Future<DateTime?> latestEventDateBefore({
    required String tableName,
    required DateTime before,
    String? inputUser,
    DataStorageLocation? storageLocation,
    void Function(EventItem)? onLatestEvent,
    bool Function()? shouldContinue,
  }) async {
    olderProbes++;
    return pendingOlder?.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final table in [
    TableNames.recommendEvents,
    TableNames.recommendPlaces,
    TableNames.memoryTrace,
  ]) {
    group(table, () {
      late _Auth auth;
      late _Service service;
      late ControllerEvent c;
      final loc = AppLocalizationsEn();
      final size = ModelEventLoadPolicy.forTable(table).cloudPageSize;
      List<EventItem> rows(String prefix) => List.generate(
        size + 1,
        (i) => EventItem(
          id: '$prefix-$i',
          name: '$prefix-$i',
          startDate: DateTime.now(),
        ),
      );
      Future<void> more() => table == TableNames.memoryTrace
          ? c.loadMoreMemoryEvents()
          : c.loadMoreRecommendedEvents();
      bool loadingMore() => table == TableNames.memoryTrace
          ? c.isLoadingMoreMemory
          : c.isLoadingMoreEvents;
      setUp(() {
        auth = _Auth();
        service = _Service();
        c = ControllerEvent(
          auth: auth,
          serviceEvent: service,
          serviceWeather: ServiceWeather(),
          modelEvent: ModelEvent(),
          tableName: table,
        );
      });
      tearDown(() {
        if (!c.notifierDisposed) c.dispose();
        for (final read in service.reads) {
          if (!read.done.isCompleted) read.done.complete([]);
        }
        auth.dispose();
      });
      Future<void> seed() async {
        final initial = c.loadEvents(isGetPublicEvents: false);
        service.reads.last.done.complete(rows('seed'));
        await initial;
      }

      for (final fails in [false, true]) {
        for (final finishesFirst in [false, true]) {
          test(
            'reload supersedes paging (failure=$fails, old first=$finishesFirst)',
            () async {
              await seed();
              final old = more();
              final oldRead = service.reads.last;
              final fresh = c.loadEvents(isGetPublicEvents: false);
              final freshRead = service.reads.last;
              expect(oldRead.active!(), isFalse);
              expect(freshRead.active!(), isTrue);
              expect(c.isLoadingMoreEvents, isFalse);
              void finishOld() {
                if (fails) {
                  oldRead.done.completeError(StateError('obsolete'));
                } else {
                  oldRead.done.complete(rows('old'));
                }
              }

              if (finishesFirst) {
                finishOld();
                await old;
                expect(c.isLoadingEvents, isTrue);
              }
              freshRead.done.complete(rows('fresh'));
              await fresh;
              if (!finishesFirst) {
                finishOld();
                await old;
              }
              expect(c.getFilteredEvents(loc).length, size);
              expect(
                c.getFilteredEvents(loc).every((e) => e.id.startsWith('fresh')),
                isTrue,
              );
              expect(c.isLoadingEvents, isFalse);
              expect(loadingMore(), isFalse);
              final next = more();
              expect(service.reads.last.offset, size);
              service.reads.last.done.complete(rows('next'));
              await next;
              expect(c.getFilteredEvents(loc).length, size * 2);
            },
          );
        }
      }
      test(
        'full loading blocks a duplicate first-page paging request',
        () async {
          final initial = c.loadEvents(isGetPublicEvents: false);
          await more();
          expect(service.reads.length, 1);
          service.reads.single.done.complete(rows('initial'));
          await initial;
        },
      );
      test(
        'current paging failure keeps rows and retries the same offset',
        () async {
          await seed();
          final oldRows = c.getFilteredEvents(loc);
          final failed = more();
          final checked = expectLater(failed, throwsStateError);
          final offset = service.reads.last.offset;
          service.reads.last.done.completeError(StateError('offline'));
          await checked;
          expect(c.getFilteredEvents(loc), oldRows);
          expect(loadingMore(), isFalse);
          final retry = more();
          expect(service.reads.last.offset, offset);
          service.reads.last.done.complete(rows('retry'));
          await retry;
        },
      );
      for (final change in ['account', 'storage']) {
        for (final paging in [false, true]) {
          test(
            '$change during ${paging ? 'paging' : 'initial'} notification sends no stale read',
            () async {
              if (paging) await seed();
              final count = service.reads.length;
              var changed = false;
              c.addListener(() {
                if (changed) return;
                changed = true;
                if (change == 'account') {
                  auth.account = 'other@example.com';
                } else {
                  auth.local = true;
                }
                auth.notifyListeners();
              });
              await (paging ? more() : c.loadEvents(isGetPublicEvents: false));
              expect(service.reads.length, count);
              expect(service.olderProbes, 0);
              expect(c.getFilteredEvents(loc), isEmpty);
            },
          );
        }
      }
      test('disposed controller never starts reads', () async {
        c.dispose();
        await c.loadEvents(isGetPublicEvents: false);
        await more();
        expect(service.reads, isEmpty);
        expect(service.olderProbes, 0);
      });
      if (table == TableNames.memoryTrace) {
        for (final local in [false, true]) {
          test(
            'reload supersedes a pending older-date probe, local=$local',
            () async {
              auth.local = local;
              auth.notifyListeners();
              final first = c.loadEvents(isGetPublicEvents: false);
              service.reads.single.done.complete([
                EventItem(
                  id: 'initial',
                  name: 'initial',
                  startDate: DateTime.now(),
                ),
              ]);
              await first;
              service.pendingOlder = Completer<DateTime?>();
              final old = more();
              expect(service.olderProbes, 1);
              final fresh = c.loadEvents(isGetPublicEvents: false);
              final count = service.reads.length;
              service.pendingOlder!.complete(DateTime(2026, 4));
              await old;
              expect(service.reads.length, count);
              expect(c.isLoadingEvents, isTrue);
              service.reads.last.done.complete(rows('fresh'));
              await fresh;
              expect(
                c.getFilteredEvents(loc).every((e) => e.id.startsWith('fresh')),
                isTrue,
              );
            },
          );
        }
      }
    });
  }
}
