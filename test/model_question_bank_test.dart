import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/game/model_question_bank.dart';

void main() {
  test('question mapping selects the correct cloud or local group field', () {
    final row = <String, dynamic>{
      'id': 'q1',
      'question': 'Hello',
      'answer': '你好',
      'question_group': 'cloud',
      'group': 'local',
      'level': '2',
      'is_active': true,
      'options': 'A,B',
    };
    final cloud = MyGameQuestion.fromJson(row);
    final local = MyGameQuestion.fromJson(row, groupField: 'group');
    expect(cloud.group, 'cloud');
    expect(local.group, 'local');
    expect(local.id, cloud.id);
    expect(local.question, 'Hello');
    expect(local.answer, '你好');
    expect(local.level, 2);
    expect(local.isActive, isTrue);
    expect(local.options, 'A,B');
  });

  test('missing question fields preserve existing defaults', () {
    final question = MyGameQuestion.fromJson({});
    expect(question.level, 1);
    expect(question.options, isNull);
    expect(question.isActive, isFalse);
    expect(question.question, '');
    expect(question.group, '');
  });

  test('social choice mapping handles numeric text and missing fields', () {
    final choice = MySocialChoice.fromJson({
      'option_text': 'Answer',
      'score': '10',
      'feedback': 'Feedback',
      'is_best': true,
    });
    expect(choice.text, 'Answer');
    expect(choice.score, 10);
    expect(choice.feedback, 'Feedback');
    expect(choice.isBest, isTrue);
    expect(MySocialChoice.fromJson({}).score, 0);
  });

  test('cloud choices sort by score while local order is preserved', () {
    final choices = [
      {'option_text': 'First', 'score': 1},
      {'option_text': 'Second', 'score': 10},
    ];
    final row = <String, dynamic>{'id': 's1', 'choices': choices};
    final local = MySocialQuestion.fromJson(row);
    final cloud = MySocialQuestion.fromJson(row, sortChoicesByScore: true);
    expect(local.choices.map((c) => c.text), ['First', 'Second']);
    expect(cloud.choices.map((c) => c.text), ['Second', 'First']);
    expect(choices.first['option_text'], 'First');
  });

  test('missing social choices and category preserve defaults', () {
    final question = MySocialQuestion.fromJson({});
    expect(question.choices, isEmpty);
    expect(question.category, 'social');
    expect(question.isActive, isFalse);
  });
}
