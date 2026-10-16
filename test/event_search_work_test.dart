import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/event/model_event.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/l10n/app_localizations_en.dart';

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
