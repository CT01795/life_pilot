import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/utils/lazy_mapped_list.dart';

void main() {
  test('length and emptiness do not build any mapped values', () {
    var builds = 0;
    final list = LazyMappedList(List.generate(1000, (i) => i), (int value) {
      builds++;
      return '$value';
    });
    expect(list.length, 1000);
    expect(list.isNotEmpty, true);
    expect(builds, 0);
    expect(list.take(3), ['0', '1', '2']);
    expect(builds, 3);
    expect(list[1], '1');
    expect(builds, 3);
  });

  test('captures source membership and retains order', () {
    final source = [3, 1, 2];
    final list = LazyMappedList(source, (int value) => value * 2);
    source.clear();
    expect(list.toList(), [6, 2, 4]);
  });

  test('nullable results are cached too', () {
    var builds = 0;
    final list = LazyMappedList<int, String?>([1], (_) {
      builds++;
      return null;
    });
    expect(list[0], null);
    expect(list[0], null);
    expect(builds, 1);
  });

  test('failed mapping can be retried without corrupting cache', () {
    var builds = 0;
    final list = LazyMappedList([1], (int value) {
      if (++builds == 1) throw StateError('retry');
      return value;
    });
    expect(() => list[0], throwsStateError);
    expect(list[0], 1);
    expect(builds, 2);
  });

  test('rejects writes and out of range reads', () {
    final list = LazyMappedList([1], (int value) => value);
    expect(() => list[0] = 2, throwsUnsupportedError);
    expect(() => list.length = 2, throwsUnsupportedError);
    expect(() => list[-1], throwsRangeError);
    expect(() => list[1], throwsRangeError);
  });
}
