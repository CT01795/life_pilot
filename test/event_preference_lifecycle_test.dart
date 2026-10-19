import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/event/controller_event.dart';
import 'package:life_pilot/event/model_event.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/event/service_event.dart';
import 'package:life_pilot/event/service_event_public.dart';
import 'package:life_pilot/event/service_event_tracking.dart';
import 'package:life_pilot/l10n/app_localizations_en.dart';
import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/service/service_weather.dart';

class _Auth extends ControllerAuth {
  String? account = 'one@example.com';
  bool local = false;
  @override
  String? get currentAccount => account;
  @override
  DataStorageLocation get preferredStorage =>
      local ? DataStorageLocation.local : DataStorageLocation.cloud;
  void change({bool storage = false}) {
    if (storage) {
      local = !local;
    } else {
      account = 'two@example.com';
    }
    notifyListeners();
  }
}

class _Events extends ServiceEvent {
  final pending = <Completer<void>>[];
  final accounts = <String>[];
  final tables = <String?>[];
  final snapshots = <EventItem>[];
  @override
  Future<void> updateLikeEvent({
    required EventItem event,
    required String account,
    String? tableName,
  }) {
    accounts.add(account);
    tables.add(tableName);
    snapshots.add(event);
    final completion = Completer<void>();
    pending.add(completion);
    return completion.future;
  }
}

class _Tracking extends EventTrackingService {
  final columns = <String>[];
  @override
  Future<void> incrementEventCounter({
    required String eventId,
    required String eventName,
    required String column,
  }) async {
    columns.add(column);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final table in [
    TableNames.recommendEvents,
    TableNames.recommendPlaces,
  ]) {
    for (final like in [true, false]) {
      group('$table ${like ? 'like' : 'dislike'}', () {
        late _Auth auth;
        late _Events events;
        late _Tracking tracking;
        late ControllerEvent controller;
        late ServiceEventPublic public;
        late EventItem event;
        Future<void> act() =>
            like ? controller.likeEvent(event) : controller.dislikeEvent(event);
        setUp(() {
          auth = _Auth();
          events = _Events();
          tracking = _Tracking();
          public = ServiceEventPublic();
          event = EventItem(
            id: 'a',
            name: 'a',
            isLike: false,
            isDislike: false,
          );
          controller = ControllerEvent(
            auth: auth,
            serviceEvent: events,
            serviceWeather: ServiceWeather(),
            modelEvent: ModelEvent(),
            serviceEventPublic: public,
            eventTracking: tracking,
            tableName: table,
          );
          controller.modelEvent.setEvents([event]);
        });
        tearDown(() {
          if (!controller.notifierDisposed) controller.dispose();
          for (final pending in events.pending) {
            if (!pending.isCompleted) pending.complete();
          }
          auth.dispose();
          public.close();
        });
        test(
          'publishes optimistic preference and saves under the captured account',
          () async {
            final pending = act();
            expect(event.isLike, like);
            expect(event.isDislike, !like);
            expect(events.accounts, ['one@example.com']);
            expect(tracking.columns, isEmpty);
            events.pending.single.complete();
            await pending;
            expect(tracking.columns, isEmpty);
            expect(events.tables, [table]);
          },
        );
        test(
          'turning off a preference saves false without counting navigation',
          () async {
            event.isLike = like;
            event.isDislike = !like;
            final pending = act();
            expect(event.isLike, isFalse);
            expect(event.isDislike, isFalse);
            events.pending.single.complete();
            await pending;
            expect(tracking.columns, isEmpty);
            expect(events.snapshots.single.isLike, false);
            expect(events.snapshots.single.isDislike, false);
          },
        );
        test(
          'current-scope save failure restores the original nullable state',
          () async {
            event.isLike = null;
            event.isDislike = null;
            final pending = act();
            final error = expectLater(pending, throwsStateError);
            events.pending.single.completeError(StateError('save failed'));
            await error;
            expect(event.isLike, isNull);
            expect(event.isDislike, isNull);
            expect(tracking.columns, isEmpty);
          },
        );
        test(
          'rapid duplicate action cannot issue overlapping preference writes',
          () async {
            final pending = act();
            await act();
            expect(events.pending, hasLength(1));
            expect(events.snapshots.single, isNot(same(event)));
            event.isLike = null;
            event.isDislike = null;
            expect(events.snapshots.single.isLike, like);
            expect(events.snapshots.single.isDislike, !like);
            events.pending.single.complete();
            await pending;
            final next = act();
            expect(events.pending, hasLength(2));
            events.pending.last.complete();
            await next;
          },
        );
        for (final storage in [false, true]) {
          for (final fail in [false, true]) {
            test(
              'scope change storage=$storage failure=$fail cannot publish into new data',
              () async {
                var notifications = 0;
                controller.addListener(() => notifications++);
                final pending = act();
                final done = fail
                    ? expectLater(pending, throwsStateError)
                    : pending;
                auth.change(storage: storage);
                final current = EventItem(id: 'current', name: 'current');
                controller.modelEvent.setEvents([current]);
                final visible = controller.getFilteredEvents(
                  AppLocalizationsEn(),
                );
                final before = notifications;
                if (fail) {
                  events.pending.single.completeError(
                    StateError('old save failed'),
                  );
                } else {
                  events.pending.single.complete();
                }
                await done;
                expect(notifications, before);
                expect(tracking.columns, isEmpty);
                expect(controller.findEventById('current'), same(current));
                expect(visible, [current]);
              },
            );
          }
        }
        test(
          'disposal during persistence skips later tracking and notification',
          () async {
            var notifications = 0;
            controller.addListener(() => notifications++);
            final pending = act();
            final before = notifications;
            controller.dispose();
            events.pending.single.complete();
            await pending;
            expect(tracking.columns, isEmpty);
            expect(notifications, before);
          },
        );
        test('disposed controller ignores new preference actions', () async {
          controller.dispose();
          await act();
          expect(events.pending, isEmpty);
          expect(event.isLike, isFalse);
          expect(event.isDislike, isFalse);
        });
        test(
          'account change from a synchronous listener prevents the save',
          () async {
            var switched = false;
            controller.addListener(() {
              if (!switched) {
                switched = true;
                auth.change();
              }
            });
            await act();
            expect(events.pending, isEmpty);
            expect(tracking.columns, isEmpty);
          },
        );
        test(
          'missing account does not mutate preferences or write data',
          () async {
            auth.account = null;
            auth.notifyListeners();
            await act();
            expect(events.pending, isEmpty);
            expect(event.isLike, isFalse);
            expect(event.isDislike, isFalse);
          },
        );
      });
    }
  }
}
