import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/calendar/model_calendar.dart';
import 'package:life_pilot/calendar/model_calendar_month_query.dart';
import 'package:life_pilot/calendar/service_calendar_month.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/event/service_event.dart';
import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:life_pilot/utils/const.dart';

class _Events extends ServiceEvent {
  final response = Completer<List<EventItem>?>();
  int calls = 0;
  String? owner;
  String? table;
  DataStorageLocation? storage;
  DateTime? start, end;
  bool Function()? active;
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
    void Function(List<EventItem> events)? onPartialEvents,
    bool Function()? shouldContinue,
  }) {
    calls++;
    owner = inputUser;
    table = tableName;
    storage = storageLocation;
    start = dateS;
    end = dateE;
    active = shouldContinue;
    return response.future;
  }
}

ModelCalendarMonthQuery _query(DataStorageLocation? storage) =>
    ModelCalendarMonthQuery(
      month: DateTime(2026, 10),
      start: DateTime(2026, 9, 27),
      end: DateTime(2026, 10, 31),
      account: 'owner@example.com',
      storage: storage,
      locale: const Locale('ja'),
      tableName: TableNames.calendarEvents,
    );

void main() {
  late _Events events;
  late Completer<List<EventItem>> holidays;
  late ServiceCalendarMonth service;
  late List<(DateTime, DateTime, Locale)> holidayCalls;
  setUp(() {
    events = _Events();
    holidays = Completer<List<EventItem>>();
    holidayCalls = [];
    service = ServiceCalendarMonth(
      serviceEvent: events,
      holidays: (start, end, locale) {
        holidayCalls.add((start, end, locale));
        return holidays.future;
      },
    );
  });

  for (final storage in [
    DataStorageLocation.cloud,
    DataStorageLocation.local,
    null,
  ]) {
    test(
      'forwards snapshot and calendar grid bounds with storage=$storage',
      () async {
        final query = _query(storage);
        final pending = service.loadMonth(query);
        expect(events.calls, 1);
        expect(events.owner, query.account);
        expect(events.table, query.tableName);
        expect(events.storage, storage);
        expect(events.start, query.start);
        expect(events.end, query.end);
        expect(holidayCalls.single, (
          DateTime(2026, 9, 25),
          DateTime(2026, 11, 2),
          const Locale('ja'),
        ));
        events.response.complete([]);
        holidays.complete([]);
        expect(await pending, isEmpty);
      },
    );
  }

  test(
    'event and holiday requests start concurrently and merge once ready',
    () async {
      var complete = false;
      final pending = service.loadMonth(_query(DataStorageLocation.cloud)).then(
        (value) {
          complete = true;
          return value;
        },
      );
      expect(events.calls, 1);
      expect(holidayCalls.length, 1);
      final event = EventItem(id: 'event', name: 'event');
      final holiday = EventItem(
        id: 'holiday',
        name: 'holiday',
        isHoliday: true,
      );
      events.response.complete([event]);
      await Future<void>.delayed(Duration.zero);
      expect(complete, false);
      holidays.complete([holiday]);
      expect(await pending, [event, holiday]);
    },
  );

  test('inactive scope starts neither event nor holiday query', () async {
    expect(
      await service.loadMonth(_query(null), shouldContinue: () => false),
      isEmpty,
    );
    expect(events.calls, 0);
    expect(holidayCalls, isEmpty);
  });

  test(
    'events publish before slow holidays and final result includes both',
    () async {
      final previews = <List<EventItem>>[];
      final pending = service.loadMonth(
        _query(null),
        onEventsReady: previews.add,
      );
      final event = EventItem(id: 'event', name: 'event');
      events.response.complete([event]);
      await Future<void>.delayed(Duration.zero);
      expect(previews.single, [event]);
      final holiday = EventItem(id: 'holiday', name: 'holiday');
      holidays.complete([holiday]);
      expect(await pending, [event, holiday]);
    },
  );

  test(
    'stale event preview is suppressed while holidays are pending',
    () async {
      var active = true;
      final previews = <List<EventItem>>[];
      final pending = service.loadMonth(
        _query(null),
        shouldContinue: () => active,
        onEventsReady: previews.add,
      );
      active = false;
      events.response.complete([]);
      await Future<void>.delayed(Duration.zero);
      expect(previews, isEmpty);
      holidays.complete([]);
      expect(await pending, isEmpty);
    },
  );

  test('scope predicate is forwarded and late results are discarded', () async {
    var active = true;
    final pending = service.loadMonth(
      _query(null),
      shouldContinue: () => active,
    );
    expect(events.active!(), true);
    active = false;
    expect(events.active!(), false);
    events.response.complete([EventItem(id: 'old', name: 'old')]);
    holidays.complete([EventItem(id: 'holiday', name: 'holiday')]);
    expect(await pending, isEmpty);
  });

  test('null event result still retains holidays', () async {
    final pending = service.loadMonth(_query(null));
    events.response.complete(null);
    final holiday = EventItem(id: 'holiday', name: 'holiday');
    holidays.complete([holiday]);
    expect(await pending, [holiday]);
  });

  for (final eventFails in [false, true]) {
    test(
      '${eventFails ? 'event' : 'holiday'} failure returns without waiting for the other response',
      () async {
        final previews = <List<EventItem>>[];
        final pending = service.loadMonth(
          _query(null),
          onEventsReady: previews.add,
        );
        final checked = expectLater(pending, throwsStateError);
        if (eventFails) {
          events.response.completeError(StateError('events'));
        } else {
          holidays.completeError(StateError('holidays'));
        }
        await checked;
        expect(events.active!(), isFalse);
        if (eventFails) {
          holidays.completeError(StateError('late holiday failure'));
        } else {
          events.response.complete([EventItem(id: 'late', name: 'late')]);
        }
        await Future<void>.delayed(Duration.zero);
        expect(previews, isEmpty);
      },
    );
  }

  test(
    'successful completion also closes the service read predicate',
    () async {
      final pending = service.loadMonth(_query(null));
      expect(events.active!(), isTrue);
      events.response.complete([]);
      holidays.complete([]);
      await pending;
      expect(events.active!(), isFalse);
    },
  );

  test(
    'a preview published before holiday failure stays a preview, not success',
    () async {
      final previews = <List<EventItem>>[];
      final pending = service.loadMonth(
        _query(null),
        onEventsReady: previews.add,
      );
      final checked = expectLater(pending, throwsStateError);
      final event = EventItem(id: 'preview', name: 'preview');
      events.response.complete([event]);
      await Future<void>.delayed(Duration.zero);
      expect(previews.single, [event]);
      holidays.completeError(StateError('holidays'));
      await checked;
      expect(events.active!(), isFalse);
      expect(previews.length, 1);
    },
  );

  test(
    'event failure remains visible to caller rather than becoming empty data',
    () async {
      final result = expectLater(
        service.loadMonth(_query(null)),
        throwsStateError,
      );
      events.response.completeError(StateError('read failed'));
      holidays.complete([]);
      await result;
    },
  );

  test('pure ordering preserves schedule rules without mutating input', () {
    EventItem row(
      String id,
      DateTime? day,
      TimeOfDay? time,
      String city,
      String place,
    ) => EventItem(
      id: id,
      name: id,
      startDate: day,
      startTime: time,
      city: city,
      location: place,
    );
    final day = DateTime(2026, 10, 20);
    const time = TimeOfDay(hour: 9, minute: 0);
    final rows = [
      row('z', day, time, 'B', 'A'),
      row('before', day.subtract(const Duration(days: 1)), time, 'Z', 'Z'),
      row('no-time', day, null, 'A', 'A'),
      row('b', day, time, 'A', 'A'),
      row('a', day, time, 'A', 'A'),
      row('place', day, time, 'A', 'B'),
      row('no-date', null, null, '', ''),
    ];
    final original = List.of(rows);
    final ordered = ModelCalendar.orderedEvents(rows);
    expect(ordered.map((event) => event.id), [
      'before',
      'a',
      'b',
      'place',
      'z',
      'no-time',
      'no-date',
    ]);
    expect(rows, original);
    expect(ordered.first, same(original[1]));
  });
}
