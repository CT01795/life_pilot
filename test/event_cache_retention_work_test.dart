import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/event/model_event_view_cache.dart';
import 'package:life_pilot/event/model_event_search_index.dart';
import 'package:life_pilot/l10n/app_localizations_en.dart';
import 'package:life_pilot/utils/const.dart';

const labels = (
  free: 'free',
  pay: 'paid',
  outdoor: 'outdoor',
  indoor: 'indoor',
);

class _TextEvent extends EventItem {
  _TextEvent(String id, String text)
    : super(id: id, name: id, description: text);
  var reads = 0;
  @override
  String get description {
    reads++;
    return super.description;
  }
}

class _UntouchedEvent extends EventItem {
  _UntouchedEvent(String id) : super(id: id, name: id);
  @override
  String get description =>
      throw StateError('Do not decode unseen descriptions');
}

void main() {
  test('empty view cache never enumerates or builds source records', () {
    Iterable<EventItem> unused() sync* {
      throw StateError('No cache to retain');
    }

    ModelEventViewCache().retainEvents(unused());
  });

  for (final keepLast in [false, true]) {
    test('view retention preserves last-duplicate-ID rule: $keepLast', () {
      final cache = ModelEventViewCache();
      final loc = AppLocalizationsEn();
      final original = EventItem(id: 'same', name: 'original');
      final replacement = EventItem(id: 'same', name: 'replacement');
      EventViewModel build(EventItem event) => cache.build(
        event: event,
        loc: loc,
        tableName: TableNames.recommendEvents,
        canDelete: false,
      );
      final first = build(original);
      cache.retainEvents(
        keepLast ? [replacement, original] : [original, replacement],
      );
      expect(identical(build(original), first), keepLast);
    });
  }

  test(
    'sparse view cache retains visible instances without decoding appended rows',
    () {
      final cache = ModelEventViewCache(), loc = AppLocalizationsEn();
      final keep = EventItem(id: 'keep', name: 'keep');
      final removed = EventItem(id: 'removed', name: 'removed');
      EventViewModel build(EventItem event) => cache.build(
        event: event,
        loc: loc,
        tableName: TableNames.recommendEvents,
        canDelete: false,
      );
      final first = build(keep), oldRemoved = build(removed);
      var visits = 0;
      Iterable<EventItem> rows() sync* {
        yield keep;
        for (var i = 0; i < 10000; i++) {
          visits++;
          yield _UntouchedEvent('$i');
        }
      }

      cache.retainEvents(rows());
      expect(visits, 10000);
      expect(build(keep), same(first));
      expect(build(removed), isNot(same(oldRemoved)));
    },
  );

  test('search retention keeps identities separate even when IDs collide', () {
    final index = ModelEventSearchIndex();
    final first = _TextEvent('same', 'first'),
        second = _TextEvent('same', 'second');
    expect(index.contains(first, 'first', labels: labels), true);
    expect(index.contains(second, 'second', labels: labels), true);
    index.retainEvents([second]);
    expect(index.contains(second, 'second', labels: labels), true);
    expect(second.reads, 1);
    expect(index.contains(first, 'first', labels: labels), true);
    expect(first.reads, 2);
  });

  test(
    'sparse search retention consumes source once without reading unseen text',
    () {
      final index = ModelEventSearchIndex();
      final keep = _TextEvent('keep', 'needle'),
          removed = _TextEvent('removed', 'old');
      index.contains(keep, 'needle', labels: labels);
      index.contains(removed, 'old', labels: labels);
      var visits = 0;
      Iterable<EventItem> rows() sync* {
        yield keep;
        for (var i = 0; i < 10000; i++) {
          visits++;
          yield _UntouchedEvent('$i');
        }
      }

      index.retainEvents(rows());
      expect(visits, 10000);
      expect(index.contains(keep, 'needle', labels: labels), true);
      expect(keep.reads, 1);
      expect(index.contains(removed, 'old', labels: labels), true);
      expect(removed.reads, 2);
    },
  );

  test('retaining an empty snapshot evicts cached text and view models', () {
    final index = ModelEventSearchIndex(), cache = ModelEventViewCache();
    final loc = AppLocalizationsEn(), event = _TextEvent('e', 'before');
    EventViewModel build() => cache.build(
      event: event,
      loc: loc,
      tableName: TableNames.recommendEvents,
      canDelete: false,
    );
    index.contains(event, 'before', labels: labels);
    final first = build();
    index.retainEvents([]);
    cache.retainEvents([]);
    event.description = 'after';
    expect(index.contains(event, 'after', labels: labels), true);
    expect(build(), isNot(same(first)));
    expect(build().description, 'after');
  });
}
