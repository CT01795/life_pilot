import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/calendar/model_calendar_holidays.dart';
import 'package:life_pilot/calendar/service_calendar.dart';

void main() {
  for (final failedYear in [2026, 2027]) {
    for (final synchronous in [false, true]) {
      for (final lateFailure in [false, true]) {
        test(
          'year $failedYear fails promptly and observes late sibling (sync=$synchronous, late error=$lateFailure)',
          () async {
            final pending = Completer<List<CalendarHolidayRecord>>();
            final calls = <int>[];
            final request = ServiceCalendar.loadHolidayYears(
              start: DateTime(2026, 12),
              end: DateTime(2027, 2),
              loadYear: (year) {
                calls.add(year);
                if (year != failedYear) return pending.future;
                if (synchronous) throw StateError('failed year $year');
                return Future.error(StateError('failed year $year'));
              },
            );
            await expectLater(request, throwsStateError);
            expect(calls, [2026, 2027]);
            expect(pending.isCompleted, isFalse);
            // A fresh range load can succeed while the old sibling is pending.
            final records = await ServiceCalendar.loadHolidayYears(
              start: DateTime(2026, 12),
              end: DateTime(2027, 2),
              loadYear: (year) async => [
                CalendarHolidayRecord(date: DateTime(year), summary: '$year'),
              ],
            );
            expect(records.map((record) => record.summary), ['2026', '2027']);
            if (lateFailure) {
              pending.completeError(StateError('late sibling'));
            } else {
              pending.complete([
                CalendarHolidayRecord(
                  date: DateTime(2026),
                  summary: 'obsolete',
                ),
              ]);
            }
            await Future<void>.delayed(Duration.zero);
            expect(records.map((record) => record.summary), ['2026', '2027']);
          },
        );
      }
    }
  }

  test('simultaneous year failures are all observed', () async {
    final a = Completer<List<CalendarHolidayRecord>>(),
        b = Completer<List<CalendarHolidayRecord>>();
    final checked = expectLater(
      ServiceCalendar.loadHolidayYears(
        start: DateTime(2026, 12),
        end: DateTime(2027, 2),
        loadYear: (year) => year == 2026 ? a.future : b.future,
      ),
      throwsStateError,
    );
    a.completeError(StateError('first year'));
    b.completeError(StateError('second year'));
    await checked;
    await Future<void>.delayed(Duration.zero);
  });

  test('same-year day range requests that year once', () {
    expect(
      ModelCalendarHolidays.requiredYears(
        DateTime(2026, 10, 1, 23),
        DateTime(2026, 11, 1, 5),
      ),
      [2026],
    );
  });
  test('exclusive January first end does not request the following year', () {
    expect(
      ModelCalendarHolidays.requiredYears(
        DateTime(2026, 12, 27),
        DateTime(2027, 1, 1),
      ),
      [2026],
    );
    expect(
      ModelCalendarHolidays.requiredYears(
        DateTime(2026, 12, 27),
        DateTime(2027, 1, 2),
      ),
      [2026, 2027],
    );
  });
  test('empty/reversed/same-day ranges contain no years', () {
    expect(
      ModelCalendarHolidays.requiredYears(DateTime(2026), DateTime(2025)),
      isEmpty,
    );
    expect(
      ModelCalendarHolidays.requiredYears(DateTime(2026), DateTime(2026)),
      isEmpty,
    );
    expect(
      ModelCalendarHolidays.requiredYears(
        DateTime(2026, 1, 1, 3),
        DateTime(2026, 1, 1, 23),
      ),
      isEmpty,
    );
  });
  test(
    'multi-year ranges preserve ascending order and return read-only years',
    () {
      final years = ModelCalendarHolidays.requiredYears(
        DateTime.utc(2024, 12, 31),
        DateTime.utc(2027, 1, 2),
      );
      expect(years, [2024, 2025, 2026, 2027]);
      expect(() => years.clear(), throwsUnsupportedError);
    },
  );
  test(
    'cross-year reads start concurrently and retain year order after reverse completion',
    () async {
      final calls = <int>[];
      final a = Completer<List<CalendarHolidayRecord>>(),
          b = Completer<List<CalendarHolidayRecord>>();
      final first = CalendarHolidayRecord(
        date: DateTime(2026, 12, 31),
        summary: 'First',
      );
      final second = CalendarHolidayRecord(
        date: DateTime(2027, 1, 1),
        summary: 'Second',
      );
      final request = ServiceCalendar.loadHolidayYears(
        start: DateTime(2026, 12, 27),
        end: DateTime(2027, 1, 3),
        loadYear: (year) {
          calls.add(year);
          return year == 2026 ? a.future : b.future;
        },
      );
      expect(calls, [2026, 2027]);
      b.complete([second]);
      a.complete([first]);
      expect(await request, [first, second]);
    },
  );
  test('empty range does not invoke the loader', () async {
    final rows = await ServiceCalendar.loadHolidayYears(
      start: DateTime(2026),
      end: DateTime(2026),
      loadYear: (_) => throw StateError('unexpected query'),
    );
    expect(rows, isEmpty);
  });
  for (final synchronous in [true, false]) {
    test(
      'year failure propagates without unhandled errors ($synchronous)',
      () async {
        final request = ServiceCalendar.loadHolidayYears(
          start: DateTime(2026, 12),
          end: DateTime(2027, 2),
          loadYear: (year) {
            if (year == 2026) {
              if (synchronous) throw StateError('holiday failure');
              return Future.error(StateError('holiday failure'));
            }
            return Future.value([]);
          },
        );
        await expectLater(request, throwsStateError);
      },
    );
  }
  test(
    'range loader does not add a second cache over the existing yearly cache',
    () async {
      var reads = 0;
      Future<List<CalendarHolidayRecord>> load(int _) async {
        reads++;
        return [];
      }

      for (var i = 0; i < 2; i++) {
        await ServiceCalendar.loadHolidayYears(
          start: DateTime(2026, 10),
          end: DateTime(2026, 11),
          loadYear: load,
        );
      }
      expect(reads, 2);
    },
  );
}
