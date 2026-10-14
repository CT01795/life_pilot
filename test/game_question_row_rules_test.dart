import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/game/game_question_row_rules.dart';

void main() {
  test('playable rows require active status and a level within the limit', () {
    expect(
      GameQuestionRowRules.isPlayableAtLevel({
        'is_active': true,
        'level': '2',
      }, 2),
      isTrue,
    );
    expect(
      GameQuestionRowRules.isPlayableAtLevel({
        'is_active': true,
        'level': 3,
      }, 2),
      isFalse,
    );
    expect(
      GameQuestionRowRules.isPlayableAtLevel({
        'is_active': false,
        'level': 1,
      }, 2),
      isFalse,
    );
    expect(
      GameQuestionRowRules.isPlayableAtLevel({
        'is_active': 'true',
        'level': 1,
      }, 2),
      isFalse,
    );
  });

  test('missing or malformed levels retain the existing level-one default', () {
    for (final row in [
      <String, dynamic>{'is_active': true},
      <String, dynamic>{'is_active': true, 'level': 'invalid'},
    ]) {
      expect(GameQuestionRowRules.isPlayableAtLevel(row, 1), isTrue);
      expect(GameQuestionRowRules.isPlayableAtLevel(row, 0), isFalse);
    }
  });

  test('playable translation and word-search rows enforce source groups', () {
    final row = <String, dynamic>{
      'is_active': true,
      'level': 1,
      'group': '日翻中句子',
    };
    expect(
      GameQuestionRowRules.isPlayableAtLevel(
        row,
        1,
        gameName: 'Translation (CH-JP)',
      ),
      isTrue,
    );
    expect(
      GameQuestionRowRules.isPlayableAtLevel(
        row,
        1,
        gameName: 'Translation (CH-EN)',
      ),
      isFalse,
    );
    expect(
      GameQuestionRowRules.isPlayableAtLevel(
        row,
        1,
        gameName: 'Word Searching',
      ),
      isFalse,
    );
    row['group'] = '英翻中Word';
    expect(
      GameQuestionRowRules.isPlayableAtLevel(
        row,
        1,
        gameName: 'Word Searching',
      ),
      isTrue,
    );
  });

  test('callers without a group constraint preserve all active groups', () {
    expect(
      GameQuestionRowRules.isPlayableAtLevel({
        'is_active': true,
        'level': 1,
        'group': 'custom',
      }, 1),
      isTrue,
    );
  });

  final rows = <Map<String, dynamic>>[
    {
      'id': 'q1',
      'question': 'Hello_World',
      'answer': '你好 世界',
      'group': 'English',
    },
  ];

  test('duplicate keys ignore case whitespace and underscores', () {
    expect(
      GameQuestionRowRules.duplicateKey('  HELLO_\nWorld\t'),
      'helloworld',
    );
    expect(GameQuestionRowRules.duplicateKey(null), '');
    expect(GameQuestionRowRules.duplicateKey('hello-world'), 'hello-world');
  });

  test('duplicate detection compares both texts within the same group', () {
    expect(
      GameQuestionRowRules.hasDuplicateQuestion(
        rows,
        question: 'hello world',
        answer: '你好世界',
        group: ' english ',
      ),
      isTrue,
    );
    expect(
      GameQuestionRowRules.hasDuplicateQuestion(
        rows,
        question: 'hello world',
        answer: 'different',
        group: 'English',
      ),
      isFalse,
    );
    expect(
      GameQuestionRowRules.hasDuplicateQuestion(
        rows,
        question: 'hello world',
        answer: '你好世界',
        group: 'Japanese',
      ),
      isFalse,
    );
  });

  test('editing excludes the current question but not other duplicates', () {
    expect(
      GameQuestionRowRules.hasDuplicateQuestion(
        rows,
        question: 'hello world',
        answer: '你好世界',
        group: 'English',
        excludingId: 'q1',
      ),
      isFalse,
    );
    expect(
      GameQuestionRowRules.hasDuplicateQuestion(
        [
          ...rows,
          {...rows.first, 'id': 'q2'},
        ],
        question: 'hello world',
        answer: '你好世界',
        group: 'English',
        excludingId: 'q1',
      ),
      isTrue,
    );
  });

  test('empty question banks have no duplicates', () {
    expect(
      GameQuestionRowRules.hasDuplicateQuestion(
        [],
        question: '',
        answer: '',
        group: '',
      ),
      isFalse,
    );
  });

  test(
    'status filtering preserves strict boolean and unknown-status behavior',
    () {
      for (final value in [true, false, null, 'true']) {
        expect(GameQuestionRowRules.matchesStatus(value, 'all'), isTrue);
        expect(
          GameQuestionRowRules.matchesStatus(value, 'active'),
          value == true,
        );
        expect(
          GameQuestionRowRules.matchesStatus(value, 'inactive'),
          value != true,
        );
        expect(GameQuestionRowRules.matchesStatus(value, 'unknown'), isFalse);
      }
    },
  );
}
