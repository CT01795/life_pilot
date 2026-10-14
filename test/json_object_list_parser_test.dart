import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/pages/home/model/event/calendar_event.dart';
import 'package:life_pilot/utils/json_object_list_parser.dart';

void main() {
  test('database lists and local JSON strings produce equivalent objects', () {
    final source = [
      {'id': 'child', 'name': 'Child'},
    ];
    expect(parseJsonObjectList(source), source);
    expect(parseJsonObjectList(jsonEncode(source)), source);
  });

  test('empty, malformed and non-array inputs are safe', () {
    for (final input in [
      null,
      '',
      '  ',
      'invalid',
      '{}',
      'null',
      '42',
      42,
      {},
    ]) {
      expect(parseJsonObjectList(input), isEmpty, reason: '$input');
    }
  });

  test('mixed arrays retain object entries in their original order', () {
    expect(parseJsonObjectList('[null,1,{"id":"a"},"text",{"id":"b"}]'), [
      {'id': 'a'},
      {'id': 'b'},
    ]);
  });

  test('parsed rows do not alias the input maps', () {
    final row = <String, dynamic>{'id': 'a'};
    final result = parseJsonObjectList([row]);
    result.single['id'] = 'b';
    expect(row['id'], 'a');
  });

  test('dashboard and event models accept the same serialized sub events', () {
    final input = <String, dynamic>{
      'id': 'parent',
      'sub_events': jsonEncode([
        {
          'id': 'child',
          'name': 'Child',
          'start_date': '2026-10-14',
          'end_date': '2026-10-15',
        },
        null,
      ]),
    };
    final dashboard = CalendarEvent.fromJson(input);
    final event = EventItem.fromJson(json: input);
    expect(dashboard.subEvents.single['id'], event.subEvents.single.id);
    expect(dashboard.subEventsForDate(DateTime(2026, 10, 15)), hasLength(1));
    expect(dashboard.subEventsForDate(DateTime(2026, 10, 16)), isEmpty);
  });
}
