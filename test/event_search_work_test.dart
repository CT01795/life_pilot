import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/event/model_event.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/l10n/app_localizations_en.dart';
import 'package:life_pilot/l10n/app_localizations_zh.dart';

class _AlternateFreeLabel extends AppLocalizationsEn {
  @override
  String get free => 'complimentary';
}

class _TextEvent extends EventItem {
  _TextEvent(String id, DateTime? date, {List<EventItem> children = const []})
    : super(
        id: id,
        name: id,
        startDate: date,
        description: 'needle',
        subEvents: children,
      );
  int reads = 0;
  @override
  String get description {
    reads++;
    return super.description;
  }
}

void main() {
  final loc = AppLocalizationsEn();
  test('equivalent locale instances reuse the same filtered projection', () {
    final row = _TextEvent('event', DateTime(2026, 10, 1));
    final model = ModelEvent()
      ..setEvents([row])
      ..updateSearchKeywords('needle')
      ..updateStartDate(DateTime(2026, 10, 1));
    final first = model.getFilteredEvents(AppLocalizationsEn());
    for (var i = 0; i < 20; i++) {
      expect(model.getFilteredEvents(AppLocalizationsEn()), same(first));
    }
    expect(first, [row]);
    expect(row.reads, 1);
  });

  test(
    'changed search labels invalidate the cache even for the same language',
    () {
      final model = ModelEvent()
        ..setEvents([EventItem(id: 'e', name: '', isFree: true)])
        ..updateSearchKeywords('complimentary');
      expect(model.getFilteredEvents(AppLocalizationsEn()), isEmpty);
      expect(model.getFilteredEvents(_AlternateFreeLabel()).single.id, 'e');
      expect(model.getFilteredEvents(AppLocalizationsEn()), isEmpty);
    },
  );

  test('equivalent locale labels cannot reuse a projection after an edit', () {
    final model = ModelEvent()
      ..setEvents([EventItem(id: 'e', name: 'needle')])
      ..updateSearchKeywords('needle');
    final previous = model.getFilteredEvents(AppLocalizationsEn());
    model.updateEvent(EventItem(id: 'e', name: 'replacement'));
    final current = model.getFilteredEvents(AppLocalizationsEn());
    expect(current, isEmpty);
    expect(current, isNot(same(previous)));
    expect(previous.single.name, 'needle');
  });

  test('equivalent labels do not carry filtered rows across account reset', () {
    final model = ModelEvent()
      ..setEvents([EventItem(id: 'same', name: 'private-a')])
      ..updateSearchKeywords('private-a');
    final previous = model.getFilteredEvents(AppLocalizationsEn());
    model.resetForDataScope();
    model.setEvents([EventItem(id: 'same', name: 'private-b')]);
    model.updateSearchKeywords('private-a');
    expect(model.getFilteredEvents(AppLocalizationsEn()), isEmpty);
    expect(previous.single.name, 'private-a');
  });

  test('editing one record preserves the other records search index', () {
    final changed = _TextEvent('changed', DateTime(2026, 10, 1));
    final keep = _TextEvent('keep', DateTime(2026, 10, 1));
    final model = ModelEvent()
      ..setEvents([changed, keep])
      ..updateSearchKeywords('needle');
    expect(model.getFilteredEvents(loc).length, 2);
    model.updateEvent(EventItem(id: 'changed', name: 'different'));
    expect(model.getFilteredEvents(loc).single.id, 'keep');
    expect(keep.reads, 1);
  });

  test('deleting duplicate IDs preserves unrelated search text', () {
    final first = _TextEvent('duplicate', DateTime(2026, 10, 1));
    final second = _TextEvent('duplicate', DateTime(2026, 10, 2));
    final keep = _TextEvent('keep', DateTime(2026, 10, 1));
    final model = ModelEvent()
      ..setEvents([first, second, keep])
      ..updateSearchKeywords('needle');
    expect(model.getFilteredEvents(loc).length, 3);
    model.removeEvent(EventItem(id: 'duplicate', name: 'argument only'));
    expect(model.getFilteredEvents(loc).single.id, 'keep');
    expect(keep.reads, 1);
    expect(model.findEventById('duplicate'), isNull);
  });

  test('editing a mutable shared child refreshes the parent result', () {
    final child = _TextEvent('child', DateTime(2026, 10, 1));
    final parent = EventItem(id: 'parent', name: '', subEvents: [child]);
    final model = ModelEvent()
      ..setEvents([parent, child])
      ..updateSearchKeywords('needle');
    expect(model.getFilteredEvents(loc).length, 2);
    child.description = 'replacement';
    model.updateEvent(child);
    expect(model.getFilteredEvents(loc), isEmpty);
    model.updateSearchKeywords('replacement');
    expect(model.getFilteredEvents(loc).map((e) => e.id), ['parent', 'child']);
  });

  test('parent text match keeps child search text deferred', () {
    final child = _TextEvent('child', DateTime(2026, 10, 1));
    final parent = _TextEvent(
      'parent',
      DateTime(2026, 10, 1),
      children: [child],
    );
    final model = ModelEvent()
      ..setEvents([parent])
      ..updateSearchKeywords('needle');
    expect(model.getFilteredEvents(loc).single.id, 'parent');
    expect([parent.reads, child.reads], [1, 0]);
    model.updateSearchKeywords('child');
    expect(model.getFilteredEvents(loc).single.id, 'parent');
    expect([parent.reads, child.reads], [1, 1]);
  });

  test('editing invalidates both levels of the text index', () {
    final model = ModelEvent()
      ..setEvents([
        EventItem(
          id: 'e',
          name: 'before',
          subEvents: [EventItem(id: 'c', name: 'oldchild')],
        ),
      ])
      ..updateSearchKeywords('oldchild');
    expect(model.getFilteredEvents(loc).length, 1);
    model.updateEvent(
      EventItem(
        id: 'e',
        name: 'after',
        subEvents: [EventItem(id: 'c', name: 'newchild')],
      ),
    );
    expect(model.getFilteredEvents(loc), isEmpty);
    model.updateSearchKeywords('newchild');
    expect(model.getFilteredEvents(loc).single.id, 'e');
  });

  test('data scope reset cannot restore previous account indexed text', () {
    final model = ModelEvent()
      ..setEvents([EventItem(id: 'same', name: 'private-a')])
      ..updateSearchKeywords('private-a');
    expect(model.getFilteredEvents(loc).length, 1);
    model.resetForDataScope();
    model.setEvents([EventItem(id: 'same', name: 'private-b')]);
    model.updateSearchKeywords('private-a');
    expect(model.getFilteredEvents(loc), isEmpty);
    model.updateSearchKeywords('private-b');
    expect(model.getFilteredEvents(loc).length, 1);
  });

  test('locale switch updates translated search text', () {
    final chinese = AppLocalizationsZh();
    final model = ModelEvent()
      ..setEvents([EventItem(id: 'e', name: '', isFree: true)])
      ..updateSearchKeywords(chinese.free);
    expect(model.getFilteredEvents(loc), isEmpty);
    expect(model.getFilteredEvents(chinese).single.id, 'e');
    expect(model.getFilteredEvents(loc), isEmpty);
  });
  test('numeric metadata search avoids parent and child text indexing', () {
    final child = _TextEvent('child', DateTime(2026, 10, 1));
    final parent = _TextEvent(
      'parent',
      DateTime(2026, 10, 1),
      children: [child],
    );
    final model = ModelEvent()
      ..setEvents([parent])
      ..updateSearchKeywords('18y 100');
    expect(model.getFilteredEvents(loc).single.id, 'parent');
    expect([parent.reads, child.reads], [0, 0]);
  });
  test('date-only filtering never builds parent or child search text', () {
    final child = _TextEvent('child', DateTime(2026, 10, 1));
    final old = _TextEvent('old', DateTime(2026, 9, 1), children: [child]);
    final recent = _TextEvent('recent', DateTime(2026, 10, 1));
    final model = ModelEvent()
      ..setEvents([old, recent])
      ..updateStartDate(DateTime(2026, 10, 1));
    expect(model.getFilteredEvents(loc).map((event) => event.id), ['recent']);
    expect([old.reads, recent.reads, child.reads], [0, 0, 0]);
  });

  test('keyword search skips text indexing outside the date window', () {
    final old = _TextEvent('old', DateTime(2026, 9, 1));
    final recent = _TextEvent('recent', DateTime(2026, 10, 1));
    final model = ModelEvent()
      ..setEvents([old, recent])
      ..updateStartDate(DateTime(2026, 10, 1))
      ..updateSearchKeywords('needle');
    expect(model.getFilteredEvents(loc).map((event) => event.id), ['recent']);
    expect([old.reads, recent.reads], [0, 1]);
    model.updateStartDate(null);
    expect(model.getFilteredEvents(loc).length, 2);
    expect([old.reads, recent.reads], [1, 1]);
  });

  test('removed-only filtering does not index descriptions', () {
    final removed = _TextEvent('removed', DateTime(2026, 10, 1));
    final keep = _TextEvent('keep', DateTime(2026, 10, 1));
    final model = ModelEvent()
      ..setEvents([removed, keep])
      ..markRemoved('removed');
    expect(model.getFilteredEvents(loc).single.id, 'keep');
    expect([removed.reads, keep.reads], [0, 0]);
  });

  test('date bounds remain inclusive for spanning and undated events', () {
    final events = [
      EventItem(
        id: 'spanning',
        name: '',
        startDate: DateTime(2026, 9, 30),
        endDate: DateTime(2026, 10, 2),
      ),
      EventItem(id: 'end', name: '', startDate: DateTime(2026, 10, 2)),
      EventItem(id: 'after', name: '', startDate: DateTime(2026, 10, 3)),
      EventItem(id: 'undated', name: ''),
    ];
    final model = ModelEvent()
      ..setEvents(events)
      ..updateStartDate(DateTime(2026, 10, 1))
      ..updateEndDate(DateTime(2026, 10, 2));
    expect(model.getFilteredEvents(loc).map((event) => event.id), [
      'spanning',
      'end',
    ]);
  });
}
