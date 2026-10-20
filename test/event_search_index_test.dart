import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/event/model_event_search_index.dart';

const labels = (
  free: 'free',
  pay: 'paid',
  outdoor: 'outdoor',
  indoor: 'indoor',
);

class _CountedEvent extends EventItem {
  _CountedEvent(
    String id,
    String description, {
    List<EventItem> children = const [],
  }) : super(id: id, name: id, description: description, subEvents: children);

  int reads = 0;

  @override
  String get description {
    reads++;
    return super.description;
  }
}

String legacyText(EventItem event, EventSearchLabels labels) {
  List<String> fields(EventItem e) => [
    e.city,
    e.location,
    e.name,
    e.type,
    e.description,
    e.unit,
    if (e.isFree != null) e.isFree! ? labels.free : labels.pay,
    if (e.isOutdoor != null) e.isOutdoor! ? labels.outdoor : labels.indoor,
  ];
  return [
    ...fields(event),
    for (final child in event.subEvents) ...fields(child),
  ].join('\n').toLowerCase();
}

void main() {
  test('retaining unchanged rows preserves deferred child text', () {
    final child = _CountedEvent('child', 'needle');
    final parent = _CountedEvent('parent', 'other', children: [child]);
    final index = ModelEventSearchIndex();
    expect(index.contains(parent, 'needle', labels: labels), true);
    index.retainEvents([parent, _CountedEvent('new', 'new')]);
    expect(index.contains(parent, 'needle', labels: labels), true);
    expect([parent.reads, child.reads], [1, 1]);
  });

  test(
    'retention releases removed objects and does not equate matching IDs',
    () {
      final old = _CountedEvent('same', 'before');
      final replacement = _CountedEvent('same', 'after');
      final index = ModelEventSearchIndex();
      index.contains(old, 'before', labels: labels);
      index.retainEvents([replacement]);
      expect(index.contains(replacement, 'before', labels: labels), false);
      expect(index.contains(replacement, 'after', labels: labels), true);
      index.contains(old, 'before', labels: labels);
      expect(old.reads, 2);
      index.retainEvents([]);
      index.contains(replacement, 'after', labels: labels);
      expect(replacement.reads, 2);
    },
  );

  test('retention does not force deferred child indexing', () {
    final child = _CountedEvent('child', 'child');
    final parent = _CountedEvent('parent', 'needle', children: [child]);
    final index = ModelEventSearchIndex();
    index.contains(parent, 'needle', labels: labels);
    index.retainEvents([parent]);
    expect([parent.reads, child.reads], [1, 0]);
    child.description = 'changed';
    index.invalidate([parent]);
    expect(index.contains(parent, 'changed', labels: labels), true);
  });

  test('targeted invalidation preserves unrelated indexed text', () {
    final changed = _CountedEvent('changed', 'before');
    final keep = _CountedEvent('keep', 'stable');
    final index = ModelEventSearchIndex();
    expect(index.contains(changed, 'before', labels: labels), isTrue);
    expect(index.contains(keep, 'stable', labels: labels), isTrue);
    changed.description = 'after';
    index.invalidate([changed]);
    expect(index.contains(changed, 'before', labels: labels), isFalse);
    expect(index.contains(changed, 'after', labels: labels), isTrue);
    expect(index.contains(keep, 'stable', labels: labels), isTrue);
    expect([changed.reads, keep.reads], [2, 1]);
  });

  test('changed shared child also invalidates its cached parent', () {
    final child = _CountedEvent('child', 'before');
    final parent = _CountedEvent('parent', 'parent text', children: [child]);
    final index = ModelEventSearchIndex();
    expect(index.contains(parent, 'before', labels: labels), isTrue);
    child.description = 'after';
    index.invalidate([child]);
    expect(index.contains(parent, 'before', labels: labels), isFalse);
    expect(index.contains(parent, 'after', labels: labels), isTrue);
    expect([parent.reads, child.reads], [2, 2]);
  });

  test(
    'invalidation does not decode previously deferred child descriptions',
    () {
      final child = _CountedEvent('child', 'before');
      final parent = _CountedEvent('parent', 'match', children: [child]);
      final index = ModelEventSearchIndex();
      expect(index.contains(parent, 'match', labels: labels), isTrue);
      child.description = 'after';
      index.invalidate([child]);
      expect([parent.reads, child.reads], [1, 0]);
      expect(index.contains(parent, 'after', labels: labels), isTrue);
      expect([parent.reads, child.reads], [1, 1]);
    },
  );

  test('same-ID independent instances are invalidated by identity only', () {
    final first = _CountedEvent('same', 'first');
    final second = _CountedEvent('same', 'second');
    final index = ModelEventSearchIndex();
    index.contains(first, 'first', labels: labels);
    index.contains(second, 'second', labels: labels);
    index.invalidate([first]);
    expect(index.contains(second, 'second', labels: labels), isTrue);
    expect(second.reads, 1);
  });

  test('empty invalidation keeps cached parent and children', () {
    final child = _CountedEvent('child', 'child match');
    final parent = _CountedEvent('parent', 'parent text', children: [child]);
    final index = ModelEventSearchIndex();
    index.contains(parent, 'child match', labels: labels);
    index.invalidate([]);
    expect(index.contains(parent, 'child match', labels: labels), isTrue);
    expect([parent.reads, child.reads], [1, 1]);
  });

  test('parent match never reads child descriptions', () {
    final child = _CountedEvent('child', 'only child');
    final parent = _CountedEvent('parent', 'music', children: [child]);
    final index = ModelEventSearchIndex();
    expect(index.contains(parent, 'music', labels: labels), isTrue);
    expect([parent.reads, child.reads], [1, 0]);
    expect(index.contains(parent, 'parent', labels: labels), isTrue);
    expect([parent.reads, child.reads], [1, 0]);
  });

  test('children are indexed only once when parent does not match', () {
    final child = _CountedEvent('child', 'music park');
    final parent = _CountedEvent('parent', 'other', children: [child]);
    final index = ModelEventSearchIndex();
    expect(index.contains(parent, 'music', labels: labels), isTrue);
    expect(index.contains(parent, 'park', labels: labels), isTrue);
    expect(index.contains(parent, 'missing', labels: labels), isFalse);
    expect([parent.reads, child.reads], [1, 1]);
  });

  test('changed translated labels rebuild parent and children', () {
    final parent = EventItem(
      id: 'e',
      name: '',
      isFree: true,
      subEvents: [EventItem(id: 'c', name: '', isOutdoor: true)],
    );
    final index = ModelEventSearchIndex();
    expect(index.contains(parent, 'free', labels: labels), isTrue);
    expect(index.contains(parent, 'outdoor', labels: labels), isTrue);
    const chinese = (free: '免費', pay: '付費', outdoor: '戶外', indoor: '室內');
    expect(index.contains(parent, '免費', labels: chinese), isTrue);
    expect(index.contains(parent, '戶外', labels: chinese), isTrue);
    expect(index.contains(parent, 'free', labels: chinese), isFalse);
  });

  test('explicit invalidation refreshes mutable content and children', () {
    final parent = EventItem(
      id: 'e',
      name: 'before',
      subEvents: [EventItem(id: 'c', name: 'oldchild')],
    );
    final index = ModelEventSearchIndex();
    expect(index.contains(parent, 'oldchild', labels: labels), isTrue);
    parent.name = 'after';
    parent.subEvents = [EventItem(id: 'c2', name: 'newchild')];
    index.clear();
    expect(index.contains(parent, 'before', labels: labels), isFalse);
    expect(index.contains(parent, 'after', labels: labels), isTrue);
    expect(index.contains(parent, 'newchild', labels: labels), isTrue);
    expect(index.contains(parent, 'oldchild', labels: labels), isFalse);
  });

  test('same ID with a new event instance never reuses old text', () {
    final index = ModelEventSearchIndex();
    expect(
      index.contains(
        EventItem(id: 'same', name: 'old'),
        'old',
        labels: labels,
      ),
      isTrue,
    );
    expect(
      index.contains(
        EventItem(id: 'same', name: 'new'),
        'old',
        labels: labels,
      ),
      isFalse,
    );
  });

  test('no-child misses are cached without rebuilding parent', () {
    final event = _CountedEvent('e', 'plain');
    final index = ModelEventSearchIndex();
    for (final word in ['one', 'two', 'three']) {
      expect(index.contains(event, word, labels: labels), isFalse);
    }
    expect(event.reads, 1);
  });

  test('separate indexes preserve literal results for generated fields', () {
    final random = Random(1920);
    const values = ['MUSIC', 'TaIPEI', '免費', '18y', r'$100', '', 'indoor'];
    String value() => values[random.nextInt(values.length)];
    EventItem item(String id) => EventItem(
      id: id,
      name: value(),
      city: value(),
      location: value(),
      description: value(),
      type: value(),
      unit: value(),
      isFree: random.nextBool(),
      isOutdoor: random.nextBool(),
    );
    final index = ModelEventSearchIndex();
    for (var i = 0; i < 200; i++) {
      final event = item('$i')..subEvents = [item('c$i'), item('d$i')];
      final original = legacyText(event, labels);
      for (final word in [...values.where((v) => v.isNotEmpty), 'missing']) {
        expect(
          index.contains(event, word.toLowerCase(), labels: labels),
          original.contains(word.toLowerCase()),
          reason: '$i $word',
        );
      }
    }
  });
}
