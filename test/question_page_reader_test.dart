import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/game/question_page_reader.dart';

void main() {
  List<Map<String, dynamic>> rows(int count) =>
      List.generate(count, (i) => {'id': '$i'});

  test(
    'lookahead keeps more available without including the extra row',
    () async {
      final data = rows(25);
      final calls = <(int, int)>[];
      final page = await readQuestionPage(
        offset: 0,
        limit: 20,
        fetch: (offset, limit) async {
          calls.add((offset, limit));
          return data.skip(offset).take(limit).toList();
        },
      );
      expect(page.rows, hasLength(20));
      expect(page.hasMore, isTrue);
      expect(calls, [(0, 21)]);
    },
  );

  test('capped RPC uses a one-row probe beyond a full page', () async {
    final data = rows(25);
    final calls = <(int, int)>[];
    final page = await readQuestionPage(
      offset: 0,
      limit: 20,
      fetch: (offset, limit) async {
        calls.add((offset, limit));
        return data.skip(offset).take(limit > 20 ? 20 : limit).toList();
      },
    );
    expect(page.hasMore, isTrue);
    expect(calls, [(0, 21), (20, 1)]);
  });

  test('exactly one full page hides more when the probe is empty', () async {
    final data = rows(20);
    final page = await readQuestionPage(
      offset: 0,
      limit: 20,
      fetch: (offset, limit) async => data.skip(offset).take(limit).toList(),
    );
    expect(page.hasMore, isFalse);
    expect(page.totalCount, 20);
  });

  test(
    'consecutive pages return every question once and finish at the end',
    () async {
      final data = rows(25);
      Future<List<dynamic>> fetch(int offset, int limit) async =>
          data.skip(offset).take(limit).toList();
      final first = await readQuestionPage(offset: 0, limit: 20, fetch: fetch);
      final last = await readQuestionPage(offset: 20, limit: 20, fetch: fetch);
      expect(
        [...first.rows, ...last.rows].map((row) => row['id']),
        data.map((row) => row['id']),
      );
      expect(last.hasMore, isFalse);
      expect(last.totalCount, 25);
    },
  );

  test('valid total_count metadata avoids a capped-page probe', () async {
    var calls = 0;
    final page = await readQuestionPage(
      offset: 0,
      limit: 20,
      fetch: (offset, limit) async {
        calls++;
        return rows(20).map((row) => {...row, 'total_count': '50'}).toList();
      },
    );
    expect(page.totalCount, 50);
    expect(page.hasMore, isTrue);
    expect(calls, 1);
  });

  test('empty results do not expose another page', () async {
    final page = await readQuestionPage(
      offset: 0,
      limit: 20,
      fetch: (_, _) async => [],
    );
    expect(page.rows, isEmpty);
    expect(page.hasMore, isFalse);
    expect(page.totalCount, 0);
  });
}
