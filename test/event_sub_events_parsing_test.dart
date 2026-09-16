import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/utils/const.dart';

void main() {
  group('EventItem sub event parsing', () {
    final child = <String, dynamic>{
      Fields.id: 'child-1',
      EventFields.name: 'Child event',
    };

    test('reads a JSON array returned by the database', () {
      final event = EventItem.fromJson(
        json: {
          Fields.id: 'parent-1',
          EventFields.subEvents: [child],
        },
      );

      expect(event.subEvents, hasLength(1));
      expect(event.subEvents.single.name, 'Child event');
    });

    test('reads a JSON string restored from local storage', () {
      final event = EventItem.fromJson(
        json: {
          Fields.id: 'parent-1',
          EventFields.subEvents: jsonEncode([child]),
        },
      );

      expect(event.subEvents, hasLength(1));
      expect(event.subEvents.single.id, 'child-1');
    });

    test('keeps malformed local data safe', () {
      final event = EventItem.fromJson(
        json: {
          Fields.id: 'parent-1',
          EventFields.subEvents: 'not-json',
        },
      );

      expect(event.subEvents, isEmpty);
    });
  });
}
