import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/event/model_event.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/l10n/app_localizations_en.dart';

void main() {
  final loc = AppLocalizationsEn();
  final day = DateTime(2026, 10, 22);
  ModelEvent create() => ModelEvent()
    ..setEvents([
      EventItem(id: 'a', name: 'Music', startDate: day),
      EventItem(id: 'b', name: 'Park', startDate: DateTime(2026, 11, 1)),
    ]);
  test(
    'equal keywords retain results while restoring mutable display tags',
    () {
      final model = create()..updateSearchKeywords('Music');
      final before = model.getFilteredEvents(loc);
      model.searchFilter.tags.clear();
      model.updateSearchKeywords('Music');
      expect(model.searchFilter.tags, ['Music']);
      expect(model.getFilteredEvents(loc), same(before));
      model.updateSearchKeywords('Park');
      expect(model.getFilteredEvents(loc).single.id, 'b');
    },
  );
  test('null and empty keywords are the same unfiltered condition', () {
    final model = create();
    final before = model.getFilteredEvents(loc);
    model.updateSearchKeywords(null);
    expect(model.getFilteredEvents(loc), same(before));
    model.updateSearchKeywords('');
    expect(model.getFilteredEvents(loc), same(before));
  });
  test('equal date values and repeated clears retain the filtered list', () {
    final model = create()
      ..updateStartDate(day)
      ..updateEndDate(day);
    final before = model.getFilteredEvents(loc);
    model.updateStartDate(DateTime(2026, 10, 22));
    model.updateEndDate(DateTime(2026, 10, 22));
    expect(model.getFilteredEvents(loc), same(before));
    model.updateStartDate(null);
    model.updateEndDate(null);
    final cleared = model.getFilteredEvents(loc);
    expect(cleared.length, 2);
    model.updateStartDate(null);
    model.updateEndDate(null);
    expect(model.getFilteredEvents(loc), same(cleared));
  });
  test('moving start after end still adjusts both bounds and invalidates', () {
    final model = create()..updateEndDate(day);
    final before = model.getFilteredEvents(loc);
    final next = DateTime(2026, 11, 1);
    model.updateStartDate(next);
    expect(model.searchFilter.endDate, next);
    expect(model.getFilteredEvents(loc), isNot(same(before)));
    expect(model.getFilteredEvents(loc).single.id, 'b');
  });
  test('moving end before start still adjusts both bounds and invalidates', () {
    final model = create()..updateStartDate(DateTime(2026, 11, 1));
    model.getFilteredEvents(loc);
    model.updateEndDate(day);
    expect(model.searchFilter.startDate, day);
    expect(model.getFilteredEvents(loc).single.id, 'a');
  });
  test('equal search input cannot hide explicit edits or appended records', () {
    final model = create()..updateSearchKeywords('Music');
    model.getFilteredEvents(loc);
    model.updateEvent(EventItem(id: 'a', name: 'Changed'));
    model.updateSearchKeywords('Music');
    expect(model.getFilteredEvents(loc), isEmpty);
    model.appendEvents([EventItem(id: 'c', name: 'Music')]);
    model.updateSearchKeywords('Music');
    expect(model.getFilteredEvents(loc).single.id, 'c');
    model.resetForDataScope();
    model.updateSearchKeywords('Music');
    expect(model.getFilteredEvents(loc), isEmpty);
  });
}
