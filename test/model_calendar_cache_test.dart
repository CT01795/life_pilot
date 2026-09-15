import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/calendar/model_calendar.dart';

void main() {
  test('invalidating an event clears affected and adjacent month caches', () {
    final model = ModelCalendar();
    for (final key in ['2026-08', '2026-09', '2026-10', '2026-11']) {
      model.cachedEvents[key] = {};
      model.flatMonthEventsCache[key] = [];
    }

    model.invalidateEventRange(startDate: DateTime(2026, 9, 15));

    expect(model.cachedEvents.keys, ['2026-11']);
    expect(model.flatMonthEventsCache.keys, ['2026-11']);
  });

  test('invalidating a range clears every spanned month and grid neighbour',
      () {
    final model = ModelCalendar();
    for (final key in [
      '2026-07',
      '2026-08',
      '2026-09',
      '2026-10',
      '2026-11',
      '2026-12',
      '2027-01',
    ]) {
      model.cachedEvents[key] = {};
      model.flatMonthEventsCache[key] = [];
    }

    model.invalidateEventRange(
      startDate: DateTime(2026, 8, 31),
      endDate: DateTime(2026, 11, 1),
    );

    expect(model.cachedEvents.keys, ['2027-01']);
    expect(model.flatMonthEventsCache.keys, ['2027-01']);
  });
}
