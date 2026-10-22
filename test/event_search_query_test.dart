import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/event/model_event_search_query.dart';
import 'package:life_pilot/event/model_event_item.dart';

bool legacyMatch(EventItem event, String text, String word) {
  if (text.contains(word)) return true;
  final range = ModelEventSearchQuery.ageRange.firstMatch(word);
  final single = ModelEventSearchQuery.ageSingle.firstMatch(word);
  final price = ModelEventSearchQuery.price.firstMatch(word);
  bool matches(EventItem item) {
    if (range != null) {
      final min = num.parse(range.group(1)!);
      final max = num.parse(range.group(2)!);
      if (!(max < (item.ageMin ?? 0) || min > (item.ageMax ?? 999))) {
        return true;
      }
    } else if (single != null) {
      final value = num.parse(single.group(1)!);
      if ((item.ageMin ?? 0) <= value && (item.ageMax ?? 999) >= value) {
        return true;
      }
    }
    if (price != null) {
      final min = num.parse(price.group(1)!);
      final upper = price.group(2);
      if (upper == null) {
        if ((item.priceMin ?? 0) <= min && (item.priceMax ?? 999999) >= min) {
          return true;
        }
      } else if (!(num.parse(upper) < (item.priceMin ?? 0) ||
          min > (item.priceMax ?? 999999))) {
        return true;
      }
    }
    return false;
  }

  return matches(event) || event.subEvents.any(matches);
}

void main() {
  test(
    'duplicate normalized words are checked once in first-occurrence order',
    () {
      final query = ModelEventSearchQuery('MUSIC music，Taipei,MUSIC TAIPEI');
      final checked = <String>[];
      expect(
        query.matchesWithText(
          EventItem(id: 'e', name: ''),
          containsText: (word) {
            checked.add(word);
            return true;
          },
        ),
        isTrue,
      );
      expect(checked, ['music', 'taipei']);
      expect(query.tokens, ['MUSIC', 'music', 'Taipei', 'MUSIC', 'TAIPEI']);
      expect(() => query.tokens.clear(), throwsUnsupportedError);
    },
  );

  test('deduplication does not collapse distinct numeric literal forms', () {
    final query = ModelEventSearchQuery(r'100 $100 100 $100');
    final checked = <String>[];
    expect(
      query.matchesWithText(
        EventItem(id: 'e', name: '', priceMin: 500, priceMax: 600),
        containsText: (word) {
          checked.add(word);
          return true;
        },
      ),
      isTrue,
    );
    expect(checked, ['100', r'$100']);
  });

  test(
    'deduplicated queries retain short-circuit AND matching on every call',
    () {
      final query = ModelEventSearchQuery('first FIRST second SECOND');
      final checked = <String>[];
      final event = EventItem(id: 'e', name: '');
      expect(
        query.matchesWithText(
          event,
          containsText: (word) {
            checked.add(word);
            return false;
          },
        ),
        isFalse,
      );
      expect(checked, ['first']);
      checked.clear();
      expect(
        query.matchesWithText(
          event,
          containsText: (word) {
            checked.add(word);
            return true;
          },
        ),
        isTrue,
      );
      expect(checked, ['first', 'second']);
    },
  );

  test('duplicate age and price conditions retain child metadata fallback', () {
    final event = EventItem(
      id: 'parent',
      name: '',
      ageMin: 30,
      ageMax: 40,
      priceMin: 500,
      priceMax: 600,
      subEvents: [
        EventItem(
          id: 'child',
          name: '',
          ageMin: 5,
          ageMax: 10,
          priceMin: 100,
          priceMax: 200,
        ),
      ],
    );
    final checked = <String>[];
    expect(
      ModelEventSearchQuery('8y 8Y 150 150').matchesWithText(
        event,
        containsText: (word) {
          checked.add(word);
          return false;
        },
      ),
      isTrue,
    );
    expect(checked, ['8y', '150']);
  });

  test('trim-only Unicode whitespace retains the original token behavior', () {
    final query = ModelEventSearchQuery('\u0085MUSIC\u0085');
    expect(
      query.matches(
        EventItem(id: 'e', name: ''),
        searchableText: () => 'music',
      ),
      isTrue,
    );
  });
  test('empty query does not request text or children', () {
    expect(ModelEventSearchQuery(' ， , ').isEmpty, isTrue);
    expect(
      ModelEventSearchQuery('').matches(
        EventItem(id: 'empty', name: ''),
        searchableText: () => throw StateError('unnecessary indexing'),
      ),
      isTrue,
    );
  });

  test('parent metadata matches without building search text', () {
    final event = EventItem(
      id: 'parent',
      name: '',
      ageMin: 5,
      ageMax: 10,
      priceMin: 100,
      priceMax: 200,
    );
    for (final query in ['5y', '10y', '4y~6y', '100', r'$200', r'$90~$110']) {
      expect(
        ModelEventSearchQuery(query).matches(
          event,
          searchableText: () => throw StateError('unnecessary indexing'),
        ),
        isTrue,
      );
    }
  });

  test('literal numeric text remains a valid fallback', () {
    final event = EventItem(
      id: 'literal',
      name: '',
      ageMin: 30,
      ageMax: 40,
      priceMin: 500,
      priceMax: 600,
    );
    expect(
      ModelEventSearchQuery(
        r'18y $100',
      ).matches(event, searchableText: () => r'title 18y $100'),
      isTrue,
    );
  });

  test('children can satisfy numeric conditions independently', () {
    final event = EventItem(
      id: 'parent',
      name: '',
      ageMin: 30,
      ageMax: 40,
      priceMin: 500,
      priceMax: 600,
      subEvents: [
        EventItem(
          id: 'child',
          name: '',
          ageMin: 5,
          ageMax: 10,
          priceMin: 100,
          priceMax: 200,
        ),
      ],
    );
    expect(
      ModelEventSearchQuery('8y 150').matches(event, searchableText: () => ''),
      isTrue,
    );
    expect(
      ModelEventSearchQuery('11y').matches(event, searchableText: () => ''),
      isFalse,
    );
  });

  test('comma spaces and case retain AND semantics', () {
    final query = ModelEventSearchQuery('MUSIC， Taipei, family');
    final event = EventItem(id: 'e', name: '');
    expect(
      query.matches(event, searchableText: () => 'music taipei family'),
      isTrue,
    );
    expect(query.matches(event, searchableText: () => 'music taipei'), isFalse);
  });

  test('query can be reused across events without caching their values', () {
    final query = ModelEventSearchQuery('18y');
    final event = EventItem(id: 'e', name: '', ageMin: 20, ageMax: 30);
    expect(query.matches(event, searchableText: () => ''), isFalse);
    expect(
      query.matches(
        EventItem(id: 'f', name: '', ageMin: 10, ageMax: 20),
        searchableText: () => '',
      ),
      isTrue,
    );
  });

  test('parsed terms preserve original matching over randomized metadata', () {
    final random = Random(1910);
    const words = [
      '5y',
      '18y',
      '3y~10y',
      '20y~5y',
      '100',
      r'$100',
      r'$50~$200',
      r'$200~$50',
      'MUSIC',
      'not-found',
      '18.5y',
      '-2',
    ];
    num? value() => random.nextInt(4) == 0 ? null : random.nextInt(500);
    EventItem item(String id) => EventItem(
      id: id,
      name: '',
      ageMin: value(),
      ageMax: value(),
      priceMin: value(),
      priceMax: value(),
    );
    for (var i = 0; i < 300; i++) {
      final event = item('e$i');
      event.subEvents = [item('child$i')];
      final text = i.isEven ? r'music 5y $100' : 'taipei family';
      for (final raw in words) {
        final word = raw.toLowerCase();
        expect(
          ModelEventSearchQuery(raw).matches(event, searchableText: () => text),
          legacyMatch(event, text, word),
          reason: '$i $raw',
        );
      }
    }
  });
}
