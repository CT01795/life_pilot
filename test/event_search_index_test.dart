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
  const translations = <EventSearchLabels>[
    labels,
    (free: '免費', pay: '付費', outdoor: '戶外', indoor: '室內'),
    (free: '無料', pay: '有料', outdoor: '屋外', indoor: '屋内'),
    (free: '무료', pay: '유료', outdoor: '야외', indoor: '실내'),
  ];

  test(
    'language changes reuse parent descriptions and compare current labels',
    () {
      final row = _CountedEvent('e', 'literal')
        ..isFree = true
        ..isOutdoor = false;
      final index = ModelEventSearchIndex();
      for (final current in translations) {
        expect(index.contains(row, 'literal', labels: current), isTrue);
        expect(
          index.contains(row, current.free.toLowerCase(), labels: current),
          isTrue,
        );
        expect(
          index.contains(row, current.indoor.toLowerCase(), labels: current),
          isTrue,
        );
        expect(
          index.contains(row, current.pay.toLowerCase(), labels: current),
          isFalse,
        );
        expect(
          index.contains(row, current.outdoor.toLowerCase(), labels: current),
          isFalse,
        );
      }
      expect(row.reads, 1);
    },
  );

  test(
    'language changes preserve prepared children and leave later children lazy',
    () {
      final first = _CountedEvent('first', 'plain')..isFree = true;
      final later = _CountedEvent('later', 'plain')..isOutdoor = false;
      final parent = _CountedEvent('parent', 'plain', children: [first, later]);
      final index = ModelEventSearchIndex();
      expect(index.contains(parent, 'free', labels: labels), isTrue);
      expect([parent.reads, first.reads, later.reads], [1, 1, 0]);
      expect(index.contains(parent, '免費', labels: translations[1]), isTrue);
      expect([parent.reads, first.reads, later.reads], [1, 1, 0]);
      expect(index.contains(parent, '室內', labels: translations[1]), isTrue);
      expect([parent.reads, first.reads, later.reads], [1, 1, 1]);
      expect(index.contains(parent, '무료', labels: translations[3]), isTrue);
      expect([parent.reads, first.reads, later.reads], [1, 1, 1]);
    },
  );

  test(
    'literal words remain searchable independently of translated labels',
    () {
      final row = _CountedEvent('e', 'FREE OUTDOOR')
        ..isFree = false
        ..isOutdoor = false;
      final index = ModelEventSearchIndex();
      expect(index.contains(row, 'free', labels: translations[1]), isTrue);
      expect(index.contains(row, 'outdoor', labels: translations[1]), isTrue);
      expect(index.contains(row, '付費', labels: translations[1]), isTrue);
      expect(index.contains(row, '免費', labels: translations[1]), isFalse);
      expect(row.reads, 1);
    },
  );

  test('metadata edits still invalidate text and translated flag matches', () {
    final row = _CountedEvent('e', 'before')
      ..isFree = true
      ..isOutdoor = true;
    final index = ModelEventSearchIndex();
    expect(index.contains(row, 'free', labels: labels), isTrue);
    row.isFree = false;
    row.isOutdoor = false;
    row.description = 'after';
    index.invalidate([row]);
    expect(index.contains(row, '免費', labels: translations[1]), isFalse);
    expect(index.contains(row, '付費', labels: translations[1]), isTrue);
    expect(index.contains(row, '室內', labels: translations[1]), isTrue);
    expect(index.contains(row, 'after', labels: translations[1]), isTrue);
    expect(index.contains(row, 'before', labels: labels), isFalse);
    expect(row.reads, 2);
  });

  test(
    'a shared child remains indexed once across parents and language changes',
    () {
      final child = _CountedEvent('child', 'plain')..isFree = true;
      final a = _CountedEvent('a', 'plain', children: [child]);
      final b = _CountedEvent('b', 'plain', children: [child]);
      final index = ModelEventSearchIndex();
      expect(index.contains(a, 'free', labels: labels), isTrue);
      expect(index.contains(b, '免費', labels: translations[1]), isTrue);
      expect(index.contains(a, '無料', labels: translations[2]), isTrue);
      expect(child.reads, 1);
      expect([a.reads, b.reads], [1, 1]);
    },
  );

  test('explicit clear discards text and normalizes fresh label values', () {
    final row = _CountedEvent('e', 'before')..isFree = true;
    final index = ModelEventSearchIndex();
    expect(index.contains(row, 'free', labels: labels), isTrue);
    index.clear();
    row.description = 'after';
    const replacement = (
      free: 'CoMpliMeNtary',
      pay: 'PAY',
      outdoor: 'OUT',
      indoor: 'IN',
    );
    expect(index.contains(row, 'complimentary', labels: replacement), isTrue);
    expect(index.contains(row, 'after', labels: replacement), isTrue);
    expect(index.contains(row, 'before', labels: replacement), isFalse);
    expect(row.reads, 2);
  });

  test(
    'all nullable flag combinations match legacy text across four languages',
    () {
      final index = ModelEventSearchIndex();
      for (final free in <bool?>[null, false, true]) {
        for (final outdoor in <bool?>[null, false, true]) {
          final row = EventItem(
            id: 'e',
            name: 'Literal',
            isFree: free,
            isOutdoor: outdoor,
          );
          for (final current in translations) {
            final expected = legacyText(row, current);
            for (final word in [
              'literal',
              'missing',
              current.free,
              current.pay,
              current.outdoor,
              current.indoor,
            ]) {
              expect(
                index.contains(row, word.toLowerCase(), labels: current),
                expected.contains(word.toLowerCase()),
                reason: '$free $outdoor $word',
              );
            }
          }
        }
      }
    },
  );

  for (final keepUnrelated in [false, true]) {
    test(
      'orphan child base text is pruned without parent entries ($keepUnrelated)',
      () {
        final child = _CountedEvent('child', 'oldneedle');
        final parent = _CountedEvent('parent', 'plain', children: [child]);
        final index = ModelEventSearchIndex();
        expect(index.contains(parent, 'oldneedle', labels: labels), isTrue);
        expect(child.reads, 1);
        // Only the child's base text remains; it has no full search entry yet.
        index.retainEvents([child]);
        index.retainEvents(keepUnrelated ? [EventItem(id: 'other')] : []);
        child.description = 'newneedle';
        expect(index.contains(child, 'newneedle', labels: labels), isTrue);
        expect(child.reads, 2);
      },
    );
  }
  test(
    'still-active child base text is reused after its parent is removed',
    () {
      final child = _CountedEvent('child', 'needle');
      final parent = _CountedEvent('parent', 'plain', children: [child]);
      final index = ModelEventSearchIndex();
      index.contains(parent, 'needle', labels: labels);
      index.retainEvents([child]);
      index.retainEvents([child]);
      expect(index.contains(child, 'needle', labels: labels), isTrue);
      expect(child.reads, 1);
    },
  );

  test('early child match defers later descriptions until needed', () {
    final children = [
      _CountedEvent('first', 'needle'),
      _CountedEvent('second', 'park'),
      _CountedEvent('third', 'museum'),
    ];
    final parent = _CountedEvent('parent', 'plain', children: children);
    final index = ModelEventSearchIndex();
    expect(index.contains(parent, 'needle', labels: labels), isTrue);
    expect(children.map((child) => child.reads), [1, 0, 0]);
    expect(index.contains(parent, 'needle', labels: labels), isTrue);
    expect(children.map((child) => child.reads), [1, 0, 0]);
    expect(index.contains(parent, 'park', labels: labels), isTrue);
    expect(children.map((child) => child.reads), [1, 1, 0]);
    expect(index.contains(parent, 'missing', labels: labels), isFalse);
    expect(children.map((child) => child.reads), [1, 1, 1]);
    expect(index.contains(parent, 'museum', labels: labels), isTrue);
    expect(children.map((child) => child.reads), [1, 1, 1]);
  });

  test('editing an unindexed child invalidates its partial parent index', () {
    final first = _CountedEvent('first', 'needle');
    final later = _CountedEvent('later', 'before');
    final parent = _CountedEvent('parent', 'plain', children: [first, later]);
    final index = ModelEventSearchIndex();
    expect(index.contains(parent, 'needle', labels: labels), isTrue);
    expect(later.reads, 0);
    later.description = 'after';
    index.invalidate([later]);
    expect(index.contains(parent, 'after', labels: labels), isTrue);
    expect(index.contains(parent, 'before', labels: labels), isFalse);
    expect(later.reads, 1);
  });

  test('progressive retention preserves a partially prepared child index', () {
    final first = _CountedEvent('first', 'needle');
    final later = _CountedEvent('later', 'park');
    final parent = _CountedEvent('parent', 'plain', children: [first, later]);
    final index = ModelEventSearchIndex();
    index.contains(parent, 'needle', labels: labels);
    index.retainEvents([parent]);
    expect(index.contains(parent, 'needle', labels: labels), isTrue);
    expect([first.reads, later.reads], [1, 0]);
    expect(index.contains(parent, 'park', labels: labels), isTrue);
    expect([first.reads, later.reads], [1, 1]);
  });

  test(
    'locale changes apply current labels to partially prepared child text',
    () {
      final first = EventItem(id: 'first', name: '', isFree: true);
      final later = EventItem(id: 'later', name: '', isOutdoor: true);
      final parent = EventItem(
        id: 'parent',
        name: '',
        subEvents: [first, later],
      );
      final index = ModelEventSearchIndex();
      expect(index.contains(parent, 'free', labels: labels), isTrue);
      const chinese = (free: '免費', pay: '付費', outdoor: '戶外', indoor: '室內');
      expect(index.contains(parent, '戶外', labels: chinese), isTrue);
      expect(index.contains(parent, 'free', labels: chinese), isFalse);
      expect(index.contains(parent, '免費', labels: chinese), isTrue);
    },
  );

  test(
    'shared child text is prepared once across multiple parent searches',
    () {
      final child = _CountedEvent('shared', 'needle');
      final first = _CountedEvent('first', 'plain', children: [child]);
      final second = _CountedEvent('second', 'plain', children: [child]);
      final index = ModelEventSearchIndex();
      expect(index.contains(first, 'needle', labels: labels), isTrue);
      expect(index.contains(second, 'needle', labels: labels), isTrue);
      expect(child.reads, 1);
    },
  );
  test('an event used both as a parent row and a child reuses base text', () {
    final child = _CountedEvent('shared', 'needle');
    final parent = _CountedEvent('parent', 'plain', children: [child]);
    final index = ModelEventSearchIndex();
    expect(index.contains(child, 'needle', labels: labels), isTrue);
    expect(index.contains(parent, 'needle', labels: labels), isTrue);
    expect(child.reads, 1);
  });
  test('parent invalidation cannot reuse stale shared child text', () {
    final child = _CountedEvent('shared', 'before');
    final parent = _CountedEvent('parent', 'plain', children: [child]);
    final index = ModelEventSearchIndex();
    index.contains(child, 'before', labels: labels);
    child.description = 'after';
    index.invalidate([parent]);
    expect(index.contains(parent, 'after', labels: labels), isTrue);
    expect(child.reads, 2);
  });
  test('child edits invalidate both parents and rebuild shared text once', () {
    final child = _CountedEvent('shared', 'before');
    final first = _CountedEvent('first', 'plain', children: [child]);
    final second = _CountedEvent('second', 'plain', children: [child]);
    final index = ModelEventSearchIndex();
    index.contains(first, 'before', labels: labels);
    index.contains(second, 'before', labels: labels);
    child.description = 'after';
    index.invalidate([child]);
    expect(index.contains(first, 'before', labels: labels), isFalse);
    expect(index.contains(second, 'after', labels: labels), isTrue);
    expect(child.reads, 2);
  });
  test('different objects with matching IDs never share child text', () {
    final firstChild = _CountedEvent('same', 'first');
    final secondChild = _CountedEvent('same', 'second');
    final index = ModelEventSearchIndex();
    final parent = _CountedEvent(
      'parent',
      'plain',
      children: [firstChild, secondChild],
    );
    expect(index.contains(parent, 'first', labels: labels), isTrue);
    expect(index.contains(parent, 'second', labels: labels), isTrue);
    expect([firstChild.reads, secondChild.reads], [1, 1]);
  });
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
