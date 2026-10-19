import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/event/model_event.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/event/model_event_search_query.dart';
import 'package:life_pilot/l10n/app_localizations_en.dart';

void main() {
  final loc = AppLocalizationsEn();
  test('display tokens preserve case and matching is case insensitive', () {
    final query = ModelEventSearchQuery(' MUSIC，Park\tTaipei\n18Y ');
    expect(query.tokens, ['MUSIC', 'Park', 'Taipei', '18Y']);
    expect(
      query.matches(
        EventItem(id: 'e', name: ''),
        searchableText: () => 'music park taipei',
      ),
      isTrue,
    );
  });

  test('display tokens cannot change the compiled query', () {
    final query = ModelEventSearchQuery('Music');
    expect(() => query.tokens.add('other'), throwsUnsupportedError);
    expect(query.tokens, ['Music']);
  });

  for (final input in <String?>[null, '', '  ,，\t\n']) {
    test('empty input $input clears previous tags and results', () {
      final model = ModelEvent()
        ..setEvents([
          EventItem(id: 'a', name: 'Music'),
          EventItem(id: 'b', name: 'Park'),
        ])
        ..updateSearchKeywords('Music');
      expect(model.getFilteredEvents(loc).single.id, 'a');
      model.updateSearchKeywords(input);
      expect(model.searchFilter.tags, isEmpty);
      expect(model.getFilteredEvents(loc).length, 2);
    });
  }

  test('mutable display tags cannot mutate matching terms', () {
    final model = ModelEvent()
      ..setEvents([
        EventItem(id: 'a', name: 'Music Park'),
        EventItem(id: 'b', name: 'Music'),
      ])
      ..updateSearchKeywords('Music Park');
    expect(model.searchFilter.tags, ['Music', 'Park']);
    model.searchFilter.tags.clear();
    model.updateStartDate(null);
    expect(model.getFilteredEvents(loc).single.id, 'a');
    model.updateSearchKeywords('Music Park');
    expect(model.searchFilter.tags, ['Music', 'Park']);
  });

  test('dates and appended records retain the current query meaning', () {
    final model = ModelEvent()
      ..setEvents([
        EventItem(id: 'old', name: 'Music', startDate: DateTime(2026, 9, 1)),
        EventItem(id: 'new', name: 'Music', startDate: DateTime(2026, 10, 19)),
      ])
      ..updateSearchKeywords('MUSIC');
    expect(model.getFilteredEvents(loc).length, 2);
    model.updateStartDate(DateTime(2026, 10, 1));
    expect(model.getFilteredEvents(loc).single.id, 'new');
    model.appendEvents([
      EventItem(id: 'append', name: 'music', startDate: DateTime(2026, 10, 20)),
    ]);
    expect(model.getFilteredEvents(loc).map((e) => e.id), ['new', 'append']);
    expect(model.searchFilter.tags, ['MUSIC']);
  });

  test('new keywords replace numeric and literal matching terms', () {
    final model = ModelEvent()
      ..setEvents([
        EventItem(id: 'young', name: 'Music', ageMin: 3, ageMax: 8),
        EventItem(id: 'adult', name: 'Park', ageMin: 18, ageMax: 80),
      ])
      ..updateSearchKeywords('5Y');
    expect(model.getFilteredEvents(loc).single.id, 'young');
    model.updateSearchKeywords('18Y');
    expect(model.getFilteredEvents(loc).single.id, 'adult');
    model.updateSearchKeywords('MUSIC');
    expect(model.getFilteredEvents(loc).single.id, 'young');
  });

  test('clear and scope reset discard both terms and tags', () {
    final model = ModelEvent()
      ..setEvents([EventItem(id: 'a', name: 'Music')])
      ..updateSearchKeywords('missing');
    expect(model.getFilteredEvents(loc), isEmpty);
    model.clearSearchAll();
    expect(model.searchFilter.tags, isEmpty);
    expect(model.getFilteredEvents(loc).single.id, 'a');
    model.updateSearchKeywords('Music');
    model.resetForDataScope();
    model.setEvents([EventItem(id: 'b', name: 'Park')]);
    expect(model.searchFilter.tags, isEmpty);
    expect(model.getFilteredEvents(loc).single.id, 'b');
  });
}
