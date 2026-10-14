import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/utils/paged_row_reader.dart';

void main() {
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
