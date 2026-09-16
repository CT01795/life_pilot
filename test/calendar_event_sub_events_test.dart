import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/pages/home/model/event/calendar_event.dart';
import 'package:life_pilot/utils/const.dart';

void main() {
  test('dashboard calendar event keeps sub events for memory creation', () {
    final child = <String, dynamic>{
      Fields.id: 'child-1',
      EventFields.name: 'Child event',
    };

    final event = CalendarEvent.fromJson({
      Fields.id: 'parent-1',
      EventFields.name: 'Parent event',
      EventFields.subEvents: jsonEncode([child]),
    });

    expect(event.subEvents, hasLength(1));
    expect(event.subEvents.single[Fields.id], 'child-1');
    expect(event.toJson()[EventFields.subEvents], event.subEvents);
  });

  test('dashboard memory keeps only sub-events on selected day', () {
    final event = CalendarEvent.fromJson({
      Fields.id: 'master',
      EventFields.name: 'Master event',
      EventFields.subEvents: [
        {Fields.id: 'first', EventFields.startDate: '2026-09-15T00:00:00.000Z'},
        {
          Fields.id: 'selected',
          EventFields.startDate: '2026-09-16T00:00:00.000Z',
        },
        {
          Fields.id: 'spanning',
          EventFields.startDate: '2026-09-15T00:00:00.000Z',
          EventFields.endDate: '2026-09-17T00:00:00.000Z',
        },
      ],
    });

    final selected = event.subEventsForDate(DateTime(2026, 9, 16));

    expect(selected.map((item) => item[Fields.id]), ['selected', 'spanning']);
  });
}
