import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/event/model_event_page.dart';

List<EventItem> rows(int count) =>
    List.generate(count, (i) => EventItem(id: '$i', name: '$i'));

void main() {
  for (final size in [0, 1, 49, 50, 51, 80]) {
    test('page boundaries preserve visible rows for $size results', () {
      final source = rows(size);
      final page = ModelEventPage.fromRows(source, pageSize: 50);
      expect(page.events.length, min(size, 50));
      expect(page.hasMore, size > 50);
      expect(page.nextOffset, min(size, 50));
      expect(page.events, orderedEquals(source.take(50)));
    });
  }

  test('next offset counts consumed rows rather than unique IDs', () {
    final page = ModelEventPage.fromRows(
      List.generate(51, (_) => EventItem(id: 'same', name: '')),
      pageSize: 50,
      offset: 100,
    );
    expect(page.events.map((e) => e.id).toSet().length, 1);
    expect(page.nextOffset, 150);
    expect(page.hasMore, isTrue);
  });

  test('empty continuation retains offset and marks end', () {
    final page = ModelEventPage.fromRows([], pageSize: 50, offset: 100);
    expect(page.nextOffset, 100);
    expect(page.hasMore, isFalse);
  });

  test('trimmed page is independent of the source and lookahead row', () {
    final source = rows(51);
    final page = ModelEventPage.fromRows(source, pageSize: 50);
    page.events.sort((a, b) => b.id.compareTo(a.id));
    expect(source.map((e) => e.id), List.generate(51, (i) => '$i'));
    expect(page.events.any((e) => e.id == '50'), isFalse);
    expect(
      identical(page.events.first, source[int.parse(page.events.first.id)]),
      isTrue,
    );
  });

  test('a page without lookahead does not copy its existing list', () {
    final source = rows(12);
    final page = ModelEventPage.fromRows(source, pageSize: 50);
    expect(identical(page.events, source), isTrue);
  });

  test('invalid pagination inputs are rejected explicitly', () {
    for (final size in [0, -1]) {
      expect(
        () => ModelEventPage.fromRows([], pageSize: size),
        throwsArgumentError,
      );
    }
    expect(
      () => ModelEventPage.fromRows([], pageSize: 50, offset: -1),
      throwsArgumentError,
    );
  });

  test(
    'page interpretation matches previous slicing for generated batches',
    () {
      final random = Random(2010);
      for (var i = 0; i < 300; i++) {
        final size = random.nextInt(120);
        final pageSize = random.nextInt(80) + 1;
        final offset = random.nextInt(1000);
        final source = rows(size);
        final expected = size > pageSize
            ? source.take(pageSize).toList()
            : source;
        final page = ModelEventPage.fromRows(
          source,
          pageSize: pageSize,
          offset: offset,
        );
        expect(page.events, orderedEquals(expected));
        expect(page.hasMore, size > pageSize);
        expect(page.nextOffset, offset + expected.length);
      }
    },
  );
}
