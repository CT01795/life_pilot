import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/event/model_event.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/l10n/app_localizations_en.dart';

EventItem _event(
  String id, {
  DateTime? date,
  int hour = 9,
  String city = 'A',
  bool liked = false,
}) => EventItem(
  id: id,
  name: id,
  city: city,
  startDate: date,
  startTime: TimeOfDay(hour: hour, minute: 0),
  isLike: liked,
);

class _ObservedEvent extends EventItem {
  _ObservedEvent(DateTime date)
    : super(id: 'one', name: 'one', startDate: date);
  int orderReads = 0;
  @override
  DateTime? get startDate {
    orderReads++;
    return super.startDate;
  }
}

void main() {
  final today = DateTime(2026, 10, 21);
  final loc = AppLocalizationsEn();
  for (final isEvent in [true, false]) {
    group(isEvent ? 'activities' : 'attractions', () {
      late ModelEvent model;
      setUp(() => model = ModelEvent());
      void append(List<EventItem> rows) =>
          model.appendRecommendedEvents(rows, isEvent: isEvent, now: today);
      test(
        'duplicate-only and empty pages preserve filtered result and skip sorting',
        () {
          final first = _ObservedEvent(today);
          append([first]);
          model.updateSearchKeywords('one');
          final previous = model.getFilteredEvents(loc);
          final reads = first.orderReads;
          append([_event('one', date: today, city: 'Changed')]);
          append([]);
          expect(model.getFilteredEvents(loc), same(previous));
          expect(model.findEventById('one'), same(first));
          expect(first.orderReads, reads);
        },
      );
      test(
        'new rows deduplicate and sort while keeping first matching object',
        () {
          final first = _event('first', date: today, city: 'Z');
          append([first]);
          final liked = _event('liked', date: today, liked: true);
          append([
            liked,
            _event('liked', date: today),
            _event('first', date: today),
          ]);
          expect(model.getFilteredEvents(loc).map((e) => e.id), [
            'liked',
            'first',
          ]);
          expect(model.findEventById('liked'), same(liked));
        },
      );
      test(
        'explicit edit invalidates order even if next page adds nothing',
        () {
          final a = _event('a', date: today), b = _event('b', date: today);
          append([a, b]);
          b.isLike = true;
          model.updateEvent(b);
          append([_event('a', date: today)]);
          expect(model.getFilteredEvents(loc).map((e) => e.id), ['b', 'a']);
        },
      );
      test('scope reset cannot reuse previous order or filter results', () {
        append([_event('old', date: today)]);
        final old = model.getFilteredEvents(loc);
        model.resetForDataScope();
        append([_event('new', date: today)]);
        expect(model.getFilteredEvents(loc).single.id, 'new');
        expect(identical(model.getFilteredEvents(loc), old), false);
      });
      test(
        'replacement snapshots require sorting even when append is empty',
        () {
          append([_event('old', date: today)]);
          model.setProgressiveEvents([
            _event('neutral', date: today),
            _event('liked', date: today, liked: true),
          ]);
          append([]);
          expect(model.getFilteredEvents(loc).map((e) => e.id), [
            'liked',
            'neutral',
          ]);
        },
      );
      test(
        'generic append cannot leave a supposedly current recommendation order',
        () {
          append([_event('neutral', date: today)]);
          model.appendEvents([_event('liked', date: today, liked: true)]);
          append([]);
          expect(model.getFilteredEvents(loc).map((e) => e.id), [
            'liked',
            'neutral',
          ]);
        },
      );
    });
  }
  test('empty page after midnight still updates ongoing activity order', () {
    final model = ModelEvent();
    model.appendRecommendedEvents(
      [
        _event(
          'ongoing',
          date: today.subtract(const Duration(days: 1)),
          hour: 12,
        ),
        _event('next-day', date: today.add(const Duration(days: 1)), hour: 9),
      ],
      isEvent: true,
      now: today,
    );
    final previous = model.getFilteredEvents(loc);
    expect(previous.map((e) => e.id), ['ongoing', 'next-day']);
    model.appendRecommendedEvents(
      [],
      isEvent: true,
      now: today.add(const Duration(days: 1)),
    );
    expect(model.getFilteredEvents(loc).map((e) => e.id), [
      'next-day',
      'ongoing',
    ]);
    expect(identical(previous, model.getFilteredEvents(loc)), false);
  });
  test('a memory sort invalidates the recorded recommendation order', () {
    final model = ModelEvent();
    model.appendRecommendedEvents(
      [
        _event('old', date: today.subtract(const Duration(days: 1))),
        _event('new', date: today),
      ],
      isEvent: true,
      now: today,
    );
    model.sortMemoryEvents();
    expect(model.getFilteredEvents(loc).first.id, 'new');
    model.appendRecommendedEvents([], isEvent: true, now: today);
    expect(model.getFilteredEvents(loc).first.id, 'old');
  });
  test(
    'switching recommendation type does not reuse an incompatible order',
    () {
      final model = ModelEvent();
      model.appendRecommendedEvents(
        [
          _event('earlier', date: today, city: 'Z'),
          _event('later', date: today.add(const Duration(days: 1)), city: 'A'),
        ],
        isEvent: true,
        now: today,
      );
      expect(model.getFilteredEvents(loc).first.id, 'earlier');
      model.appendRecommendedEvents([], isEvent: false, now: today);
      expect(model.getFilteredEvents(loc).first.id, 'later');
    },
  );
}
