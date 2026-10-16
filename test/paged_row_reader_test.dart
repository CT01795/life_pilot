import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/utils/paged_row_reader.dart';

void main() {
  test(
    'small first batch publishes early without truncating the logical page',
    () async {
      final data = List.generate(24, (i) => {'id': '$i'});
      final tail = Completer<List<dynamic>>();
      final calls = <(int, int)>[];
      final snapshots = <List<dynamic>>[];
      final request = readPagedRows(
        offset: 0,
        limit: 51,
        initialBatchSize: 6,
        onProgress: snapshots.add,
        fetch: (offset, limit) async {
          calls.add((offset, limit));
          if (offset == 0) return data.take(limit).toList();
          if (offset == 6) return tail.future;
          return [];
        },
      );
      await Future<void>.delayed(Duration.zero);
      expect(snapshots.single.length, 6);
      expect(calls, [(0, 6), (6, 45)]);
      tail.complete(data.skip(6).toList());
      expect(
        (await request).map((row) => row['id']),
        List.generate(24, (i) => '$i'),
      );
      expect(snapshots.map((rows) => rows.length), [6, 24]);
      expect(calls, [(0, 6), (6, 45), (24, 27)]);
    },
  );

  test(
    'small first batch still supports server caps and nonzero offsets',
    () async {
      final data = List.generate(80, (i) => {'id': '$i'});
      final calls = <(int, int)>[];
      final rows = await readPagedRows(
        offset: 10,
        limit: 51,
        initialBatchSize: 6,
        fetch: (offset, limit) async {
          calls.add((offset, limit));
          return data.skip(offset).take(limit > 20 ? 20 : limit).toList();
        },
      );
      expect(
        rows.map((row) => row['id']),
        List.generate(51, (i) => '${i + 10}'),
      );
      expect(calls, [(10, 6), (16, 45), (36, 25), (56, 5)]);
    },
  );

  test('initial batch cannot exceed the requested logical page', () async {
    final calls = <int>[];
    final rows = await readPagedRows(
      offset: 0,
      limit: 2,
      initialBatchSize: 6,
      fetch: (offset, limit) async {
        calls.add(limit);
        return List.generate(limit, (i) => {'id': '$i'});
      },
    );
    expect(rows.length, 2);
    expect(calls, [2]);
    await expectLater(
      readPagedRows(
        offset: 0,
        limit: 2,
        initialBatchSize: 0,
        fetch: (_, _) async => [],
      ),
      throwsArgumentError,
    );
  });
  test(
    'publishes first rows before waiting for the end-of-data probe',
    () async {
      final probe = Completer<List<dynamic>>();
      final snapshots = <List<dynamic>>[];
      final request = readPagedRows(
        offset: 0,
        limit: 51,
        onProgress: snapshots.add,
        fetch: (offset, limit) async => offset == 0
            ? [
                {'id': 'first'},
              ]
            : probe.future,
      );
      await Future<void>.delayed(Duration.zero);
      expect(snapshots.single.single['id'], 'first');
      expect(() => snapshots.single.clear(), throwsUnsupportedError);
      probe.complete([]);
      expect((await request).single['id'], 'first');
    },
  );

  test('progress snapshots do not grow when later batches arrive', () async {
    final snapshots = <List<dynamic>>[];
    await readPagedRows(
      offset: 0,
      limit: 3,
      onProgress: snapshots.add,
      fetch: (offset, limit) async => [
        {'id': '$offset'},
      ],
    );
    expect(snapshots.map((rows) => rows.length), [1, 2, 3]);
  });
  test('fills lookahead despite an RPC page cap', () async {
    final data = List.generate(75, (i) => {'id': '$i'});
    final calls = <(int, int)>[];
    final rows = await readPagedRows(
      offset: 0,
      limit: 51,
      fetch: (offset, limit) async {
        calls.add((offset, limit));
        return data.skip(offset).take(limit > 20 ? 20 : limit).toList();
      },
    );
    expect(rows.length, 51);
    expect(calls, [(0, 51), (20, 31), (40, 11)]);
  });
  test('last page stops when server returns no more rows', () async {
    final data = List.generate(25, (i) => {'id': '$i'});
    final rows = await readPagedRows(
      offset: 20,
      limit: 51,
      fetch: (offset, limit) async => data.skip(offset).take(limit).toList(),
    );
    expect(rows.map((row) => row['id']), ['20', '21', '22', '23', '24']);
  });
  test('ignoring offset is an error, not end-of-data', () async {
    await expectLater(
      readPagedRows(
        offset: 0,
        limit: 51,
        fetch: (offset, limit) async => [
          {'id': 'same'},
        ],
      ),
      throwsStateError,
    );
  });
  test('invalid range is rejected', () async {
    await expectLater(
      readPagedRows(offset: -1, limit: 51, fetch: (offset, limit) async => []),
      throwsArgumentError,
    );
  });
}
