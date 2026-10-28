import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/event/model_event.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/l10n/app_localizations_en.dart';

class _DeferredEvent extends EventItem {
  _DeferredEvent(String id, DateTime date)
    : super(id: id, name: id, startDate: date);
  @override
  String get description => throw StateError('unexpected text decoding');
  @override
  List<EventItem> get subEvents =>
      throw StateError('unexpected child decoding');
}

void main() {
  final loc = AppLocalizationsEn();

  test('date-only filtering leaves all descriptions and children deferred', () {
    final rows = [
      for (var i = 0; i < 10000; i++)
        _DeferredEvent('$i', DateTime(2026, 10, i.isEven ? 28 : 27)),
    ];
    final model = ModelEvent()
      ..setEvents(rows)
      ..updateStartDate(DateTime(2026, 10, 28));
    final result = model.getFilteredEvents(loc);
    expect(result, rows.where((row) => row.startDate!.day == 28).toList());
    expect(model.getFilteredEvents(loc), same(result));
  });

  test(
    'removed-only filtering excludes all matching IDs without text work',
    () {
      final rows = [
        _DeferredEvent('keep', DateTime(2026, 10, 28)),
        _DeferredEvent('remove', DateTime(2026, 10, 28)),
        _DeferredEvent('remove', DateTime(2026, 10, 29)),
      ];
      final model = ModelEvent()
        ..setEvents(rows)
        ..markRemoved('remove');
      expect(model.getFilteredEvents(loc), [rows.first]);
      expect(rows.length, 3);
    },
  );

  test('combined keyword date and removal filters keep source order', () {
    final random = Random(2810);
    for (var batch = 0; batch < 100; batch++) {
      final rows = [
        for (var i = 0; i < 100; i++)
          EventItem(
            id: '$i',
            name: random.nextBool() ? 'needle' : 'other',
            startDate: DateTime(2026, 10, 25 + random.nextInt(7)),
            endDate: DateTime(2026, 10, 25 + random.nextInt(7)),
          ),
      ];
      final model = ModelEvent()
        ..setEvents(rows)
        ..updateStartDate(DateTime(2026, 10, 27))
        ..updateEndDate(DateTime(2026, 10, 29))
        ..updateSearchKeywords('needle');
      for (var i = 0; i < 100; i += 7) {
        model.markRemoved('$i');
      }
      expect(
        model.getFilteredEvents(loc),
        rows
            .where(
              (row) =>
                  int.parse(row.id) % 7 != 0 &&
                  row.endDate!.day >= 27 &&
                  row.startDate!.day <= 29 &&
                  row.name == 'needle',
            )
            .toList(),
      );
    }
  });

  test('scope reset cannot retain a previous filtered snapshot', () {
    final model = ModelEvent()
      ..setEvents([EventItem(id: 'old', name: 'needle')])
      ..updateSearchKeywords('needle');
    final old = model.getFilteredEvents(loc);
    model.resetForDataScope();
    model.setEvents([EventItem(id: 'new', name: 'new')]);
    final current = model.getFilteredEvents(loc);
    expect(current.single.id, 'new');
    expect(current, isNot(same(old)));
    expect(old.single.id, 'old');
  });
}
