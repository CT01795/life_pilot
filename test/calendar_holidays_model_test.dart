import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/calendar/model_calendar_holidays.dart';
import 'package:life_pilot/event/model_event_item.dart';

CalendarHolidayRecord record(
  int day,
  String name, {
  int month = 10,
  int year = 2026,
}) => CalendarHolidayRecord(date: DateTime(year, month, day), summary: name);

void main() {
  var ids = 0;
  String createId() => 'holiday_${ids++}';
  setUp(() => ids = 0);
  test(
    'row parsing skips invalid fields and normalizes dates without local conversion',
    () {
      final rows = ModelCalendarHolidays.parseRows([
        null,
        'invalid',
        {'date': 1, 'summary': 'skip'},
        {'date': 'bad', 'summary': 'skip'},
        {'date': '2026-10-01'},
        {'date': '2026-10-01T23:00:00-02:00', 'summary': 'Holiday'},
      ]);
      expect(rows, hasLength(1));
      expect(rows.single.date, DateTime(2026, 10, 2));
      expect(rows.single.summary, 'Holiday');
    },
  );
  test(
    'range is inclusive at start, exclusive at end and source remains untouched',
    () {
      final rows = List<CalendarHolidayRecord>.unmodifiable([
        record(3, 'C'),
        record(1, 'A'),
        record(2, 'B'),
        record(4, 'D'),
      ]);
      final result = ModelCalendarHolidays.project(
        records: rows,
        start: DateTime(2026, 10, 2, 15),
        end: DateTime(2026, 10, 4, 10),
        createId: createId,
      );
      expect(result.map((e) => e.name), ['B', 'C']);
      expect(rows.first.summary, 'C');
      expect(ids, 2);
      expect(
        result.every(
          (e) =>
              e.isHoliday == true && e.startTime == null && e.endTime == null,
        ),
        isTrue,
      );
    },
  );
  test('mapped Taiwanese holidays retain flags and merge behavior', () {
    final result = ModelCalendarHolidays.project(
      records: [record(1, '春節連假'), record(2, '春節連假'), record(3, '春節')],
      start: DateTime(2026, 10),
      end: DateTime(2026, 11),
      createId: createId,
    );
    expect(result, hasLength(1));
    expect(result.single.name, '春節');
    expect(result.single.isTaiwanHoliday, isTrue);
    expect(result.single.startDate, DateTime(2026, 10, 1));
    expect(result.single.endDate, DateTime(2026, 10, 3));
    expect(ids, 1);
  });
  test(
    'makeup holiday text is preserved and nonmerging records stay separate',
    () {
      final result = ModelCalendarHolidays.project(
        records: [record(1, '國慶日補假'), record(2, '國慶日補假')],
        start: DateTime(2026, 10),
        end: DateTime(2026, 11),
        createId: createId,
      );
      expect(result.map((e) => e.name), ['國慶日補假', '國慶日補假']);
      expect(result.every((e) => e.isTaiwanHoliday == true), isTrue);
      expect(ids, 2);
    },
  );
  test(
    'other holiday breaks a merge and names are not translated by the model',
    () {
      final result = ModelCalendarHolidays.project(
        records: [
          record(1, 'New Year'),
          record(2, 'Other'),
          record(3, 'New Year'),
        ],
        start: DateTime(2026, 10),
        end: DateTime(2026, 11),
        createId: createId,
      );
      expect(result.map((e) => e.name), ['New Year', 'Other', 'New Year']);
      expect(result.every((e) => e.isTaiwanHoliday == false), isTrue);
    },
  );
  test('year boundary merging preserves previous rules', () {
    final result = ModelCalendarHolidays.project(
      records: [
        record(1, 'New Year', year: 2027, month: 1),
        record(31, 'New Year', month: 12),
      ],
      start: DateTime(2026, 12, 31),
      end: DateTime(2027, 1, 2),
      createId: createId,
    );
    expect(result.single.startDate, DateTime(2026, 12, 31));
    expect(result.single.endDate, DateTime(2027, 1, 1));
  });
  test('repeated projection never reuses mutable output events', () {
    final rows = [record(1, 'Holiday')];
    List<EventItem> run() => ModelCalendarHolidays.project(
      records: rows,
      start: DateTime(2026, 10),
      end: DateTime(2026, 11),
      createId: createId,
    );
    final first = run();
    first.single.name = 'edited';
    expect(run().single.name, 'Holiday');
    expect(rows.single.summary, 'Holiday');
  });
  test('empty or invalid ranges generate no IDs and no events', () {
    for (final end in [DateTime(2026, 10), DateTime(2026, 9)]) {
      expect(
        ModelCalendarHolidays.project(
          records: [record(1, 'Holiday')],
          start: DateTime(2026, 10),
          end: end,
          createId: createId,
        ),
        isEmpty,
      );
    }
    expect(
      ModelCalendarHolidays.project(
        records: [],
        start: DateTime(2026, 10),
        end: DateTime(2026, 11),
        createId: createId,
      ),
      isEmpty,
    );
    expect(ids, 0);
  });
}
