import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/event/model_event.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/l10n/app_localizations_en.dart';
import 'package:life_pilot/l10n/app_localizations_zh.dart';

class _CountedEvent extends EventItem {
  _CountedEvent(
    String id, {
    String text = 'needle',
    List<EventItem> children = const [],
  }) : super(
         id: id,
         name: id,
         description: text,
         subEvents: children,
         startDate: DateTime(2026, 10, 19),
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
  for (final memory in [false, true]) {
    group(memory ? 'memory append' : 'recommended append', () {
      late ModelEvent model;
      void append(List<EventItem> rows) {
        if (memory) {
          model.appendMemoryEvents(rows);
        } else {
          model.appendEvents(rows);
        }
      }

      setUp(() => model = ModelEvent());

      test('existing search text is reused and new rows become searchable', () {
        final existing = _CountedEvent('existing');
        final added = _CountedEvent('added');
        model
          ..setEvents([existing])
          ..updateSearchKeywords('needle');
        expect(model.getFilteredEvents(loc), [existing]);
        append([added]);
        expect(
          model.getFilteredEvents(loc),
          unorderedEquals([existing, added]),
        );
        expect([existing.reads, added.reads], [1, 1]);
      });

      test('cached child text is retained after another page', () {
        final child = _CountedEvent('child');
        final parent = _CountedEvent(
          'parent',
          text: 'other',
          children: [child],
        );
        model
          ..setEvents([parent])
          ..updateSearchKeywords('needle');
        expect(model.getFilteredEvents(loc), [parent]);
        append([_CountedEvent('new')]);
        expect(model.getFilteredEvents(loc).length, 2);
        expect([parent.reads, child.reads], [1, 1]);
      });

      test('appending does not decode deferred children', () {
        final child = _CountedEvent('child');
        final parent = _CountedEvent('parent', children: [child]);
        model
          ..setEvents([parent])
          ..updateSearchKeywords('needle');
        model.getFilteredEvents(loc);
        append([_CountedEvent('new')]);
        model.getFilteredEvents(loc);
        expect([parent.reads, child.reads], [1, 0]);
      });

      test('duplicate-only and empty pages preserve indexed text', () {
        final existing = _CountedEvent('existing');
        final duplicate = _CountedEvent('existing', text: 'discarded');
        model
          ..setEvents([existing])
          ..updateSearchKeywords('needle');
        model.getFilteredEvents(loc);
        append([duplicate, duplicate]);
        append([]);
        expect(model.getFilteredEvents(loc), [existing]);
        expect([existing.reads, duplicate.reads], [1, 0]);
      });

      test('same-page duplicate IDs keep the first new row', () {
        final first = _CountedEvent('new');
        final duplicate = _CountedEvent('new', text: 'discarded');
        append([first, duplicate]);
        model.updateSearchKeywords('needle');
        expect(model.getFilteredEvents(loc), [first]);
        expect(model.findEventById('new'), same(first));
        expect(duplicate.reads, 0);
      });

      test('an explicit edit still invalidates appended search text', () {
        final existing = _CountedEvent('existing');
        model
          ..setEvents([existing])
          ..updateSearchKeywords('needle');
        model.getFilteredEvents(loc);
        append([_CountedEvent('new')]);
        model.getFilteredEvents(loc);
        existing.description = 'changed';
        model.updateEvent(existing);
        expect(model.getFilteredEvents(loc).single.id, 'new');
        model.updateSearchKeywords('changed');
        expect(model.getFilteredEvents(loc), [existing]);
        expect(existing.reads, 2);
      });

      test('language changes still rebuild localized search labels', () {
        final existing = _CountedEvent('existing')..isFree = true;
        model
          ..setEvents([existing])
          ..updateSearchKeywords('free');
        expect(model.getFilteredEvents(loc), [existing]);
        append([_CountedEvent('new')..isFree = false]);
        model.getFilteredEvents(loc);
        expect(model.getFilteredEvents(AppLocalizationsZh()), isEmpty);
        model.updateSearchKeywords('免費');
        expect(model.getFilteredEvents(AppLocalizationsZh()), [existing]);
      });

      test('data-scope reset does not reuse old appended rows', () {
        append([_CountedEvent('same')]);
        model.updateSearchKeywords('needle');
        model.getFilteredEvents(loc);
        model.resetForDataScope();
        append([_CountedEvent('same', text: 'private-other')]);
        model.updateSearchKeywords('needle');
        expect(model.getFilteredEvents(loc), isEmpty);
      });
    });
  }
}
