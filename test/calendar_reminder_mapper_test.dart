import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/utils/enum.dart';
import 'package:life_pilot/utils/mapper.dart';

void main() {
  test('every reminder key round-trips and exposes its duration', () {
    for (final option in CalendarReminderOption.values) {
      final key = CalendarReminderMapper.toKey(reminderOption: option);
      expect(CalendarReminderMapper.fromKey(key: key), option);
      expect(
        CalendarReminderMapper.getDuration(reminderOption: option).isNegative,
        isFalse,
      );
    }
  });

  test('database arrays and local JSON preserve option order', () {
    const expected = [
      CalendarReminderOption.oneHour,
      CalendarReminderOption.twoDays,
    ];
    expect(CalendarReminderMapper.parseOptions(['1_hour', '2_days']), expected);
    expect(
      CalendarReminderMapper.parseOptions('["1_hour","2_days"]'),
      expected,
    );
  });

  test('explicit empty selections do not enable a default reminder', () {
    expect(CalendarReminderMapper.parseOptions([]), isEmpty);
    expect(CalendarReminderMapper.parseOptions('[]'), isEmpty);
  });

  test('missing or malformed serialized options use the existing default', () {
    for (final input in [null, '', 'invalid', '{}', 'null']) {
      expect(CalendarReminderMapper.parseOptions(input), [
        CalendarReminderOption.dayBefore8am,
      ]);
    }
  });

  test('unknown keys retain the existing fifteen-minute fallback', () {
    expect(
      CalendarReminderMapper.fromKey(key: 'unknown'),
      CalendarReminderOption.fifteenMin,
    );
    expect(CalendarReminderMapper.parseOptions(['unknown']), [
      CalendarReminderOption.fifteenMin,
    ]);
    expect(CalendarReminderMapper.parseOptions(42), isEmpty);
  });

  test('the event model entry point delegates with identical results', () {
    expect(EventItem.parseReminderOptions(jsonValue: '["same_day_8am"]'), [
      CalendarReminderOption.sameDay8am,
    ]);
  });
}
