import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/event/model_event_tags.dart';

List<String> previousTags(Iterable<String> parts) => parts
    .where((t) => t.isNotEmpty)
    .expand((t) => t.split(RegExp(r'[\s,，]')))
    .map((t) => t.trim())
    .where((t) => t.isNotEmpty)
    .take(3)
    .toList();

void main() {
  for (final parts in [
    <String>[],
    [''],
    [' ,，\t\n '],
    ['免費', '戶外', '展覽'],
    ['Free entry', 'Outdoor', 'Family friendly'],
    ['免費，戶外,親子 第四個'],
    ['a\tb\nc\rd'],
    ['\u00a0a\u00a0', '\u200bb\u200b', '\u3000c\u3000'],
    ['中文 日本語 한국어 English'],
    ['', 'first', '', ',second，', 'third fourth'],
  ]) {
    test('preserves splitting/trim/limit behavior: $parts', () {
      expect(ModelEventTags.firstThree(parts), previousTags(parts));
    });
  }

  test('randomized multilingual text matches the original pipeline', () {
    final random = Random(20261028);
    const atoms = [
      'a',
      '中文',
      '日本語',
      '한국어',
      ' ',
      ',',
      '，',
      '\t',
      '\n',
      '\r',
      '\u00a0',
      '\u200b',
      '\u3000',
      '',
      ':',
      '+',
      '-',
    ];
    for (var batch = 0; batch < 1000; batch++) {
      final parts = [
        for (var p = 0; p < 5; p++)
          List.generate(
            random.nextInt(30),
            (_) => atoms[random.nextInt(atoms.length)],
          ).join(),
      ];
      expect(
        ModelEventTags.firstThree(parts),
        previousTags(parts),
        reason: 'batch $batch',
      );
    }
  });

  test('does not visit remaining parts after collecting three tags', () {
    Iterable<String> parts() sync* {
      yield 'one, two，three';
      throw StateError('Unused suffix must not be visited');
    }

    expect(ModelEventTags.firstThree(parts()), ['one', 'two', 'three']);
  });

  test('long type text keeps only the first three tags', () {
    final text = 'first second third ${List.filled(10000, 'unused').join(',')}';
    expect(ModelEventTags.firstThree([text]), ['first', 'second', 'third']);
  });

  test('returned tags remain independent growable lists', () {
    final input = ['one two three four'];
    final first = ModelEventTags.firstThree(input);
    first.add('edited');
    expect(ModelEventTags.firstThree(input), ['one', 'two', 'three']);
    expect(input, ['one two three four']);
  });
}
