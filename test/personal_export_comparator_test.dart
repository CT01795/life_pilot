import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/service/export/personal_export_comparator.dart';

void main() {
  test('account tables sort account names without case sensitivity', () {
    for (final table in [
      TableNames.accountingAccount,
      TableNames.pointRecordAccount,
    ]) {
      final rows = <PersonalExportRow>[
        {'account_name': 'Zulu'},
        {'account_name': 'alpha'},
        {'account_name': 'Beta'},
      ]..sort(personalExportComparator(table));
      expect(rows.map((row) => row['account_name']), ['alpha', 'Beta', 'Zulu']);
    }
  });

  test('detail tables prioritize account, date, time, then description', () {
    const baseline = <String, dynamic>{
      'account_name': 'A',
      'date': '2026-10-14',
      'time': '09:00',
      'description': 'A',
    };
    for (final table in [
      TableNames.accountingDetail,
      TableNames.pointRecordDetail,
    ]) {
      final compare = personalExportComparator(table);
      for (final entry in const {
        'account_name': 'B',
        'date': '2026-10-15',
        'time': '10:00',
        'description': 'B',
      }.entries) {
        final later = {...baseline, entry.key: entry.value};
        expect(compare(baseline, later), lessThan(0));
        expect(compare(later, baseline), greaterThan(0));
      }
      expect(
        compare({
          ...baseline,
          'account_name': 'B',
          'date': '2020-01-01',
        }, baseline),
        greaterThan(0),
      );
    }
  });

  test('calendar and memory sorting follows the full schedule field order', () {
    const baseline = <String, dynamic>{
      'start_date': '2026-10-14',
      'start_time': '09:00',
      'end_date': '2026-10-15',
      'end_time': '17:00',
      'city': 'A',
      'location': 'A',
      'name': 'A',
    };
    final laterValues = <String, dynamic>{
      'start_date': '2026-10-16',
      'start_time': '10:00',
      'end_date': '2026-10-16',
      'end_time': '18:00',
      'city': 'B',
      'location': 'B',
      'name': 'B',
    };
    for (final table in [TableNames.calendarEvents, TableNames.memoryTrace]) {
      final compare = personalExportComparator(table);
      final keys = laterValues.keys.toList();
      for (var i = 0; i < keys.length; i++) {
        final later = {...baseline, keys[i]: laterValues[keys[i]]};
        for (final key in keys.skip(i + 1)) {
          later[key] = '';
        }
        expect(compare(baseline, later), lessThan(0), reason: keys[i]);
      }
    }
  });

  test(
    'missing end dates use start date and comparison leaves rows intact',
    () {
      final compare = personalExportComparator(TableNames.calendarEvents);
      final row = <String, dynamic>{'start_date': '2026-10-14'};
      final explicitEnd = {...row, 'end_date': '2026-10-14'};
      expect(compare(row, explicitEnd), 0);
      expect(compare({}, {}), 0);
      expect(row, {'start_date': '2026-10-14'});
    },
  );
}
